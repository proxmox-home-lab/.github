unit "github-actions" {
  source = "${get_repo_root()}/infrastructure-catalog/units/github-repository"
  path   = "github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & workflows"
  }
}

unit "infrastructure-catalog" {
  source = "${get_repo_root()}/infrastructure-catalog/units/github-repository"
  path   = "infrastructure-catalog"
  values = {
    name        = "infrastructure-catalog"
    description = "Infrastructure Catalog which contains reusable Terraform & Terragrunt code"
  }
}

unit "packer-ubuntu" {
  # source = "github.com/proxmox-home-lab/terraform-module-github-repository?ref=${local.version}"
  source = "${get_repo_root()}/infrastructure-catalog/units/github-repository"
  path   = "packer-ubuntu"
  values = {
    name        = "packer-ubuntu"
    description = "Packer Ubuntu Templates"
  }
}

unit "packer-opnsense" {
  # source = "github.com/proxmox-home-lab/terraform-module-github-repository?ref=${local.version}"
  source = "${get_repo_root()}/infrastructure-catalog/units/github-repository"
  path   = "packer-opnsense"
  values = {
    name        = "packer-opnsense"
    description = "Packer OPNSense Template"
  }
}
