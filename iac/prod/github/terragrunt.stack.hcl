locals {
  version = "main"
  topics  = ["iac", "github"]
  base_repos_topics = concat(
    local.topics,
    ["base"]
  )
}

unit "repo-github-actions" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & reusable workflows"
    topics      = local.base_repos_topics
    # All content is CI/CD — platform team owns everything.
    # /.github/ is already covered by the unit default.
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "repo-infrastructure-catalog" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-infrastructure-catalog"
  values = {
    name        = "infrastructure-catalog"
    description = "Infrastructure Catalog which contains reusable Terraform & Terragrunt code"
    topics      = local.base_repos_topics
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "repo-packer-images" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-packer-images"
  values = {
    name        = "packer-images"
    description = "Packer Images for proxmox VM"
    topics      = local.base_repos_topics
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "teams-iac-approvers" {
  # path is a stable state key — keep it unchanged even when renaming the team.
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-team?ref=${local.version}"
  path   = "teams-iac-approvers"
  values = {
    name        = "platform"
    description = "Platform team with permission to approve IaC deployments"
    members = {
      sergioaten = "maintainer"
    }
  }
}
