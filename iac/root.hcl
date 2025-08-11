locals {
  env_vars       = try(read_terragrunt_config(find_in_parent_folders("env.hcl")))
  component_vars = try(read_terragrunt_config(find_in_parent_folders("component.hcl")), {})

  combined_vars = merge(local.component_vars, local.env_vars)
}

inputs = local.combined_vars.locals
