locals {
  common      = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  environment = "prod"
}
