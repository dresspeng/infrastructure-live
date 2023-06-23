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
export GIT_NAME ORGANIZATION_NAME PROJECT_NAME SERVICE_NAME

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terragrunt hclfmt

SCRAPER_BACKEND_BRANCH_NAME ?= master
SCRAPER_FRONTEND_BRANCH_NAME ?= master
.ONESHELL: set-scraper
prepare-scraper:
	make prepare-terragrunt
	make prepare-scraper-backend BRANCH_NAME=${SCRAPER_BACKEND_BRANCH_NAME}
	make prepare-scraper-frontend BRANCH_NAME=${SCRAPER_FRONTEND_BRANCH_NAME}

.ONESHELL: prepare
prepare-terragrunt: ## Setup the environment
	make prepare-convention
	make prepare-aws-account
	make prepare-aws-region
.ONESHELL: prepare-account-aws
prepare-convention:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=infrastructure)
	$(eval SERVICE_NAME=modules)
	$(eval BRANCH_NAME=master)
	cat <<-EOF > ${PATH_ABS_LIVE}/convention_${OVERRIDE_EXTENSION}.hcl 
	locals {
		organization_name			= "${ORGANIZATION_NAME}"
		environment_name			= "${ENVIRONMENT_NAME}"
		modules_git_name			= "${GIT_NAME}"
		modules_organization_name	= "${ORGANIZATION_NAME}"
		modules_repository_name		= "${PROJECT_NAME}-${SERVICE_NAME}"
		modules_branch_name			= "${BRANCH_NAME}"
		common_tags = {
			"Git Module" 	= "${GIT_NAME}/${ORGANIZATION_NAME}/${PROJECT_NAME}-${SERVICE_NAME}@${BRANCH_NAME}"
			"Environment" 	= "${ENVIRONMENT_NAME}"
		}
	}
	EOF
prepare-aws-account:
	cat <<-EOF > ${PATH_ABS_AWS}/account_${OVERRIDE_EXTENSION}.hcl 
	locals {
		account_region_names	= ["${AWS_REGION}"]
		account_name			= "${AWS_PROFILE}"
		account_id				= "${AWS_ACCOUNT_ID}"
		common_tags = {
			"Account" = "${AWS_PROFILE}"
		}
	}
	EOF
prepare-aws-region:
	cat <<-EOF > ${PATH_ABS_AWS}/region/region_${OVERRIDE_EXTENSION}.hcl 
	locals {
		region_names = ["${AWS_REGION}"]
	}
	EOF
.ONESHELL: prepare-module-microservice-scraper-backend
prepare-microservice:
	cat <<-EOF > ${OUTPUT_FOLDER}/service_${OVERRIDE_EXTENSION}.hcl
	locals {
		common_name 		= "${COMMON_NAME}"
		# organization_name 	= "${ORGANIZATION_NAME}"
		repository_name 	= "${PROJECT_NAME}-${SERVICE_NAME}"
		branch_name 		= "${BRANCH_NAME}"
		common_tags = {
			"Git Microservice" 	= "${GIT_NAME}/${ORGANIZATION_NAME}/${PROJECT_NAME}-${SERVICE_NAME}@${BRANCH_NAME}"
			"Service" = "${SERVICE_NAME}"
		}
	}
	EOF

.ONESHELL: gh-load-folder
gh-load-folder:
	$(eval res=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${GH_ORG}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH} | jq -c '.[] | .path'))
	for file in ${res}; do \
		make gh-load-file OUTPUT_FOLDER=${OUTPUT_FOLDER} GH_PATH="$$file"; \
    done
gh-load-file:
	curl -L -o ${OUTPUT_FOLDER}/$(shell basename ${GH_PATH} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${GH_PATH}" = *.* ]] && echo .$(shell basename ${GH_PATH} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${GH_ORG}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}

export FLICKR_PRIVATE_KEY FLICKR_PUBLIC_KEY UNSPLASH_PRIVATE_KEY PEXELS_PUBLIC_KEY
export OUTPUT_FOLDER COMMON_NAME FLICKR_PRIVATE_KEY FLICKR_PUBLIC_KEY UNSPLASH_PRIVATE_KEY UNSPLASH_PUBLIC_KEY PEXELS_PUBLIC_KEY
.ONESHELL: prepare-scraper-backend
BRANCH_NAME ?= master
prepare-scraper-backend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval OUTPUT_FOLDER=${PATH_ABS_AWS}/region/${PROJECT_NAME}/${SERVICE_NAME})
	$(eval COMMON_NAME=$(shell echo ${ORGANIZATION_NAME}-${PROJECT_NAME}-${SERVICE_NAME}-${BRANCH_NAME}-${ENVIRONMENT_NAME} | tr A-Z a-z))
	make prepare-microservice \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME}
	make gh-load-folder \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		GH_ORG=${ORGANIZATION_NAME} \
		GH_REPO=${PROJECT_NAME}-${SERVICE_NAME} \
		GH_BRANCH=${BRANCH_NAME} \
		GH_PATH=config
	make prepare-scraper-backend-env
	cd ${OUTPUT_FOLDER}
	terragrunt init
make prepare-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=aws \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY}
export OUTPUT_FOLDER NEXT_PUBLIC_API_URL
.ONESHELL: prepare-scraper-frontend
BRANCH_NAME ?= master
prepare-scraper-frontend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	$(eval OUTPUT_FOLDER=${PATH_ABS_AWS}/region/${PROJECT_NAME}/${SERVICE_NAME})
	$(eval COMMON_NAME=$(shell echo ${ORGANIZATION_NAME}-${PROJECT_NAME}-${SERVICE_NAME}-${BRANCH_NAME}-${ENVIRONMENT_NAME} | tr A-Z a-z))
	make prepare-microservice \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME}
	make gh-load-folder \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		GH_ORG=${ORGANIZATION_NAME} \
		GH_REPO=${PROJECT_NAME}-${SERVICE_NAME} \
		GH_BRANCH=${BRANCH_NAME} \
		GH_PATH=config
	make prepare-scraper-frontend-env 
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL} \
		PORT=3000
	
aws-configure:
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE} \
		&& aws configure set --profile ${AWS_PROFILE} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE} \
		&& aws configure set region ${AWS_REGION} --profile ${AWS_PROFILE} \
		&& aws configure set output 'text' --profile ${AWS_PROFILE} \
		&& aws configure list

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc
