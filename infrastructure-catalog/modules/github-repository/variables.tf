variable "enabled" {
  description = "Enable or disable the repository creation"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the repository"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,38}$", var.name))
    error_message = "Repository name must be alphanumeric and can contain hyphens, but cannot start or end with a hyphen and must be between 1 and 39 characters long."
  }
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = null
}

variable "visibility" {
  description = "Visibility of the repository. Must be public, private, or internal."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "Repository visibility must be public, private or internal"
  }
}

variable "homepage_url" {
  description = "Homepage URL of the repository"
  type        = string
  default     = null
}

variable "auto_init" {
  description = "Auto-initialize the repository"
  type        = bool
  default     = false
}

variable "default_branch" {
  description = "Default branch name"
  type        = string
  default     = "main"
}

variable "vulnerability_alerts" {
  description = "Enable vulnerability alerts for the repository"
  type        = bool
  default     = true
}

variable "topics" {
  description = "List of repository topics"
  type        = list(string)
  default     = []
}

variable "variables" {
  description = "Environment variables for the repository"
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = var.variables == null || alltrue([for k, v in var.variables : can(regex("^[a-zA-Z0-9_]+$", k))])
    error_message = "Variable names must be alphanumeric and underscores only, can not start with a number"
  }
}

# Migrate to Vault Secrets
# variable "secrets" {
#   description = "Secrets for the repository (if prefixed with nacl: it should be encrypted value using the GitHub public key in Base64 format. Read more: https://docs.github.com/en/actions/security-for-github-actions/encrypted-secrets)"
#   type        = map(string)
#   default     = {}
#   sensitive   = true
#   nullable    = false

#   validation {
#     condition     = var.secrets == null || alltrue([for k, v in var.secrets : can(regex("^[a-zA-Z0-9_]+$", k))])
#     error_message = "Secret names must be alphanumeric and underscores only, can not start with a number"
#   }
# }

variable "labels" {
  description = "A map of labels to configure for the repository"
  type = map(object({
    color       = string
    description = string
  }))
  default  = {}
  nullable = false
}

variable "rulesets" {
  description = "A map of rulesets to configure for the repository"
  type = map(object({
    name = string
    // disabled, active
    enforcement = string
    // branch, tag
    target = string
    bypass_actors = optional(list(object({
      // always, pull_request
      bypass_mode = string
      actor_id    = optional(string, null)
      // RepositoryRole, Team, Integration, OrganizationAdmin
      actor_type = string
    })), [])
    conditions = object({
      ref_name = object({
        // Supports ~DEFAULT_BRANCH or ~ALL
        include = optional(list(string), [])
        exclude = optional(list(string), [])
      })
    })
    rules = object({
      branch_name_pattern = optional(object({
        // starts_with, ends_with, contains, regex
        operator = string
        pattern  = string
        name     = optional(string, null)
        negate   = optional(bool, false)
      }), null),
      commit_author_email_pattern = optional(object({
        // starts_with, ends_with, contains, regex
        operator = string
        pattern  = string
        name     = optional(string, null)
        negate   = optional(bool, false)
      }), null),
      creation         = optional(bool, false),
      deletion         = optional(bool, false),
      non_fast_forward = optional(bool, false),
      required_pull_request_reviews = optional(object({
        dismiss_stale_reviews           = bool
        required_approving_review_count = number
      }), null),
      commit_message_pattern = optional(object({
        // starts_with, ends_with, contains, regex
        operator = string
        pattern  = string
        name     = optional(string, null)
        negate   = optional(bool, false)
      }), null),
      committer_email_pattern = optional(object({
        // starts_with, ends_with, contains, regex
        operator = string
        pattern  = string
        name     = optional(string, null)
        negate   = optional(bool, false)
      }), null),
      merge_queue = optional(object({
        check_response_timeout_minutes = optional(number, 60)
        // ALLGREEN, HEADGREEN
        grouping_strategy    = string
        max_entries_to_build = optional(number, 5)
        max_entries_to_merge = optional(number, 5)
        // MERGE, SQUASH, REBASE
        merge_method                      = optional(string, "MERGE")
        min_entries_to_merge              = optional(number, 1)
        min_entries_to_merge_wait_minutes = optional(number, 5)
      }), null),
      pull_request = optional(object({
        dismiss_stale_reviews_on_push     = optional(bool, false)
        require_code_owner_review         = optional(bool, false)
        require_last_push_approval        = optional(bool, false)
        required_approving_review_count   = optional(number, 0)
        required_review_thread_resolution = optional(bool, false)
      }), null),
      required_deployments = optional(object({
        required_deployment_environments = optional(list(string), [])
      }), null),
      required_status_checks = optional(object({
        required_check = list(object({
          context        = string
          integration_id = optional(number, null)
        }))
        strict_required_status_checks_policy = optional(bool, false)
        do_not_enforce_on_create             = optional(bool, false)
      }), null),
      tag_name_pattern = optional(object({
        // starts_with, ends_with, contains, regex
        operator = string
        pattern  = string
        name     = optional(string, null)
        negate   = optional(bool, false)
      }), null),
    }),
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.rulesets : can(regex("^[a-zA-Z0-9_]+$", k))])
    error_message = "Ruleset names must be alphanumeric and underscores only, can not start with a number"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : contains(["disabled", "active", "evaluate"], v.enforcement)])
    error_message = "Ruleset enforcement must be disabled, active, or evaluate"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : contains(["branch", "tag"], v.target)])
    error_message = "Ruleset target must be branch or tag"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["always", "pull_request"], v.bypass_actors.bypass_mode), true)])
    error_message = "Ruleset bypass mode must be always or pull_request"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["RepositoryRole", "Team", "Integration", "OrganizationAdmin"], v.bypass_actors.actor_type), true)])
    error_message = "Ruleset actor type must be RepositoryRole, Team, Integration or OrganizationAdmin"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["starts_with", "ends_with", "contains", "regex"], v.rules.branch_name_pattern.operator), true)])
    error_message = "Ruleset branch name pattern operator must be starts_with, ends_with, contains or regex"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : v.target == "branch" || try(v.rules.branch_name_pattern == null, true)])
    error_message = "Ruleset branch name pattern can be specified only for branch rulesets"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["starts_with", "ends_with", "contains", "equals", "regex"], v.rules.commit_author_email_pattern.operator), true)])
    error_message = "Ruleset commit author email pattern operator must be starts_with, ends_with, contains, equals or regex"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["starts_with", "ends_with", "contains", "equals", "regex"], v.rules.commit_message_pattern.operator), true)])
    error_message = "Ruleset commit message pattern operator must be starts_with, ends_with, contains, equals or regex"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["starts_with", "ends_with", "contains", "equals", "regex"], v.rules.committer_email_pattern.operator), true)])
    error_message = "Ruleset committer email pattern operator must be starts_with, ends_with, contains, equals or regex"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["ALLGREEN", "HEADGREEN"], v.rules.merge_queue.grouping_strategy), true)])
    error_message = "Ruleset merge queue grouping strategy must be ALLGREEN or HEADGREEN"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["MERGE", "SQUASH", "REBASE"], v.rules.merge_queue.merge_method), true)])
    error_message = "Ruleset merge queue merge method must be MERGE, SQUASH or REBASE"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : v.rules.merge_queue == null || alltrue([for c in v.conditions.ref_name.include : can(!strcontains(c, "*") && !strcontains(c, "~ALL"))])])
    error_message = "Ruleset merge queue condition mush point to specific branch"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : try(contains(["starts_with", "ends_with", "contains", "regex"], v.rules.tag_name_pattern.operator), true)])
    error_message = "Ruleset branch name pattern operator must be starts_with, ends_with, contains or regex"
  }

  validation {
    condition     = alltrue([for k, v in var.rulesets : v.target == "tag" || try(v.rules.tag_name_pattern == null, true)])
    error_message = "Ruleset tag name pattern can be specified only for tag rulesets"
  }
}
