# infrastructure

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

## yml/yaml

`yml` files can be used for configuration, as they are human readable and commonly used. There is a similarity with `hcl` language:

- array
```hcl
array = ["a", "b", "c"]
```
```yml
array:
  - a
  - b
  - c
```

- object/map
```hcl
object = { a = 1, b = 2, c = 3 }
```
```yml
object:
  a: 1
  b: 2
  c: 3
```

- array of objects
```hcl
arr_objs = [{ a = 1 }, { b = 2 }]
```
```yml
arr_objs:
  - a: 1
  - b: 2
```

If you have a file without variables, load it as follow:
```hcl
config = yamldecode(file("${get_terragrunt_dir()}/config.yml"))
```

If you have a file with variables, load it as follow:
```hcl
config = yamldecode(
  templatefile(
    "${get_terragrunt_dir()}/config.yml",
    {
      var_1 = "a"
      var_2 = "b"
    }
  )
)
```
```yml
statements:
  - name: ${var_1}
  - name: ${var_1}
  - name: ${var_1}
  - name: ${var_2}
```