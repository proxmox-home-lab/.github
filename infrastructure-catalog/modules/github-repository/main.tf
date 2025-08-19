resource "github_repository" "default" {
  count                = var.enabled ? 1 : 0
  name                 = var.name
  description          = var.description
  visibility           = var.visibility
  homepage_url         = var.homepage_url
  topics               = var.topics
  auto_init            = var.auto_init
  vulnerability_alerts = var.vulnerability_alerts
}

resource "github_branch_default" "default" {
  count = var.enabled && var.auto_init ? 1 : 0

  repository = join("", github_repository.default[*].name)
  branch     = var.default_branch

  depends_on = [
    github_repository.default
  ]
}

locals {
  variables = var.enabled ? var.variables : {}
  #   secrets   = var.enabled ? { for k, v in nonsensitive(var.secrets) : k => sensitive(v) } : {} // Migrate to Vault Secrets
  labels   = var.enabled ? var.labels : {}
  rulesets = var.enabled ? var.rulesets : {}
}

resource "github_actions_variable" "default" {
  for_each      = local.variables
  repository    = join("", github_repository.default[*].name)
  variable_name = each.key
  value         = each.value
}

# Migrate to Vault Secrets
# resource "github_actions_secret" "default" {
#   for_each        = local.secrets
#   repository      = join("", github_repository.default[*].name)
#   secret_name     = each.key
#   plaintext_value = !startswith(each.value, "nacl:") ? each.value : null
#   encrypted_value = startswith(each.value, "nacl:") ? trimprefix(each.value, "nacl:") : null
# }

resource "github_issue_label" "default" {
  for_each    = local.labels
  repository  = join("", github_repository.default[*].name)
  name        = each.key
  color       = trimprefix(each.value.color, "#")
  description = each.value.description
}

locals {
  organization_roles_map = {
    "maintain" = "2"
    "write"    = "4"
    "admin"    = "5"
  }

  ruleset_rules_teams = flatten([
    for e, c in local.rulesets :
    c.bypass_actors != null ? compact([for b in c.bypass_actors : b.actor_type == "Team" ? b.actor_id : null]) : []
  ])

  ruleset_conditions_refs_prefix = {
    "branch" = "refs/heads/"
    "tag"    = "refs/tags/"
  }
}

data "github_team" "ruleset_rules_teams" {
  for_each = toset(local.ruleset_rules_teams)

  slug = each.value
}

resource "github_repository_ruleset" "default" {
  for_each = local.rulesets

  repository = join("", github_repository.default[*].name)

  name        = each.value.name
  enforcement = each.value.enforcement
  target      = each.value.target

  conditions {
    ref_name {
      include = [
        for c in each.value.conditions.ref_name.include :
        startswith(c, local.ruleset_conditions_refs_prefix[each.value.target]) || c == "~DEFAULT_BRANCH" || c == "~ALL" ? c :
        format("%s%s", local.ruleset_conditions_refs_prefix[each.value.target], c)
      ]
      exclude = [
        for c in each.value.conditions.ref_name.exclude :
        startswith(c, local.ruleset_conditions_refs_prefix[each.value.target]) ? c :
        format("%s%s", local.ruleset_conditions_refs_prefix[each.value.target], c)
      ]
    }
  }

  dynamic "bypass_actors" {
    for_each = each.value.bypass_actors
    content {
      bypass_mode = bypass_actors.value.bypass_mode
      actor_id = (bypass_actors.value.actor_type == "OrganizationAdmin" ? "0" :
        bypass_actors.value.actor_type == "RepositoryRole" ? local.organization_roles_map[bypass_actors.value.actor_id] :
        bypass_actors.value.actor_type == "Team" ? data.github_team.ruleset_rules_teams[bypass_actors.value.actor_id].id :
      bypass_actors.value.actor_id)
      actor_type = bypass_actors.value.actor_type
    }
  }

  dynamic "rules" {
    for_each = each.value.rules != null ? [each.value.rules] : []
    content {
      creation         = rules.value.creation
      deletion         = rules.value.deletion
      non_fast_forward = rules.value.non_fast_forward

      dynamic "branch_name_pattern" {
        for_each = rules.value.branch_name_pattern != null ? [rules.value.branch_name_pattern] : []
        content {
          operator = branch_name_pattern.value.operator
          pattern  = branch_name_pattern.value.pattern
          negate   = branch_name_pattern.value.negate
          name     = branch_name_pattern.value.name
        }
      }
      dynamic "commit_author_email_pattern" {
        for_each = rules.value.commit_author_email_pattern != null ? [rules.value.commit_author_email_pattern] : []
        content {
          operator = commit_author_email_pattern.value.operator
          pattern  = commit_author_email_pattern.value.pattern
          negate   = commit_author_email_pattern.value.negate
          name     = commit_author_email_pattern.value.name
        }
      }
      dynamic "commit_message_pattern" {
        for_each = rules.value.commit_message_pattern != null ? [rules.value.commit_message_pattern] : []
        content {
          operator = commit_message_pattern.value.operator
          pattern  = commit_message_pattern.value.pattern
          negate   = commit_message_pattern.value.negate
          name     = commit_message_pattern.value.name
        }
      }
      dynamic "committer_email_pattern" {
        for_each = rules.value.committer_email_pattern != null ? [rules.value.committer_email_pattern] : []
        content {
          operator = committer_email_pattern.value.operator
          pattern  = committer_email_pattern.value.pattern
          negate   = committer_email_pattern.value.negate
          name     = committer_email_pattern.value.name
        }
      }

      dynamic "merge_queue" {
        for_each = rules.value.merge_queue != null ? [rules.value.merge_queue] : []
        content {
          check_response_timeout_minutes    = merge_queue.value.check_response_timeout_minutes
          grouping_strategy                 = merge_queue.value.grouping_strategy
          max_entries_to_build              = merge_queue.value.max_entries_to_build
          max_entries_to_merge              = merge_queue.value.max_entries_to_merge
          merge_method                      = merge_queue.value.merge_method
          min_entries_to_merge              = merge_queue.value.min_entries_to_merge
          min_entries_to_merge_wait_minutes = merge_queue.value.min_entries_to_merge_wait_minutes
        }
      }

      dynamic "pull_request" {
        for_each = rules.value.pull_request != null ? [rules.value.pull_request] : []
        content {
          dismiss_stale_reviews_on_push     = pull_request.value.dismiss_stale_reviews_on_push
          require_code_owner_review         = pull_request.value.require_code_owner_review
          require_last_push_approval        = pull_request.value.require_last_push_approval
          required_approving_review_count   = pull_request.value.required_approving_review_count
          required_review_thread_resolution = pull_request.value.required_review_thread_resolution
        }
      }

      dynamic "required_deployments" {
        for_each = rules.value.required_deployments != null ? [rules.value.required_deployments] : []
        content {
          required_deployment_environments = required_deployments.value.required_deployment_environments
        }
      }

      dynamic "required_status_checks" {
        for_each = rules.value.required_status_checks != null ? [rules.value.required_status_checks] : []
        content {
          dynamic "required_check" {
            for_each = required_status_checks.value.required_check
            content {
              context        = required_check.value.context
              integration_id = required_check.value.integration_id
            }
          }
          strict_required_status_checks_policy = required_status_checks.value.strict_required_status_checks_policy
          do_not_enforce_on_create             = required_status_checks.value.do_not_enforce_on_create
        }
      }

      dynamic "tag_name_pattern" {
        for_each = rules.value.tag_name_pattern != null ? [rules.value.tag_name_pattern] : []
        content {
          operator = tag_name_pattern.value.operator
          pattern  = tag_name_pattern.value.pattern
          negate   = tag_name_pattern.value.negate
          name     = tag_name_pattern.value.name
        }
      }
    }
  }
}
