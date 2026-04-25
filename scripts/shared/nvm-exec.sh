#!/usr/bin/env bash
# Shared library: run a command under a specific nvm node version.
# Source this file; do not execute directly.
#
# Resolution priority (matches plan):
#   1. config.node.cli_paths.<cli> (absolute path) — runs as-is
#   2. nvm exec <version> <cli-cmd...>             — preferred
#   3. PATH lookup                                 — last resort

set -euo pipefail

# Args: <config-file> <cli> <args...>
# Side effect: execs the CLI with the configured node version.
nvm_exec_cli() {
  local config="$1" cli="$2"
  shift 2

  # 1. Absolute path override
  local override
  override=$(jq -r --arg cli "$cli" '.node.cli_paths[$cli] // empty' "$config" 2>/dev/null || true)
  if [[ -n "$override" && -x "$override" ]]; then
    exec "$override" "$@"
  fi

  # 2. nvm exec wrapping (preferred)
  local use_nvm
  use_nvm=$(jq -r '.node.use_nvm // false' "$config" 2>/dev/null || echo "false")

  if [[ "$use_nvm" == "true" ]]; then
    local node_ver
    node_ver=$(jq -r --arg cli "$cli" '
      .xreview.node_version_per_cli[$cli]
      // .node.default_version
      // empty
    ' "$config" 2>/dev/null || true)

    if [[ -n "$node_ver" && -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
      # shellcheck disable=SC1091
      \. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
      # nvm exec finds the binary under the chosen node version's bin dir.
      exec nvm exec --silent "$node_ver" "$cli" "$@"
    fi
  fi

  # 3. PATH fallback
  if command -v "$cli" >/dev/null 2>&1; then
    exec "$cli" "$@"
  fi

  echo "nvm-exec: $cli not found via override / nvm / PATH" >&2
  exit 127
}

# Args: <config-file> <cli>
# Side effect: prints resolved binary path (does not exec).
resolve_cli_path() {
  local config="$1" cli="$2"

  local override
  override=$(jq -r --arg cli "$cli" '.node.cli_paths[$cli] // empty' "$config" 2>/dev/null || true)
  if [[ -n "$override" && -x "$override" ]]; then
    echo "$override"
    return 0
  fi

  local use_nvm
  use_nvm=$(jq -r '.node.use_nvm // false' "$config" 2>/dev/null || echo "false")
  if [[ "$use_nvm" == "true" ]]; then
    local node_ver
    node_ver=$(jq -r --arg cli "$cli" '
      .xreview.node_version_per_cli[$cli]
      // .node.default_version
      // empty
    ' "$config" 2>/dev/null || true)
    if [[ -n "$node_ver" ]]; then
      local nvm_bin="$HOME/.nvm/versions/node/v${node_ver}*/bin/$cli"
      # Use shell glob expansion
      for path in $nvm_bin; do
        if [[ -x "$path" ]]; then
          echo "$path"
          return 0
        fi
      done
    fi
  fi

  command -v "$cli" 2>/dev/null
}
