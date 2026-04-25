# CLAUDE.md

Project-wide instructions for AI agents working in this repo.

## What this is
A Claude Code plugin that orchestrates multi-model code/plan reviews via parallel CLI fan-out plus MAGI weighted voting. Architecture and full feature spec live in [SPEC.md](SPEC.md).

## Status
Phase A complete: orchestrator + three adapters (claude/gemini/codex) + MAGI consensus report builder. Skills (`/maestro.*` slash commands), subagents, and the setup wizard are not yet implemented — see Phase B onward in [SPEC.md](SPEC.md).

## Run / test commands

```bash
# Aggregate CLI healthcheck (writes nothing; exits 0 if at least one ok).
./scripts/shared/preflight.sh

# Real CLI smoke test — calls every reviewer with a tiny prompt.
./test/e2e-smoke.sh

# Mock-adapter test — validates quota/auth fallback without spending tokens.
./test/e2e-fallback.sh
```

## Conventions

- **Bash 3.2 compatible.** macOS ships bash 3.2; do not use `mapfile`, `readarray`, `declare -A`, or `${var^^}`/`${var,,}`.
- **Shellcheck-friendly.** Source paths use `# shellcheck source=...` annotations.
- **`set -uo pipefail`** at the top of every script. Avoid `set -e` — explicit `|| rc=$?` patterns are clearer for orchestration.
- **Bash arrays must be initialised** (`arr=()`) before any indexed access; otherwise `set -u` aborts the script.
- **`jq`** for all JSON read/write. **Python 3** is allowed but currently unused.
- **No `setsid`** (Linux-only). Process group isolation is achieved via subshell `(...) &` + PID tracking.
- **`gtimeout` preferred over `timeout`** when both are present (BSD/GNU divergence).

### Language

| Surface | Language |
|---------|----------|
| `CLAUDE.md`, `SPEC.md`, `references/**`, `skills/**/SKILL.md`, `agents/*.md` | English |
| `README.md`, future `/maestro.setup` interactive prompts, plugin output to user | Traditional Chinese (zh-TW), configurable |
| Code comments | English |

### File naming

- SSOT documents produced **inside user projects** are uppercase: `PLAN.md`, `SPEC.md`, `TASKS.md`, `WORKS.md` (one bundle per `docs/<num>-<name>/`).
- Plugin internals follow normal kebab-case for shell scripts and `<name>.md` for skill / agent definitions.

## Adapter contract (when adding a new CLI)

Every `skills/maestro.xreview-plan/scripts/adapters/<cli>.sh` must support:

1. `<adapter> --healthcheck <config>` — print `status=ok|skip|fail` plus optional `reason=` / `version=` / `path=` lines. Exit 0 (ok), 1 (skip), 2 (fail).
2. `<adapter> run <config> <prompt-file> <log-file> <final-file> [model]` — invoke the CLI, write log + final, return:
   - `0` ok, `11` skip-quota, `12` skip-auth, `13` skip-missing, `14` skip-empty-final, anything else fail.

Adapters that wrap npm-based CLIs must source `scripts/shared/nvm-exec.sh` and run the CLI under the configured node version (avoids the macOS `/usr/bin/env node` → wrong-shebang trap).

## Workflow rules
Do not commit on the user's behalf without explicit confirmation. After completing an implementation, summarise and wait. Use Conventional Commits.
