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
	cloud-nuke aws --region ${AWS_REGION} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

.ONESHELL: aws-auth
aws-auth:
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE}
	aws configure set --profile ${AWS_PROFILE} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE}
	aws configure set region ${AWS_REGION} --profile ${AWS_PROFILE}
	aws configure set output 'text' --profile ${AWS_PROFILE}
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
.ONESHELL: gh-load-folder
gh-load-folder:
	echo GET Github folder:: ${REPOSITORY_PATH}
	$(eval res=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_PATH}?ref=${BRANCH_NAME} | jq -c '.[] | .path'))
	for file in ${res}; do
		echo GET Github file:: "$$file"; \
		make gh-load-file \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			OUTPUT_FOLDER=${OUTPUT_FOLDER} \
			REPOSITORY_PATH="$$file" \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME}; \
    done
gh-load-file:
	curl -L -o ${OUTPUT_FOLDER}/$(shell basename ${REPOSITORY_PATH} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${REPOSITORY_PATH}" = *.* ]] && echo .$(shell basename ${REPOSITORY_PATH} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_PATH}?ref=${BRANCH_NAME}


.ONESHELL: prepare
prepare-terragrunt: ## Setup the environment
	make prepare-convention OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION}
	make prepare-aws-account OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION}
.ONESHELL: prepare-account-aws
prepare-convention:
	$(eval GIT_HOST=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=infrastructure)
	$(eval SERVICE_NAME=modules)
	$(eval BRANCH_NAME=master)
	cat <<-EOF > ${PATH_ABS_LIVE}/convention_${OVERRIDE_EXTENSION}.hcl 
	locals {
		override_extension_name		= "${OVERRIDE_EXTENSION}"
		organization_name			= "${ORGANIZATION_NAME}"
		modules_git_host_name		= "${GIT_HOST}"
		modules_organization_name	= "${ORGANIZATION_NAME}"
		modules_repository_name		= "${PROJECT_NAME}-${SERVICE_NAME}"
		modules_branch_name			= "${BRANCH_NAME}"
		common_tags = {
			"Git Module" 	= "${GIT_HOST}/${ORGANIZATION_NAME}/${PROJECT_NAME}-${SERVICE_NAME}@${BRANCH_NAME}"
			"Environment" 	= "${ENVIRONMENT_NAME}"
		}
	}
	EOF
prepare-aws-account:
	cat <<-EOF > ${PATH_ABS_AWS}/account_${OVERRIDE_EXTENSION}.hcl 
	locals {
		domain_name 			= "${DOMAIN_NAME}"
		account_region_name		= "${AWS_REGION}"
		account_name			= "${AWS_PROFILE}"
		account_id				= "${AWS_ACCOUNT_ID}"
		common_tags = {
			"Account" = "${AWS_PROFILE}"
		}
	}
	EOF

.ONESHELL: prepare-module-microservice-scraper-backend
SERVICE_UP ?= true
USE_FARGATE ?= false
TASK_MIN_COUNT ?= 0
TASK_DESIRED_COUNT ?= 2
TASK_MAX_COUNT ?= 2
PRICING_NAMES ?= ["on-demand"]
EC2_INSTANCE_KEY ?= "t3_small"
FARGATE_INSTANCE_KEY ?= "set_1"
OS ?= "linux"
OS_VERSION ?= "2023"
ARCHITECTURE ?= "x64"
prepare-microservice:
	$(eval FILE=${OUTPUT_FOLDER}/service_${OVERRIDE_EXTENSION}.hcl)
	cat <<-EOF > ${FILE}
	locals {
		common_name 			= "${COMMON_NAME}"
		# organization_name 	= "${ORGANIZATION_NAME}"
		project_name 			= "${PROJECT_NAME}"
		service_name 			= "${SERVICE_NAME}"
		repository_name 		= "${PROJECT_NAME}-${SERVICE_NAME}"
		branch_name 			= "${BRANCH_NAME}"
		common_tags = {
			"Git Microservice" 	= "${GIT_HOST}/${ORGANIZATION_NAME}/${PROJECT_NAME}-${SERVICE_NAME}@${BRANCH_NAME}"
			"Project" 			= "${PROJECT_NAME}"
			"Service" 			= "${SERVICE_NAME}"
		}
		use_fargate 	= ${USE_FARGATE}
		pricing_names 	= ${PRICING_NAMES}
		os 				= "${OS}"
		os_version 		= "${OS_VERSION}"
		architecture 	= "${ARCHITECTURE}"
	EOF
	
	if [[ ${USE_FARGATE} == true ]]; then
		cat <<-EOF >> ${FILE}
			fargate_instance_key = "${FARGATE_INSTANCE_KEY}"
		EOF
	else
		cat <<-EOF >> ${FILE}
			ec2_instance_key = "${EC2_INSTANCE_KEY}"
		EOF
	fi

	if [[ ${SERVICE_UP} == true ]]; then
		cat <<-EOF >> ${FILE}
			task_min_count     = ${TASK_MIN_COUNT}
			task_desired_count = ${TASK_DESIRED_COUNT}
			task_max_count     = ${TASK_MAX_COUNT}
		EOF
	else
		cat <<-EOF >> ${FILE}
			task_min_count 		= 0
			task_desired_count 	= 0
			task_max_count 		= 0
		EOF
	fi

	echo "}" >> ${FILE}
	echo service_${OVERRIDE_EXTENSION}:::; cat ${FILE}

.ONESHELL: prepare-scraper-backend
BRANCH_NAME ?= master
prepare-scraper-backend:
	$(eval GIT_HOST=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval REPOSITORY_CONFIG_PATH=config)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_ABS_AWS}/region/${PROJECT_NAME}/${SERVICE_NAME})
	$(eval COMMON_NAME=$(shell echo ${PROJECT_NAME}-${SERVICE_NAME}-${BRANCH_NAME}-${ENVIRONMENT_NAME} | tr A-Z a-z))
	$(eval CLOUD_HOST=aws)
	make prepare-microservice \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		GIT_HOST=${GIT_HOST} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		PROJECT_NAME=${PROJECT_NAME} \
		SERVICE_NAME=${SERVICE_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		SERVICE_UP=${SERVICE_UP}
	make gh-load-folder \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=${REPOSITORY_CONFIG_PATH}
	make prepare-scraper-backend-env \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY}
prepare-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY}

.ONESHELL: prepare-scraper-frontend
BRANCH_NAME ?= master
prepare-scraper-frontend:
	$(eval GIT_HOST=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	$(eval REPOSITORY_CONFIG_PATH=config)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_ABS_AWS}/region/${PROJECT_NAME}/${SERVICE_NAME})
	$(eval COMMON_NAME=$(shell echo ${PROJECT_NAME}-${SERVICE_NAME}-${BRANCH_NAME}-${ENVIRONMENT_NAME} | tr A-Z a-z))
	make prepare-microservice \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		GIT_HOST=${GIT_HOST} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		PROJECT_NAME=${PROJECT_NAME} \
		SERVICE_NAME=${SERVICE_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		SERVICE_UP=${SERVICE_UP}
	make gh-load-folder \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=${REPOSITORY_CONFIG_PATH}
	make prepare-scraper-frontend-env \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		OUTPUT_FOLDER=${OUTPUT_FOLDER}
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		PORT=$(shell yq eval '.port' ${OUTPUT_FOLDER}/config_${OVERRIDE_EXTENSION}.yml)

init:
	terragrunt init --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
validate:
	terragrunt validate --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
plan:
	# -lock=false
	terragrunt plan --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl -no-color -out=${OUTPUT_FILE} 2>&1
apply:
	terragrunt apply --terragrunt-non-interactive -auto-approve --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
destroy-lb:
	terragrunt destroy --terragrunt-non-interactive -auto-approve --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl -target module.microservice.module.ecs.module.elb

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc
