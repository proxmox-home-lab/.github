include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  defaults = {
    name        = "default-repo"
    description = "Default GitHub Repository"
    version     = "main"
    auto_init   = true
  }

  values = merge(
    local.defaults,
    values
  )
}

terraform {
  # source = "git::github.com/proxmox-home-lab/.github.git//infrastructure-catalog/modules/github-repository?ref=${local.values.version}"
  source = "${get_repo_root()}/infrastructure-catalog/modules/github-repository"
}

inputs = local.values