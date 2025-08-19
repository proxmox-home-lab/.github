#!/usr/bin/env bash
# Orchestrates: (re)use of token -> token_file -> vault agent (external HCL) -> load .env(s) -> clean .env/.sh
# Requirements: vault, jq
# Usage: source vault-helper.sh

# Must be executed by source
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "❌ This script must be sourced: source ${BASH_SOURCE[0]}"
  exit 1
fi

# Clean inherited traps that may cause 'unbound variable' with strict shells
trap - RETURN 2>/dev/null || true

# ---------- Mask utils (for GitHub Actions) ----------
gh_mask() {
  local val="${1-}"
  if [[ -n "$val" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::add-mask::%s\n' "$val"
  fi
}

gh_mask_file() {
  local file="${1-}"
  if [[ -f "$file" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
    local content
    content="$(cat "$file")" || return 0
    [[ -n "$content" ]] && printf '::add-mask::%s\n' "$content"
  fi
}

vault_env_main() {
  set -o pipefail

  # ---------- Utils ----------
  log() { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
  die() { log "ERROR: $*"; return 1; }
  need_bin() { command -v "$1" >/dev/null 2>&1 || { die "Command '$1' not found in PATH"; return 1; }; }

  need_bin vault || return $?
  need_bin jq    || return $?

  # ---------- Inputs ----------
  local VAULT_ADDR_VAL="${VAULT_ADDR-}"
  local ROLE_ID="${VAULT_CLIENT_ID-}"
  local SECRET_ID="${VAULT_SECRET_ID-}"
  local AGENT_CFG="${VAULT_AGENT_CONFIG-}"
  [[ -n "${VAULT_ADDR_VAL}" ]] || { die "VAULT_ADDR must be set"; return 1; }
  [[ -n "${AGENT_CFG}" && -f "${AGENT_CFG}" ]] || { die "VAULT_AGENT_CONFIG must point to an existing HCL file"; return 1; }

  # ---------- Paths ----------
  local TMPDIR=".vault_config"
  local TOKEN_FILE="${TOKEN_FILE:-${TMPDIR}/token}"
  local AGENT_LOG="${TMPDIR}/agent.log"
  local CLEAN_ENV_AFTER_LOAD="${CLEAN_ENV_AFTER_LOAD:-1}"
  local ENV_CLEAN_GLOBS="${ENV_CLEAN_GLOBS:-*.env *.sh}"

  umask 077
  mkdir -p "${TMPDIR}"
  : > "${AGENT_LOG}"

  # Optional TLS
  if [[ -n "${VAULT_CACERT-}" && -f "${VAULT_CACERT}" ]]; then
    export VAULT_CACERT
    gh_mask_file "${VAULT_CACERT}"
  fi

  # ---------- Reachability ----------
  if ! vault status >/dev/null 2>&1; then
    die "Vault not reachable at ${VAULT_ADDR_VAL}"
    return 1
  fi

  # ---------- Token functions ----------
  valid_token() {
    local t="$1"
    [[ -z "$t" ]] && return 1
    VAULT_TOKEN="$t" vault token lookup >/dev/null 2>&1
  }

  write_token_file() {
    printf '%s' "$1" > "${TOKEN_FILE}" && chmod 600 "${TOKEN_FILE}"
  }

  # ---------- Reuse token if possible ----------
  local token_to_use=""
  if [[ -n "${VAULT_TOKEN-}" ]] && valid_token "${VAULT_TOKEN}"; then
    token_to_use="${VAULT_TOKEN}"
    log "🔁 Reusing VAULT_TOKEN from environment."
    gh_mask "${token_to_use}"
  elif [[ -s "${TOKEN_FILE}" ]] && token_to_use="$(cat "${TOKEN_FILE}")" && valid_token "${token_to_use}"; then
    export VAULT_TOKEN="${token_to_use}"
    log "🔁 Reusing token from ${TOKEN_FILE}."
    gh_mask "${token_to_use}"
    gh_mask_file "${TOKEN_FILE}"
  else
    [[ -n "${ROLE_ID}" && -n "${SECRET_ID}" ]] || { die "No valid token found and AppRole creds missing (VAULT_CLIENT_ID/VAULT_SECRET_ID)"; return 1; }
    log "🔑 Logging in to Vault with AppRole…"
    local LOGIN_JSON
    if ! LOGIN_JSON=$(vault write -format=json auth/approle/login role_id="${ROLE_ID}" secret_id="${SECRET_ID}"); then
      die "Vault login failed (approle)"; return 1
    fi
    token_to_use="$(echo "${LOGIN_JSON}" | jq -r '.auth.client_token // empty')"
    [[ -n "${token_to_use}" ]] || { die "Empty client_token"; return 1; }
    export VAULT_TOKEN="${token_to_use}"
    write_token_file "${token_to_use}"
    log "✅ Login OK. New VAULT_TOKEN exported and saved to ${TOKEN_FILE}."
    gh_mask "${token_to_use}"
    gh_mask_file "${TOKEN_FILE}"
  fi

  # ---------- Run vault agent ----------
  log "🚀 Running vault agent with config: ${AGENT_CFG}"
  if ! vault agent -log-level=info -config "${AGENT_CFG}" >"${AGENT_LOG}" 2>&1; then
    log "ERROR: vault agent failed. Last 40 log lines:"
    tail -n 40 "${AGENT_LOG}" >&2 || true
    die "vault agent failed (review HCL, token_file path and template destinations)"
    return 1
  fi

# ---------- Load generated files ----------
local -a FILES=()
if [[ -n "${VAULT_ENV_FILES-}" ]]; then
  IFS=':' read -r -a FILES <<< "${VAULT_ENV_FILES}"
else
  while IFS= read -r f; do FILES+=("$f"); done < <(find "${TMPDIR}" -maxdepth 1 -type f \( -name "*.env" -o -name "*.sh" \) | sort)
fi

if ((${#FILES[@]} == 0)); then
  log "ERROR: No env files found under ${TMPDIR}. Check template.destinations in ${AGENT_CFG}."
  log "Last 40 agent log lines:"; tail -n 40 "${AGENT_LOG}" >&2 || true
  return 1
fi

declare -A LOADED_KEYS=()

local loaded=0
for f in "${FILES[@]}"; do
  if [[ -s "$f" ]]; then
    log "📥 Loading environment from ${f}…"

    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      gh_mask_file "$f"
      while IFS= read -r line; do
        [[ "$line" =~ ^#|^$ ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        [[ -n "$val" ]] && gh_mask "$val"
        [[ -n "$key" ]] && LOADED_KEYS["$key"]=1
      done < "$f"
    fi

    . "$f"
    loaded=$((loaded+1))
  else
    log "INFO: ${f} is empty or missing — skipped"
  fi
done
(( loaded > 0 )) || { log "ERROR: No non-empty env files loaded."; tail -n 40 "${AGENT_LOG}" >&2 || true; return 1; }

# ---------- Clean temporary env files ----------
if [[ "${CLEAN_ENV_AFTER_LOAD}" == "1" || "${CLEAN_ENV_AFTER_LOAD,,}" == "true" ]]; then
  log "🧹 Cleaning temporary env files in ${TMPDIR}…"
  local p
  for p in ${ENV_CLEAN_GLOBS}; do
    find "${TMPDIR}" -maxdepth 1 -type f -name "${p}" -print -exec rm -f {} \; 2>/dev/null | sed 's/^/   removed: /' >&2 || true
  done
else
  log "INFO: CLEAN_ENV_AFTER_LOAD disabled; leaving env files on disk."
fi

# ---------- Optional: post-mask exactly the keys that came from Vault .env ----------
if [[ "${GITHUB_ACTIONS:-}" == "true" && ${#LOADED_KEYS[@]} -gt 0 ]]; then
  for k in "${!LOADED_KEYS[@]}"; do
    v="${!k-}"
    [[ -n "$v" ]] && gh_mask "$v"
  done
fi

  log "✅ Done. Variables loaded into current shell."
  export VAULT_ENV_STATUS="ok"
  return 0
}

vault_env_main || { export VAULT_ENV_STATUS="error"; return $?; }