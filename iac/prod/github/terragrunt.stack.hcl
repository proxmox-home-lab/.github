locals {
  version = "main"
  topics  = ["iac", "github"]
  base_repos_topics = concat(
    local.topics,
    ["base"]
  )

  github_app_installation_id = get_env("GITHUB_APP_ID", "0")

  default_bypass_actors = [
    {
      actor_type  = "OrganizationAdmin"
      actor_id    = "0"
      bypass_mode = "always"
    },
    {
      actor_type  = "Integration"
      actor_id    = local.github_app_installation_id
      bypass_mode = "always"
    },
  ]
}

unit "repo-github-org" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-github-org"
  values = {
    name        = ".github"
    description = "GitHub organization defaults and IaC for proxmox-home-lab"
    auto_init   = false
    topics      = local.topics
    import_id   = ".github"
    rulesets = {
      default_branch_protection = {
        name          = "default-branch-protection"
        target        = "branch"
        enforcement   = "active"
        bypass_actors = local.default_bypass_actors
        conditions = {
          ref_name = {
            include = ["~DEFAULT_BRANCH"]
            exclude = []
          }
        }
        rules = {
          deletion         = true
          non_fast_forward = true
          pull_request = {
            dismiss_stale_reviews_on_push     = true
            require_code_owner_review         = true
            require_last_push_approval        = false
            required_approving_review_count   = 1
            required_review_thread_resolution = false
          }
          required_status_checks = {
            required_check = [
              { context = "plan / plan-gate", integration_id = null },
            ]
            strict_required_status_checks_policy = false
            do_not_enforce_on_create             = false
          }
        }
      }
    }
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "repo-github-actions" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-github-actions"
  values = {
    name        = "github-actions"
    description = "Repository to store GitHub Actions & reusable workflows"
    topics      = local.base_repos_topics
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
    description = "Packer images for Proxmox VMs"
    topics      = local.base_repos_topics
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "repo-infrastructure-core" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-repository?ref=${local.version}"
  path   = "repo-infrastructure-core"
  values = {
    name        = "infrastructure-core"
    description = "Infrastructure IaC for the Proxmox home lab — consumes modules from the infrastructure catalog"
    topics      = concat(local.base_repos_topics, ["proxmox"])
    codeowners = [
      "* @proxmox-home-lab/platform",
    ]
  }
}

unit "teams-platform" {
  source = "github.com/proxmox-home-lab/infrastructure-catalog.git//units/github-team?ref=${local.version}"
  path   = "teams-platform"
  values = {
    name        = "platform"
    description = "Platform team with permission to approve IaC deployments"
    members = {
      sergioaten = "maintainer"
    }
  }
}


