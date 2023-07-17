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

```env
AWS_REGION_NAME=***
AWS_PROFILE_NAME=***
AWS_ID=***
AWS_ROLE=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
REPOSITORIES_AWS_PROFILE_NAME=***
REPOSITORIES_AWS_ACCOUNT_ID=***
REPOSITORIES_AWS_REGION_NAME=***
REPOSITORIES_AWS_ACCESS_KEY=***
REPOSITORIES_AWS_SECRET_KEY=***
GITHUB_TOKEN=***GH_TERRA_TOKEN***
DOMAIN_NAME=my-domain.com

# scraper
FLICKR_PRIVATE_KEY=123
FLICKR_PUBLIC_KEY=123
UNSPLASH_PRIVATE_KEY=123
UNSPLASH_PUBLIC_KEY=123
PEXELS_PUBLIC_KEY=123
```

## vpc
#### cidr

- 1.0.0.0/16 scraper-backend
- 2.0.0.0/16 scraper-frontend

The second part is reserved for different regions for example.