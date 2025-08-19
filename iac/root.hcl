locals {
  env_vars = try(read_terragrunt_config(find_in_parent_folders("env.hcl")))
}

inputs = merge(
  local.env_vars.locals
)

remote_state {
  backend = "pg"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    schema_name = "${path_relative_to_include()}/tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
    provider "github" {
      app_auth {}
    }
  EOF
}