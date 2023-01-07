# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

GIT_SHA=$(shell git rev-parse HEAD) # latest commit hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty") # If working copy has changes, append `-dirty` to hash
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

# absolute path
ROOT_PATH=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

fmt: ## Format all files
	terragrunt hclfmt

prepare: ## Setup the environment
	make prepare-account; \
	make prepare-region;
.SILENT: prepare-account
prepare-account:
	echo 'locals {' 										> 	${ROOT_PATH}/live/account.hcl; \
	echo 'aws_account_name="${AWS_PROFILE}"' 				>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'aws_account_id="${AWS_ID}"' 						>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'aws_role_name="${AWS_ROLE}"' 						>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'aws_access_key="${AWS_ACCESS_KEY}"'				>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'aws_secret_key="${AWS_SECRET_KEY}"' 				>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'github_organization="${GH_ORG}"' 					>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'github_modules_repository="${GH_MODULES_REPO}"'	>> 	${ROOT_PATH}/live/account.hcl; \
	echo 'github_modules_branch="${GH_MODULES_BRANCH}"' 	>> 	${ROOT_PATH}/live/account.hcl; \
	echo '}'												>> 	${ROOT_PATH}/live/account.hcl;
prepare-region:
	echo 'locals {' 							> 	${ROOT_PATH}/live/region/region.hcl; \
	echo 'aws_region="${AWS_REGION}"' 			>> 	${ROOT_PATH}/live/region/region.hcl; \
	echo '}'									>> 	${ROOT_PATH}/live/region/region.hcl;	

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_override.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc
