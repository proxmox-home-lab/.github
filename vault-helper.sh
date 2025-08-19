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

vault_env_main() {
  # We avoid -u for being sourced; we keep pipefail
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

  # AppRole only if we need to generate a new token
  if [[ -z "${ROLE_ID}" || -z "${SECRET_ID}" ]]; then
    log "INFO: VAULT_CLIENT_ID / VAULT_SECRET_ID not set; will try to reuse existing token."
  fi

  # ---------- Paths consistent with your HCL ----------
  local TMPDIR=".vault_config"
  local TOKEN_FILE="${TOKEN_FILE:-${TMPDIR}/token}"
  local AGENT_LOG="${TMPDIR}/agent.log"
  local CLEAN_ENV_AFTER_LOAD="${CLEAN_ENV_AFTER_LOAD:-1}"
  local ENV_CLEAN_GLOBS="${ENV_CLEAN_GLOBS:-*.env *.sh}"  # patterns to remove after loading

  umask 077
  mkdir -p "${TMPDIR}"
  : > "${AGENT_LOG}"

  # Optional TLS for CLI
  if [[ -n "${VAULT_CACERT-}" && -f "${VAULT_CACERT}" ]]; then
    export VAULT_CACERT
  fi

  # ---------- Reachability check (without token) ----------
  if ! vault status >/dev/null 2>&1; then
    die "Vault not reachable at ${VAULT_ADDR_VAL}"
    return 1
  fi

  # ---------- Token functions ----------
  valid_token() {
    # Valida un token dado (arg1) sin tocar VAULT_TOKEN actual
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
  elif [[ -s "${TOKEN_FILE}" ]] && token_to_use="$(cat "${TOKEN_FILE}")" && valid_token "${token_to_use}"; then
    export VAULT_TOKEN="${token_to_use}"
    log "🔁 Reusing token from ${TOKEN_FILE}."
  else
    # We need AppRole login to get a new one
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
  fi

  # Ensure that the token in file matches the active one
  if [[ ! -s "${TOKEN_FILE}" ]] || [[ "$(cat "${TOKEN_FILE}")" != "${token_to_use}" ]]; then
    write_token_file "${token_to_use}"
  fi

  # ---------- Run vault agent (without -once; output is decided by HCL) ----------
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
    log "Last 40 agent log lines:"
    tail -n 40 "${AGENT_LOG}" >&2 || true
    return 1
  fi

  local loaded=0
  for f in "${FILES[@]}"; do
    if [[ -s "$f" ]]; then
      log "📥 Loading environment from ${f}…"
      # shellcheck disable=SC1090
      . "$f"
      loaded=$((loaded+1))
    else
      log "INFO: ${f} is empty or missing — skipped"
    fi
  done
  (( loaded > 0 )) || { log "ERROR: No non-empty env files loaded."; tail -n 40 "${AGENT_LOG}" >&2 || true; return 1; }

  # ---------- Clean .env / .sh files if applicable ----------
  if [[ "${CLEAN_ENV_AFTER_LOAD}" == "1" || "${CLEAN_ENV_AFTER_LOAD,,}" == "true" ]]; then
    log "🧹 Cleaning temporary env files in ${TMPDIR}…"
    # Respects files explicitly listed in VAULT_ENV_FILES if you wanted to exclude them (now we remove all)
    local p
    for p in ${ENV_CLEAN_GLOBS}; do
      find "${TMPDIR}" -maxdepth 1 -type f -name "${p}" -print -exec rm -f {} \; 2>/dev/null | sed 's/^/   removed: /' >&2 || true
    done
  else
    log "INFO: CLEAN_ENV_AFTER_LOAD disabled; leaving env files on disk."
  fi

  log "✅ Done. Variables loaded into current shell."
  export VAULT_ENV_STATUS="ok"
  return 0
}

vault_env_main || { export VAULT_ENV_STATUS="error"; return $?; }