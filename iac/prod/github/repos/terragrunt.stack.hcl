locals {
  version = "main"
}

unit "github-actions" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & workflows"
  }
}

unit "infrastructure-catalog" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "infrastructure-catalog"
  values = {
    name        = "infrastructure-catalog"
    description = "Infrastructure Catalog which contains reusable Terraform & Terragrunt code"
  }
}

unit "packer-ubuntu" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "packer-ubuntu"
  values = {
    enabled     = false
    name        = "packer-ubuntu"
    description = "Packer Ubuntu Templates"
  }
}

unit "packer-opnsense" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "packer-opnsense"
  values = {
    enabled     = false
    name        = "packer-opnsense"
    description = "Packer OPNSense Template"
  }
}

unit "packer-images" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "packer-images"
  values = {
    name        = "packer-images"
    description = "Packer OPNSense Template"
  }
}