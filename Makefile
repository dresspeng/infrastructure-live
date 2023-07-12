# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

GIT_SHA=$(shell git rev-parse HEAD) # latest commit hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty") # If working copy has changes, append `-dirty` to hash
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

# absolute path
PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PATH_REL_LIVE=live
PATH_ABS_LIVE=${PATH_ABS_ROOT}/${PATH_REL_LIVE}
PATH_REL_AWS=live/aws
PATH_ABS_AWS=${PATH_ABS_ROOT}/${PATH_REL_AWS}

OVERRIDE_EXTENSION=override

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terragrunt hclfmt

.ONESHELL: clean
clean: ## Clean the test environment
	make nuke-region
	make nuke-ecs
	make nuke-vpc
	make nuke-global

	make clean-task-definition
	make clean-elb
	make clean-ecs

	make clean-local
clean-local: ## Clean the local files and folders
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*override*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terragrunt-cache"); do echo $$folderPath; rm -Rf $$folderPath; done;
clean-cloudwatch:
	for alarmName in $(shell aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName'); do echo $$alarmName; aws cloudwatch delete-alarms --alarm-names $$alarmName; done;
clean-task-definition:
	for taskDefinition in $(shell aws ecs list-task-definitions --status ACTIVE --query 'taskDefinitionArns[]'); do aws ecs deregister-task-definition --task-definition $$taskDefinition --query 'taskDefinition.taskDefinitionArn'; done;
clean-iam:
	# roles are attached to policies
	for roleName in $(shell aws iam list-roles --query 'Roles[].RoleName'); do echo $$roleArn; aws iam delete-role --role-name $$roleName; done; \
	for policyArn in $(shell aws iam list-policies --max-items 200 --no-only-attached --query 'Policies[].Arn'); do echo $$policyArn; aws iam delete-policy --policy-arn $$policyArn; done;
clean-ec2:
	for launchTemplateId in $(shell aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateId'); do aws ec2 delete-launch-template --launch-template-id $$launchTemplateId --query 'LaunchTemplate.LaunchTemplateName'; done;
clean-elb:
	for targetGroupArn in $(shell aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn'); do echo $$targetGroupArn; aws elbv2 delete-target-group --target-group-arn $$targetGroupArn; done;
clean-ecs:
	for clusterArn in $(shell aws ecs describe-clusters --query 'clusters[].clusterArn'); do echo $$clusterArn; aws ecs delete-cluster --cluster $$clusterArn; done;
	for capacityProviderArn in $(shell aws ecs describe-capacity-providers --query 'capacityProviders[].capacityProviderArn'); do aws ecs   delete-capacity-provider --capacity-provider $$capacityProviderArn --query 'capacityProvider.capacityProviderArn'; done;

nuke-region:
	cloud-nuke aws --region ${AWS_REGION_NAME} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-vpc:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type vpc --force;
nuke-ecs:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type ecscluster --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

.ONESHELL: aws-auth
aws-auth:
	aws --version
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE_NAME}
	aws configure set --profile ${AWS_PROFILE_NAME} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE_NAME}
	aws configure set region ${AWS_REGION_NAME} --profile ${AWS_PROFILE_NAME}
	aws configure set output 'text' --profile ${AWS_PROFILE_NAME}
	make aws-auth-check
aws-auth-check:
	aws configure list
.ONESHELL: ecr-configure

ssh-auth:
	$(eval GIT_HOST=github.com)
	mkdir -p ${SSH_FOLDER}
	eval `ssh-agent -s`
	ssh-keyscan ${GIT_HOST} >> ${SSH_FOLDER}/known_hosts

gh-auth-check:
	gh auth status
gh-list-branches:
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches | jq '.[].name'
.ONESHELL: gh-load-folder
gh-load-folder:
	echo GET Github folder:: ${REPOSITORY_CONFIG_PATH_FOLDER}@${BRANCH_NAME}
	$(eval filesPath=$(shell curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FOLDER}?ref=${BRANCH_NAME} | jq -c '.[].path'))
	for filePath in ${filesPath}; do		
		make gh-load-config-file \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FILE="$$filePath" \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			BRANCH_NAME=${BRANCH_NAME}; \
    done
gh-load-config-file:
	echo GET Github file:: ${REPOSITORY_CONFIG_PATH_FILE}@${BRANCH_NAME}
	curl -s -L -o ${TERRAGRUNT_CONFIG_PATH}/$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${REPOSITORY_CONFIG_PATH_FILE}" = *.* ]] && echo .$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FILE}?ref=${BRANCH_NAME}
gh-get-default-branch:
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches

list-override-files:
	find ./live -type f -name "*${OVERRIDE_EXTENSION}*"

.ONESHELL: prepare
prepare-terragrunt: ## Setup the environment
	make prepare-convention-config-file \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION}
	make prepare-aws-account-config-file \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		DOMAIN_NAME=${DOMAIN_NAME} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_PROFILE_NAME=${AWS_PROFILE_NAME} \
		AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
.ONESHELL: prepare-account-aws
prepare-convention-config-file:
  	$(eval MODULES_GIT_HOST_AUTH_METHOD=https)
	$(eval MODULES_GIT_HOST=github.com)
	$(eval MODULES_ORGANIZATION_NAME=dresspeng)
	$(eval MODULES_PROJECT_NAME=infrastructure)
	$(eval MODULES_SERVICE_NAME=modules)
	$(eval MODULES_REPOSITORY_VISIBILITY=public)
	$(eval MODULES_BRANCH_NAME=master)
	cat <<-EOF > ${PATH_ABS_LIVE}/convention_${OVERRIDE_EXTENSION}.hcl 
	locals {
		override_extension_name			= "${OVERRIDE_EXTENSION}"
		modules_git_host_auth_method 	= "${MODULES_GIT_HOST_AUTH_METHOD}"
		modules_git_host_name			= "${MODULES_GIT_HOST}"
		modules_organization_name		= "${MODULES_ORGANIZATION_NAME}"
		modules_repository_name			= "${MODULES_PROJECT_NAME}-${MODULES_SERVICE_NAME}"
		modules_repository_visibility 	= "${MODULES_REPOSITORY_VISIBILITY}"
		modules_branch_name				= "${MODULES_BRANCH_NAME}"
		tags = {
			"Git Module" 	= "${MODULES_GIT_HOST}/${MODULES_ORGANIZATION_NAME}/${MODULES_PROJECT_NAME}-${MODULES_SERVICE_NAME}@${MODULES_BRANCH_NAME}"
		}
	}
	EOF
prepare-aws-account-config-file:
	cat <<-EOF > ${PATH_ABS_AWS}/account_${OVERRIDE_EXTENSION}.hcl 
	locals {
		domain_name 			= "${DOMAIN_NAME}"
		account_region_name		= "${AWS_REGION_NAME}"
		account_name			= "${AWS_PROFILE_NAME}"
		account_id				= "${AWS_ACCOUNT_ID}"
		tags = {
			"Account" = "${AWS_PROFILE_NAME}"
		}
	}
	EOF
prepare-microservice-config-file:
	cat <<-EOF > ${TERRAGRUNT_CONFIG_PATH}/service_${OVERRIDE_EXTENSION}.hcl 
	locals {
		branch_name = "${BRANCH_NAME}"
	}
	EOF
	
prepare-microservice:
	echo GET Github branches:: ${ORGANIZATION_NAME}/${REPOSITORY_NAME}
	$(eval branches=$(shell make gh-list-branches GITHUB_TOKEN=${GITHUB_TOKEN} ORGANIZATION_NAME=${ORGANIZATION_NAME} REPOSITORY_NAME=${REPOSITORY_NAME}))
	if [[ '$(shell echo ${branches} | grep -o "${BRANCH_NAME}" | wc -l)' == '0' ]]; then
		$(eval BRANCH_NAME_MICROSERVICE=${DEFAULT_BRANCH_NAME})
		echo -e '\033[43mWarning\033[0m' ::: BRANCH_NAME ${BRANCH_NAME} not found, using ${DEFAULT_BRANCH_NAME}
		make prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
		make gh-load-folder \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	else
		$(eval BRANCH_NAME_MICROSERVICE=${BRANCH_NAME})
		make prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
		make gh-load-folder \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	fi

test:
	$(eval test=123)
	echo ${test}

.ONESHELL: prepare-scraper-backend
prepare-scraper-backend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/scraper/backend)
	$(eval ORGANIZATION_NAME=dresspeng)
	$(eval REPOSITORY_NAME=scraper-backend)
	$(eval REPOSITORY_CONFIG_PATH_FOLDER=config)
	$(eval DEFAULT_BRANCH_NAME=master)
	$(eval COMMON_NAME=defined-in-hcl)
	$(eval CLOUD_HOST=aws)

	make prepare-microservice \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		DEFAULT_BRANCH_NAME=${DEFAULT_BRANCH_NAME} \
		BRANCH_NAME=${BRANCH_NAME}
	make prepare-scraper-backend-env \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
		AWS_SECRET_KEY=${AWS_SECRET_KEY}
prepare-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${TERRAGRUNT_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		OUTPUT_FOLDER=${TERRAGRUNT_CONFIG_PATH} \
		CLOUD_HOST=${CLOUD_HOST} \
		COMMON_NAME=${COMMON_NAME} \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
		AWS_SECRET_KEY=${AWS_SECRET_KEY}

.ONESHELL: prepare-scraper-frontend
prepare-scraper-frontend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/scraper/frontend)
	$(eval ORGANIZATION_NAME=dresspeng)
	$(eval REPOSITORY_NAME=scraper-frontend)
	$(eval REPOSITORY_CONFIG_PATH_FOLDER=config)
	$(eval DEFAULT_BRANCH_NAME=master)

	make prepare-microservice \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		DEFAULT_BRANCH_NAME=${DEFAULT_BRANCH_NAME} \
		BRANCH_NAME=${BRANCH_NAME}
	make prepare-scraper-frontend-env \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${TERRAGRUNT_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		OUTPUT_FOLDER=${TERRAGRUNT_CONFIG_PATH} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL} \
		PORT=$(shell yq eval '.port' ${TERRAGRUNT_CONFIG_PATH}/config_${OVERRIDE_EXTENSION}.yml)

init:
	terragrunt init --terragrunt-non-interactive --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl
validate:
	terragrunt validate --terragrunt-non-interactive --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl
plan:
	# -lock=false
	terragrunt plan --terragrunt-non-interactive --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl -no-color -out=${OUTPUT_FILE} 2>&1
apply:
	terragrunt apply --terragrunt-non-interactive -auto-approve --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl
destroy-microservice:
	terragrunt destroy --terragrunt-non-interactive -auto-approve --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl -target module.microservice
output-microservice:
	terragrunt output --terragrunt-non-interactive --terragrunt-config ${TERRAGRUNT_CONFIG_PATH}/terragrunt.hcl -json  microservice

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc