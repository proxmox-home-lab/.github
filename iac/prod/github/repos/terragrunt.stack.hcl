# include {
#   path = find_in_parent_folders("root.hcl")
# }

# terraform {
#   source = "https://github.com/proxmox-home-lab/terraform-module-github-repository.git?ref=v2025.8.1"
# }

# inputs = {
#   name = "test"
# }

locals {
  version = "main"
}

unit "packer-ubuntu" {
  source = "github.com/proxmox-home-lab/terraform-module-github-repository?ref=${local.version}"
  path   = "packer-ubuntu"
  values = {
    version     = local.version
    name        = "packer-ubuntu"
    description = "Packer Ubuntu Template"
    private     = true
    topics      = ["packer", "ubuntu", "template"]
  }
}

unit "packer-opnsense" {
  source = "github.com/proxmox-home-lab/terraform-module-github-repository?ref=${local.version}"
  path   = "packer-opnsense"
  values = {
    version     = local.version
    name        = "packer-opnsense"
    description = "Packer Ubuntu Template"
    private     = true
    topics      = ["packer", "ubuntu", "template"]
  }
}
