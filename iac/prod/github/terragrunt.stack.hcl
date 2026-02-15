locals {
  global         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  repository_url = local.global.locals.common.repository_url
  version        = "main"
  topics         = ["iac", "github"]
  base_repos_topics = concat(
    local.topics,
    ["base"]
  )
}

unit "repo-github-actions" {
  source = "${local.repository_url}//units/github-repository?ref=${local.version}"
  path   = "repo-github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & reusable workflows"
    topics      = local.base_repos_topics
  }
}

unit "repo-infrastructure-catalog" {
  source = "${local.repository_url}//units/github-repository?ref=${local.version}"
  path   = "repo-infrastructure-catalog"
  values = {
    name        = "infrastructure-catalog"
    description = "Infrastructure Catalog which contains reusable Terraform & Terragrunt code"
    topics      = local.base_repos_topics
  }
}

unit "repo-packer-images" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-packer-images"
  values = {
    name        = "packer-images"
    description = "Packer Images for proxmox VM"
    topics      = local.base_repos_topics
  }
}

unit "teams-apply-approvers" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-teams?ref=${local.version}"
  path   = "teams-apply-approvers"
  values = {
    name        = "apply-approvers"
    description = "GitHub Org Teams for Apply Approvers"
    members = {
      sergioaten = "maintainer"
    }
  }
}
