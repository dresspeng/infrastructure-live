ARG VARIANT=alpine:3.16
ARG ALPINE_VARIANT=alpine:3.16

#---------------------------------
#       BUILDER ALPINE
#---------------------------------
FROM ${ALPINE_VARIANT} as builder-alpine

ARG TARGETOS TARGETARCH

RUN apk add -q --update --no-cache git zip gzip tar dpkg make wget

# terraform
ARG TERRAFORM_VERSION=1.6.6
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip \
    && unzip terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip

# terragrunt
ARG TERRAGRUNT_VERSION=0.53.0
RUN wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_${TARGETOS}_${TARGETARCH} \
    && mv terragrunt_${TARGETOS}_${TARGETARCH} /usr/local/bin/terragrunt \
    && chmod +rx /usr/local/bin/terragrunt

# # cloud-nuke
# ARG CLOUD_NUKE_VERSION=0.33.0
# RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_${TARGETOS}_${TARGETARCH} \
#     && mv cloud-nuke_${TARGETOS}_${TARGETARCH} /usr/local/bin/cloud-nuke \
#     && chmod +rx /usr/local/bin/cloud-nuke

# infracost
# RUN curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

#-------------------------
#    RUNNER
#-------------------------
FROM ${VARIANT}

# coreutils for docker inspect
RUN apk add -q --update --no-cache make gcc libc-dev bash docker coreutils yq jq git github-cli aws-cli curl

# terraform
COPY --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# terragrunt
COPY --from=builder-alpine /usr/local/bin/terragrunt /usr/local/bin/terragrunt
RUN terragrunt --version

# # cloud-nuke
# COPY --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
# RUN cloud-nuke --version

# tflint
COPY --from=ghcr.io/terraform-linters/tflint:latest /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version

# github cli
RUN gh --version

# aws cli
RUN aws --version

# infracost
# COPY --from=builder-alpine /usr/local/bin/infracost /usr/local/bin/infracost
# RUN curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
# RUN infracost --version