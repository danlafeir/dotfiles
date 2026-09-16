#!/usr/bin/env bash
# PreToolUse backstop for the "never touch secret stores directly" policy in
# global-claude.md / AGENTS.md. Blocks secret-store CLI reads/writes and
# reads/edits of credential-like files; placeholder .env.example-style files
# are explicitly exempt. Fails closed: any internal error blocks too.

set -Eeuo pipefail
shopt -s nocasematch
trap 'echo "BLOCKED by secret-store-guard.sh: internal error - failing closed" >&2; exit 2' ERR

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")

deny() {
  trap - ERR
  echo "BLOCKED by secret-store-guard.sh: $1" >&2
  echo "Policy: never read or write real secret values via a secret store. Stop at configuration (env var names, IaC secret references, .env.example entries), tell the user the manual step needed to populate real values, and wait for confirmation." >&2
  exit 2
}

is_placeholder_env() {
  [[ "$1" =~ \.env\.(example|sample|template|dist)$ ]]
}

is_credential_path() {
  local p="$1"
  is_placeholder_env "$p" && return 1
  [[ "$p" =~ (^|/)\.env$ ]] && return 0
  [[ "$p" =~ (^|/)\.env\.[A-Za-z0-9_-]+$ ]] && return 0
  [[ "$p" =~ (^|/)credentials\.(json|ya?ml)$ ]] && return 0
  [[ "$p" =~ \.(pem|p12|pfx|key|jks)$ ]] && return 0
  [[ "$p" =~ (^|/)id_(rsa|ed25519|ecdsa|dsa)$ ]] && return 0
  [[ "$p" =~ (^|/)secrets\.(ya?ml|json)$ ]] && return 0
  return 1
}

SECRET_CLI_PATTERNS=(
  '\bop (read|item get|document get|inject)\b'
  '\baws secretsmanager (get-secret-value|put-secret-value|create-secret)\b'
  '\baws ssm (get-parameter|get-parameters)\b[^&|;]*--with-decryption'
  '\bgcloud secrets versions (access|add)\b'
  '\baz keyvault secret (show|download|set)\b'
  '\bvault (kv )?(get|read|put|write)\b'
  '\bsecurity find-(generic|internet)-password\b[^&|;]*-w\b'
  '\bkubectl get secrets?\b[^&|;]*-o *(json|yaml|jsonpath)'
  '\bsops (-d|--decrypt)\b'
  '\bgpg\b[^&|;]*(-d\b|--decrypt\b)'
)

READ_COMMANDS='cat|less|more|head|tail|strings|xxd|od|bat'

case "$TOOL_NAME" in
  Bash)
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
    [ -z "$COMMAND" ] && exit 0

    for pattern in "${SECRET_CLI_PATTERNS[@]}"; do
      grep -qiE "$pattern" <<< "$COMMAND" && deny "command matches a secret-store CLI pattern ($pattern)"
    done

    if grep -qiE "\b($READ_COMMANDS)\b" <<< "$COMMAND"; then
      for word in $COMMAND; do
        clean=${word//[\'\"]/}
        is_credential_path "$clean" && deny "command appears to read a credential file: $clean"
      done
    fi
    ;;

  Read|Edit|Write)
    FILE_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    [ -z "$FILE_PATH" ] && exit 0
    is_credential_path "$FILE_PATH" && deny "$TOOL_NAME targets a credential file: $FILE_PATH"
    ;;
esac

exit 0
