# .github — GitHub Organization IaC

## Purpose

This repository manages the `proxmox-home-lab` GitHub organization as code using
Terragrunt (stacks/units) and OpenTofu. It owns repository settings, team memberships,
branch protection rulesets, and GitHub Actions variables for every repo in the org.

Infrastructure secrets are injected at runtime via HashiCorp Vault. There is no
persistent credentials in this repo.

---

## Architecture

```
Pull Request (iac/** path)
        │
        ▼
  [plan job] ──── Vault ──── PostgreSQL backend
        │          (secrets)   (remote state)
        │
   PR comment with plan summary
        │
   Review + Approve PR (GitHub review nativo)
        │
   Merge a main
        │
        ▼
  push a main (iac/** path)
        │
  [plan-for-apply job] → genera tfplan.binary fresco desde main
        │
  [apply job: environment=production]  ⏸ GitHub pausa, notifica iac-approvers
        │
   Reviewer aprueba en GitHub Actions UI
        │
        ▼
  [apply job continúa] ──── tfplan.binary artifact
```

**Key design decisions:**
- GitHub App auth instead of PAT — scoped, rotatable, no user dependency.
- Custom `vault-helper.sh` instead of Vault Agent — supports diverse toolchains
  (OpenTofu, GitHub CLI, etc.) without requiring a sidecar.
- PostgreSQL remote state — schema per stack path, supports concurrent stacks.
- Terragrunt stacks — declarative multi-unit orchestration with dependency ordering.
- Apply happens **after** merge to main — `main` is always the source of truth.
- GitHub Environment `production` as approval gate — natively audited in GitHub's
  deployment history, no custom comment parsing required.

---

## Directory Structure

```
.github/                    # repo root (also the org-level .github special repo)
├── .github/
│   └── workflows/
│       └── terragrunt.yaml        # CI entrypoint (calls tpl-terragrunt from github-actions)
├── iac/
│   ├── root.hcl                   # PostgreSQL backend + GitHub provider generation
│   ├── common.hcl                 # Shared locals (repository_url)
│   └── prod/
│       ├── env.hcl                # Prod environment variables
│       └── github/
│           ├── terragrunt.stack.hcl        # Stack definition: all org units
│           └── .terragrunt-stack/          # Auto-generated unit directories (gitignored)
│               ├── repo-github-actions/
│               ├── repo-infrastructure-catalog/
│               ├── repo-packer-images/
│               └── teams-apply-approvers/
├── vault-helper.sh                # Vault token lifecycle + secret injection
└── vault-agent.hcl                # Vault Agent template config (one-shot mode)
```

---

## Key Files

| File | Description |
|------|-------------|
| `iac/root.hcl` | Remote state backend (PostgreSQL) + provider generation. Schema: `{repo_name}/{stack_path}` |
| `iac/common.hcl` | Org-wide locals. Currently holds `repository_url` for the infrastructure-catalog |
| `iac/prod/env.hcl` | Prod environment locals (version pinning, env name) |
| `iac/prod/github/terragrunt.stack.hcl` | Declares all Terragrunt units for GitHub org management |
| `vault-helper.sh` | Authenticates to Vault via AppRole, renders templates, injects env vars |
| `vault-agent.hcl` | Vault Agent templates: `terraform_backend.env` and `github_provider.env` |
| `.github/workflows/terragrunt.yaml` | CI workflow — delegates to `tpl-terragrunt` reusable workflow |

---

## Development Workflow

### Prerequisites

All tools are pre-installed in the devcontainer: `tofu`, `terragrunt`, `vault`.

### Local plan/apply

```bash
# 1. Set Vault connection details
export VAULT_ADDR="https://vault.sergioaten.cloud"
export VAULT_CLIENT_ID="<approle-role-id>"
export VAULT_SECRET_ID="<approle-secret-id>"
export VAULT_AGENT_CONFIG="$(cat vault-agent.hcl)"

# 2. Load secrets from Vault into the shell environment
source vault-helper.sh

# 3. Navigate to the IaC directory
cd iac/

# 4. Plan all stacks in prod
terragrunt run --all plan --terragrunt-working-dir prod/github

# 5. Plan a specific unit only
cd prod/github/.terragrunt-stack/repo-github-actions
terragrunt plan
```

### Adding a new repository to the org

1. Open `iac/prod/github/terragrunt.stack.hcl`.
2. Add a new `unit` block following the existing pattern:
   ```hcl
   unit "repo-<name>" {
     source = "${local.repository_url}//units/github-repository?ref=${local.version}"
     path   = "repo-<name>"
     values = {
       name        = "<repo-name>"
       description = "..."
       visibility  = "public"
       has_issues  = true
     }
   }
   ```
3. Open a PR against `main`. The plan will run automatically and post a comment.
4. Review the plan comment. Request review from `iac-approvers` if needed.
5. Merge the PR. The push to `main` triggers a fresh plan + apply workflow.
6. Approve the deployment in the GitHub Actions UI (Settings → Environments → production).

### Adding a new team

Add a `unit` block using `units/github-teams` as source. Same flow as above.

---

## Commands Reference

| Command | Context |
|---------|---------|
| `terragrunt run --all plan` | Plan all units in the working dir |
| `terragrunt run --all apply` | Apply all units (avoid locally — use CI) |
| `terragrunt plan` | Plan a single unit (run from unit directory) |
| `terragrunt hcl validate` | Validate HCL syntax of all terragrunt files |
| `terragrunt hcl fmt --diff` | Check HCL formatting without writing |
| `tofu validate` | Validate OpenTofu config inside a unit |
| `tofu fmt -recursive -check` | Check Terraform formatting |

---

## Conventions

**Do:**
- Always use Terragrunt — never run `tofu apply` directly.
- Pin module versions via `?ref=<semver-tag>` in production stacks (current default `main` is a known gap — see [Known Issues](#known-issues)).
- Keep `root.hcl` and `common.hcl` minimal — they affect every unit.
- Use `vault-helper.sh` for secret injection; never hardcode credentials.

**Don't:**
- Don't add new providers directly in `root.hcl` generate block without considering all units.
- Don't commit `.env` files, `.vault_config/`, or any `terraform_*.env` files.
- Don't use personal access tokens — the GitHub App is the only auth mechanism.
- Don't apply from a local machine against production — always go through CI.
- Don't merge to `main` unless you're ready for the apply to run (it triggers automatically).

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Terragrunt | v0.99.2 | Stack/unit orchestration |
| OpenTofu | v1.11.5 | Infrastructure provisioning |
| HashiCorp Vault | v1.20.2 | Secret management |
| Terraform GitHub provider | >= 6.11.0 | GitHub resource management |
| PostgreSQL | — | Terraform remote state backend |

**Upstream:** Modules and units consumed from `proxmox-home-lab/infrastructure-catalog`.

**Downstream:** This repo manages settings for all other repos in the org.

---

## Known Issues / TODOs

- [ ] **`?ref=main` in production** — all stack units currently pin to `main`. Should migrate
  to semantic version tags (e.g., `v1.x.x`) once a release pipeline exists in
  `infrastructure-catalog`. See `iac/prod/github/terragrunt.stack.hcl`.
- [ ] **No Terraform tests** — module behavior is not validated with `.tftest.hcl` files.
- [ ] **`@main` on custom actions** — the reusable workflow calls `vault-secrets`,
  `tg-summarize`, and `merge-pr` at `@main`. Pin after versioning is in place in
  `github-actions` repo.
