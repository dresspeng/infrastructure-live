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
export OVERRIDE_EXTENSION
export AWS_REGION AWS_PROFILE AWS_ACCOUNT_ID AWS_ACCESS_KEY AWS_SECRET_KEY ENVIRONMENT_NAME

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terragrunt hclfmt

clean:
	make nuke-region
	make nuke-global
	make clean-local
clean-local: ## Clean the local files and folders
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*override*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terragrunt-cache"); do echo $$folderPath; rm -Rf $$folderPath; done;

nuke-region:
	cloud-nuke aws --region ${AWS_REGION} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

SCRAPER_BACKEND_BRANCH_NAME ?= master
SCRAPER_FRONTEND_BRANCH_NAME ?= master
SERVICE_UP ?= true
.ONESHELL: set-scraper
scraper-prepare:
	make prepare-terragrunt
	make prepare-scraper-backend BRANCH_NAME=${SCRAPER_BACKEND_BRANCH_NAME} SERVICE_UP={SERVICE_UP}
	# TODO: extract backend dns
	# make prepare-scraper-frontend BRANCH_NAME=${SCRAPER_FRONTEND_BRANCH_NAME} SERVICE_UP={SERVICE_UP}
scraper-init:
	$(eval SRC_FOLDER=${PATH_ABS_AWS}/region/scraper/backend)
	terragrunt init --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
scraper-validate:
	$(eval SRC_FOLDER=${PATH_ABS_AWS}/region/scraper/backend)
	terragrunt validate --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
scraper-plan:
	$(eval SRC_FOLDER=${PATH_ABS_AWS}/region/scraper/backend)
	terragrunt plan --terragrunt-non-interactive --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl -lock=false -out=${OUTPUT_FILE} 2>&1
scraper-apply:
	$(eval SRC_FOLDER=${PATH_ABS_AWS}/region/scraper/backend)
	terragrunt apply --terragrunt-non-interactive  -auto-approve --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl
scraper-remove-lb:
	$(eval SRC_FOLDER=${PATH_ABS_AWS}/region/scraper/backend)
	terragrunt destroy --terragrunt-non-interactive -auto-approve --terragrunt-config ${SRC_FOLDER}/terragrunt.hcl -target module.microservice.module.ecs.module.alb

.ONESHELL: prepare
prepare-terragrunt: ## Setup the environment
	make prepare-convention
	make prepare-aws-account
	# make prepare-aws-region
.ONESHELL: prepare-account-aws
prepare-convention:
	$(eval GIT_HOST=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=infrastructure)
	$(eval SERVICE_NAME=modules)
	$(eval BRANCH_NAME=master)
	cat <<-EOF > ${PATH_ABS_LIVE}/convention_${OVERRIDE_EXTENSION}.hcl 
	locals {
		organization_name			= "${ORGANIZATION_NAME}"
		environment_name			= "${ENVIRONMENT_NAME}"
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
		account_region_name	= "${AWS_REGION}"
		account_name			= "${AWS_PROFILE}"
		account_id				= "${AWS_ACCOUNT_ID}"
		common_tags = {
			"Account" = "${AWS_PROFILE}"
		}
	}
	EOF
# prepare-aws-region:
# 	cat <<-EOF > ${PATH_ABS_AWS}/region/region_${OVERRIDE_EXTENSION}.hcl 
# 	locals {
# 		region_name = "${AWS_REGION}"
# 	}
# 	EOF
.ONESHELL: prepare-module-microservice-scraper-backend
USE_FARGATE ?= false
SERVICE_COUNT ?= 1
INSTANCE_MIN_COUNT ?= 0
INSTANCE_DESIRED_COUNT ?= 1
INSTANCE_MAX_COUNT ?= 1
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
		override_extension_name	= "${OVERRIDE_EXTENSION}"
		common_name 			= "${COMMON_NAME}"
		# organization_name 	= "${ORGANIZATION_NAME}"
		repository_name 		= "${PROJECT_NAME}-${SERVICE_NAME}"
		branch_name 			= "${BRANCH_NAME}"
		common_tags = {
			"Git Microservice" 	= "${GIT_HOST}/${ORGANIZATION_NAME}/${PROJECT_NAME}-${SERVICE_NAME}@${BRANCH_NAME}"
			"Service" 			= "${SERVICE_NAME}"
		}
		use_fargate 	= ${USE_FARGATE}
		pricing_names 	= ${PRICING_NAMES}
		os 				= ${OS}
		os_version 		= ${OS_VERSION}
		architecture 	= ${ARCHITECTURE}
	EOF

	if [[ ${USE_FARGATE} == true ]]; then
		# FARGATE
		cat <<-EOF >> ${FILE}
			fargate_instance_key = ${FARGATE_INSTANCE_KEY}
		EOF
		if [[ ${SERVICE_UP} == true ]]; then
			cat <<-EOF >> ${FILE}
				service_count = ${SERVICE_COUNT}
			EOF
		else
			cat <<-EOF >> ${FILE}
				service_count = 0
			EOF
		fi
	else
		# EC2
		cat <<-EOF >> ${FILE}
			ec2_instance_key = ${EC2_INSTANCE_KEY}
		EOF
		if [[ ${SERVICE_UP} == true ]]; then
			cat <<-EOF >> ${FILE}
				service_count 			= 1
				instance_min_count 		= ${INSTANCE_MIN_COUNT}
				instance_desired_count 	= ${INSTANCE_DESIRED_COUNT}
				instance_max_count 		= ${INSTANCE_MAX_COUNT}
			EOF
		else
			cat <<-EOF >> ${FILE}
				service_count 			= 0
				instance_min_count 		= 0
				instance_desired_count 	= 0
				instance_max_count 		= 0
			EOF
		fi
	fi

	echo "}" >> ${FILE}

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

export FLICKR_PRIVATE_KEY FLICKR_PUBLIC_KEY UNSPLASH_PRIVATE_KEY UNSPLASH_PUBLIC_KEY PEXELS_PUBLIC_KEY
.ONESHELL: prepare-scraper-backend
BRANCH_NAME ?= master
prepare-scraper-backend:
	$(eval GIT_HOST=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_ABS_AWS}/region/${PROJECT_NAME}/${SERVICE_NAME})
	$(eval COMMON_NAME=$(shell echo ${PROJECT_NAME}-${SERVICE_NAME}-${BRANCH_NAME}-${ENVIRONMENT_NAME} | tr A-Z a-z))
	$(eval CLOUD_HOST=aws)
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
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=config
	make prepare-scraper-backend-env \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST}
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
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=config
	make prepare-scraper-frontend-env \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL} \
		PORT=3000
	
aws-auth:
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE} \
		&& aws configure set --profile ${AWS_PROFILE} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE} \
		&& aws configure set region ${AWS_REGION} --profile ${AWS_PROFILE} \
		&& aws configure set output 'text' --profile ${AWS_PROFILE} \
		&& aws configure list

ssh-auth:
	$(eval GIT_HOST=github.com)
	mkdir -p ${SSH_FOLDER}
	eval `ssh-agent -s`
	ssh-keyscan ${GIT_HOST} >> ${SSH_FOLDER}/known_hosts

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc
