# infrastructure

## pipeline

before terragrunt command:
  ssh -T -oStrictHostKeyChecking=accept-new git@github.com || true

## run

Open the project with the dev container.

Check the commands of [terraform CLI](https://www.terraform.io/cli/commands#switching-working-directory-with-chdir).

```shell
# format
terragrunt hclfmt
```

#### single

```shell
cd live/region/environment/<module>

# steps to create infrastructure
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply

# inspect
terragrunt show
terragrunt output

# destroy the infrastructure
terragrunt destroy

# auto approve
terragrunt <command> -auto-approve
```

#### all
The `run-all` command will use the config for the child terragrunt file. Without it, the command is executed on the current working directory.

```shell
cd live/<region>/<environment>
terragrunt run-all <command>
```

## nuke

[Github](https://github.com/gruntwork-io/cloud-nuke)

```
cloud-nuke aws
```

## terragrunt

[Docs configuration](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/)

#### dependencies

[Docs](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#dependencies-between-modules)

```shell
terragrunt graph-dependencies | dot -Tsvg > graph.svg
```

#### architecture

[Github example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-example)

## env

#### devcontainer

```
AWS_REGION=***
AWS_PROFILE=***
AWS_ID=***
AWS_ROLE=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
ENVIRONMENT_NAME=production
GITHUB_TOKEN=***
GH_ORG=KookaS
GH_MODULES_REPO=infrastructure-modules
GH_MODULES_BRANCH=master
```

:warning: The `GITHUB_TOKEN` is a default name
In [Github](https://github.com/settings/personal-access-tokens/new):
  Actions: Read and write
  Environments: Read and write
  Metadata: Read-only
  Secrets: Read and write

#### production

[Github example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-example/tree/c269da5101210b0dd9927ad480b9f7fc73720642/prod/us-east-1)

[Scraper](live/us-east-1/scraper/README.md)

## variables

Variables set in the file can be overridden at deployment:

```shell
terraform apply -var <var_to_change>=<new_value>
```

## cidr

Using `/16` for CIDR blocks means that the last two parts of the adress are customizable for subnets.

The recommendations are to use the first part of the CIDR for different VPCs projects. When ever there should be a clear abstraction, use a different number. The recommendation is to simply increment by 1 the value of the first value of the CIDR, e.g. `10.0.0.0/16` to `11.0.0.0/16`.

The second part of the cidr block is reserved for replicas of an environment. It could be for another region, for a new environment. `10.0.0.0/16` to `10.1.0.0/16`


To check the first and last ip of a CIDR block:

```hcl
cidrhost("192.168.0.0/16", 0)
cidrhost("192.168.0.0/16", -1)
```

- 1.0.0.0/16 scraper test
- 2.0.0.0/16 scraper production
- 3.0.0.0/16 scraper non-production