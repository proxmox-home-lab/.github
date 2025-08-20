locals {
  version = "main"
}

unit "github-actions" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & workflowss"
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

unit "packer-images" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "packer-images"
  values = {
    name        = "packer-images"
    description = "Packer Ubuntu Templates"
  }
}