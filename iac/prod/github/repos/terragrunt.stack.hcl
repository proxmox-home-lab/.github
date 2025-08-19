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
