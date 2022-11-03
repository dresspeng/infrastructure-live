# infrastructure

## run

Open the project with the dev container.

Check the commands of [terraform CLI](https://www.terraform.io/cli/commands#switching-working-directory-with-chdir).

```shell
# format
terragrunt hclfmt

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
```

#### local

```shell
terragrunt apply --terragrunt-source ../../../modules//app
```

*(Note: the double slash (//) here too is intentional and required. Terragrunt downloads all the code in the folder before the double-slash into the temporary folder so that relative paths between modules work correctly. Terraform may display a “Terraform initialized in an empty directory” warning, but you can safely ignore it.)*

## nuke

[Github](https://github.com/gruntwork-io/cloud-nuke)

```
cloud-nuke aws
```

## terragrunt

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
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
```

#### production

[Github example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-example/tree/c269da5101210b0dd9927ad480b9f7fc73720642/prod/us-east-1)
Create configuration files with locals, which are used by `live/terragrunt.hcl`:

`live/account.hcl`:
```hcl
locals {
  aws_profile    = "replaceme"
  aws_account_id = "replaceme"
  aws_role_name  = "replaceme"
}
```

`live/region/region.hcl`:
```hcl
locals {
  region = "us-east-1"
}
```

`live/region/environment/environment.hcl`:
```hcl
locals {
  environment_name = "test"
  vpc_cidr_ipv4    = "10.0.0.0/16"
}
```

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