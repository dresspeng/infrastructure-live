# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FILE_NAME=$(shell basename $(MAKEFILE_LIST))
INFRA_FILE_NAME=Makefile_infra

OVERRIDE_EXTENSION=override

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced
.ONESHELL: # run one shell per target

# error for undefined variables
check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

fmt: ## Format all files
	terragrunt hclfmt

aws-auth:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} aws-auth USE_DEFAULT=true AWS_REGION_NAME=${AWS_REGION_NAME} AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
	aws configure list

clean: ## Clean the test environment
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-region

	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-task-definition
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-elb
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-ecs
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-cloudwatch

	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-ecs
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-vpc
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-global

	make -f ${PATH_ABS_ROOT}/${FILE_NAME} clean-local
clean-local: ## Clean the local files and folders
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*override*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terragrunt-cache"); do echo $$folderPath; rm -Rf $$folderPath; done;

list-override-files:
	find ./live -type f -name "*${OVERRIDE_EXTENSION}*"

prepare-terragrunt: ## Setup the environment
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-convention-config-file \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION}
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-aws-account-config-file \
		PATH_ACCOUNT=${PATH_ABS_ROOT}/live/aws \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		DOMAIN_NAME=${DOMAIN_NAME} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_PROFILE_NAME=${AWS_PROFILE_NAME} \
		AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-aws-account-config-file \
		PATH_ACCOUNT=live/_global \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		DOMAIN_NAME=${DOMAIN_NAME} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_PROFILE_NAME=${AWS_PROFILE_NAME} \
		AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
prepare-convention-config-file:
	$(eval ORGANIZATION_NAME=vistimi)

	$(eval MODULES_GIT_HOST_AUTH_METHOD=https)
	$(eval MODULES_GIT_HOST=github.com)
	$(eval MODULES_ORGANIZATION_NAME=vistimi)
	$(eval MODULES_PROJECT_NAME=infrastructure)
	$(eval MODULES_SERVICE_NAME=modules)
	$(eval MODULES_REPOSITORY_VISIBILITY=public)
	$(eval MODULES_BRANCH_NAME=trunk)

	$(call check_defined, OVERRIDE_EXTENSION)
	cat <<-EOF > ${PATH_ABS_ROOT}/live/convention_${OVERRIDE_EXTENSION}.hcl 
	locals {
		override_extension_name			= "${OVERRIDE_EXTENSION}"
		organization_name				= "${ORGANIZATION_NAME}"
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
	$(call check_defined, OVERRIDE_EXTENSION, PATH_ACCOUNT, AWS_REGION_NAME, AWS_PROFILE_NAME, AWS_ACCOUNT_ID)
	cat <<-EOF > ${PATH_ACCOUNT}/account_${OVERRIDE_EXTENSION}.hcl 
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
	$(call check_defined, OVERRIDE_EXTENSION, TERRAGRUNT_CONFIG_PATH, BRANCH_NAME)
	cat <<-EOF > ${TERRAGRUNT_CONFIG_PATH}/service_${OVERRIDE_EXTENSION}.hcl 
	locals {
		branch_name = "${BRANCH_NAME}"
	}
	EOF
	
prepare-microservice:
	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, TERRAGRUNT_CONFIG_PATH, ORGANIZATION_NAME, REPOSITORY_NAME, BRANCH_NAME, DEFAULT_BRANCH_NAME)
	echo GET Github branches:: ${ORGANIZATION_NAME}/${REPOSITORY_NAME}
	$(eval branches=$(shell make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-list-branches GITHUB_TOKEN=${GITHUB_TOKEN} ORGANIZATION_NAME=${ORGANIZATION_NAME} REPOSITORY_NAME=${REPOSITORY_NAME}))
	if [[ '$(shell echo ${branches} | grep -o "${BRANCH_NAME}" | wc -l)' == '0' ]]; then
		$(eval BRANCH_NAME_MICROSERVICE=${DEFAULT_BRANCH_NAME})
		echo -e '\033[43mWarning\033[0m' ::: BRANCH_NAME ${BRANCH_NAME} not found, using ${DEFAULT_BRANCH_NAME}
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
		make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-load-folder \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	else
		$(eval BRANCH_NAME_MICROSERVICE=${BRANCH_NAME})
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
		make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-load-folder \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	fi

prepare-tryon-backend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/tryon/backend)
	$(eval ORGANIZATION_NAME=vistimi)
	$(eval REPOSITORY_NAME=VITON-HD)
	$(eval DEFAULT_BRANCH_NAME=trunk)

	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME, DEFAULT_BRANCH_NAME)
	echo GET Github branches:: ${ORGANIZATION_NAME}/${REPOSITORY_NAME}
	$(eval branches=$(shell make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-list-branches GITHUB_TOKEN=${GITHUB_TOKEN} ORGANIZATION_NAME=${ORGANIZATION_NAME} REPOSITORY_NAME=${REPOSITORY_NAME}))
	if [[ '$(shell echo ${branches} | grep -o "${BRANCH_NAME}" | wc -l)' == '0' ]]; then
		$(eval BRANCH_NAME_MICROSERVICE=${DEFAULT_BRANCH_NAME})
		echo -e '\033[43mWarning\033[0m' ::: BRANCH_NAME ${BRANCH_NAME} not found, using ${DEFAULT_BRANCH_NAME}
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	else
		$(eval BRANCH_NAME_MICROSERVICE=${BRANCH_NAME})
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	fi

prepare-tryon-frontend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/tryon/frontend)
	$(eval ORGANIZATION_NAME=vistimi)
	$(eval REPOSITORY_NAME=tryon-frontend)
	$(eval DEFAULT_BRANCH_NAME=trunk)

	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME, DEFAULT_BRANCH_NAME)
	echo GET Github branches:: ${ORGANIZATION_NAME}/${REPOSITORY_NAME}
	$(eval branches=$(shell make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-list-branches GITHUB_TOKEN=${GITHUB_TOKEN} ORGANIZATION_NAME=${ORGANIZATION_NAME} REPOSITORY_NAME=${REPOSITORY_NAME}))
	if [[ '$(shell echo ${branches} | grep -o "${BRANCH_NAME}" | wc -l)' == '0' ]]; then
		$(eval BRANCH_NAME_MICROSERVICE=${DEFAULT_BRANCH_NAME})
		echo -e '\033[43mWarning\033[0m' ::: BRANCH_NAME ${BRANCH_NAME} not found, using ${DEFAULT_BRANCH_NAME}
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	else
		$(eval BRANCH_NAME_MICROSERVICE=${BRANCH_NAME})
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice-config-file \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			BRANCH_NAME=${BRANCH_NAME_MICROSERVICE}
	fi

prepare-scraper-backend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/scraper/backend)
	$(eval ORGANIZATION_NAME=vistimi)
	$(eval REPOSITORY_NAME=scraper-backend)
	$(eval REPOSITORY_CONFIG_PATH_FOLDER=config)
	$(eval DEFAULT_BRANCH_NAME=trunk)
	$(eval COMMON_NAME=defined-in-hcl)
	$(eval CLOUD_HOST=aws)

	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, TERRAGRUNT_CONFIG_PATH, FLICKR_PRIVATE_KEY, FLICKR_PUBLIC_KEY, UNSPLASH_PRIVATE_KEY, UNSPLASH_PUBLIC_KEY, PEXELS_PUBLIC_KEY, AWS_REGION_NAME, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		DEFAULT_BRANCH_NAME=${DEFAULT_BRANCH_NAME} \
		BRANCH_NAME=${BRANCH_NAME}
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-scraper-backend-env \
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
		AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
		AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
prepare-scraper-backend-env:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	$(eval MAKEFILE_OVERRIDE=$(shell find ${TERRAGRUNT_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE_OVERRIDE} prepare \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		ENV_FOLDER_PATH=${TERRAGRUNT_CONFIG_PATH} \
		CLOUD_HOST=${CLOUD_HOST} \
		COMMON_NAME=${COMMON_NAME} \
		FLICKR_PRIVATE_KEY=${FLICKR_PRIVATE_KEY} \
		FLICKR_PUBLIC_KEY=${FLICKR_PUBLIC_KEY} \
		UNSPLASH_PRIVATE_KEY=${UNSPLASH_PRIVATE_KEY} \
		UNSPLASH_PUBLIC_KEY=${UNSPLASH_PUBLIC_KEY} \
		PEXELS_PUBLIC_KEY=${PEXELS_PUBLIC_KEY} \
		AWS_REGION_NAME=${AWS_REGION_NAME} \
		AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
		AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
		PACKAGE_NAME=unimportant \
		CONFIG_FOLDER_PATH=${TERRAGRUNT_CONFIG_PATH}

prepare-scraper-frontend:
	$(eval TERRAGRUNT_CONFIG_PATH=live/aws/region/scraper/frontend)
	$(eval ORGANIZATION_NAME=vistimi)
	$(eval REPOSITORY_NAME=scraper-frontend)
	$(eval REPOSITORY_CONFIG_PATH_FOLDER=config)
	$(eval DEFAULT_BRANCH_NAME=trunk)

	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, TERRAGRUNT_CONFIG_PATH, NEXT_PUBLIC_API_URL)
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-microservice \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		GITHUB_TOKEN=${GITHUB_TOKEN} \
		REPOSITORY_CONFIG_PATH_FOLDER=${REPOSITORY_CONFIG_PATH_FOLDER} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		DEFAULT_BRANCH_NAME=${DEFAULT_BRANCH_NAME} \
		BRANCH_NAME=${BRANCH_NAME}
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-scraper-frontend-env \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
prepare-scraper-frontend-env:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	$(eval MAKEFILE_OVERRIDE=$(shell find ${TERRAGRUNT_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE_OVERRIDE} prepare \
		OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
		ENV_FOLDER_PATH=${TERRAGRUNT_CONFIG_PATH} \
		NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL} \
		PORT=$(shell yq eval '.port' ${TERRAGRUNT_CONFIG_PATH}/config_${OVERRIDE_EXTENSION}.yml)