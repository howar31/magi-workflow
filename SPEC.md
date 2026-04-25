# SPEC.md

Authoritative architecture and feature spec of `maestro-workflow`. Update when behavior changes.

## Vision

A Claude Code plugin that drives a five-stage engineering workflow with each stage backed by the most appropriate model:

1. **Plan** — Opus-class coordinator drafts `PLAN.md` / `SPEC.md`.
2. **Plan review (xreview)** — three external CLIs (claude / gemini / codex) review the plan in parallel. MAGI weighted voting decides which findings are adopted.
3. **Tasks** — coordinator decomposes the approved plan into `TASKS.md`.
4. **Implementation** — Sonnet-class subagent runs TDD against `TASKS.md`, updating `WORKS.md`.
5. **Code review** — same MAGI-weighted multi-CLI fan-out applied to the diff.

A `/maestro.setup` wizard runs once at install time to inspect installed CLIs, write `~/.config/maestro-workflow/config.json`, and surface unavailable reviewers.

## Implementation phases

| Phase | Deliverable | Status |
|-------|-------------|--------|
| A | Orchestrator + three adapters + MAGI consensus + tests | ✅ done |
| B | Setup wizard + 5 core skills + override flags | ⏳ not started |
| C | Subagents (`maestro-developer` / `maestro-reviewer`) | ⏳ |
| D | Web-domain skills (frontend / backend / infra / ci) | ⏳ |
| E | Externalised config + zh-TW README + optional hooks | ⏳ |

## Phase A architecture (current)

### Components

```
maestro-workflow/
├── .claude-plugin/plugin.json                 # plugin metadata
├── config/default.json                        # reviewer list, MAGI rules, fallback policy
├── scripts/shared/
│   ├── error-patterns.sh                      # quota/auth pattern matchers (sourced lib)
│   ├── extract-final.sh                       # per-CLI final-message extractors (sourced lib + CLI entry)
│   ├── nvm-exec.sh                            # nvm-aware CLI path resolution (sourced lib)
│   ├── preflight.sh                           # aggregated CLI healthcheck → JSON
│   └── magi-consensus.sh                      # consolidates per-reviewer outputs into a MAGI report
├── skills/maestro.xreview-plan/scripts/
│   ├── orchestrator.sh                        # parallel fan-out + event stream + fallback policy
│   └── adapters/{claude,gemini,codex}.sh      # CLI-specific run + healthcheck
└── test/
    ├── e2e-fallback.sh                        # mock adapters → validates quota/auth SKIP semantics
    └── e2e-smoke.sh                           # real CLIs → validates end-to-end pipeline
```

### Orchestrator event protocol

The orchestrator emits one event per line on stdout, mirrored to `<workdir>/events.log`:

| Event | Payload |
|-------|---------|
| `WORKDIR <path>` | First event; consumers parse this to find artifacts. |
| `START <cli:model> <log-path>` | Reviewer task started. |
| `RETURN <cli:model> <log-path> <final-path>` | Reviewer succeeded; `final-path` is non-empty. |
| `SKIP <cli:model> reason=<short> log=<path>` | Reviewer skipped (`quota` / `auth` / `missing`). |
| `FAIL <cli:model> exit=<n> log=<path> final=<path> [reason=<short>]` | Hard failure. |
| `ALL_DONE successful=N skipped=M failed=K policy_pass=true|false workdir=<path> [signal=<name>]` | Terminal event. |

Exit codes: `0` policy passed, `2` policy failed, `3` config error, `130` interrupted by signal.

### Adapter contract

Every adapter at `skills/maestro.xreview-plan/scripts/adapters/<cli>.sh` supports two modes:

1. `--healthcheck <config>` → prints `key=value` lines (`status` / `reason` / `version` / `path`) and exits 0/1/2.
2. `run <config> <prompt-file> <log-file> <final-file> [model]` → exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success — `final-file` non-empty. |
| 11 | SKIP — quota / rate-limit detected via `xreview.quota_error_patterns.<cli>`. |
| 12 | SKIP — auth failure detected via `xreview.auth_error_patterns.<cli>`. |
| 13 | SKIP — CLI binary not found. |
| 14 | SKIP — exit 0 but `final-file` empty (content-layer failure). |
| 1+ | FAIL — anything else. |

### Fallback policy

Defined in `config.xreview.fallback_policy` (`lenient` default | `strict`) and `config.xreview.min_successful_reviewers`. The orchestrator computes `policy_pass`:

- `false` if any `required: true` reviewer did not RETURN.
- `false` under `strict` if any reviewer was SKIP or FAIL.
- `false` if `successful < min_successful_reviewers`.
- `true` otherwise.

### MAGI weighted voting (consensus report)

`scripts/shared/magi-consensus.sh` reads orchestrator artifacts and produces `magi-report.md` (human) + `magi-report.json` (machine). It does **not** semantically deduplicate issues — that is the coordinator agent's job. It does:

- Compute `total_weight` (configured) and `ok_weight` (successful reviewers only).
- Resolve `mode` from config (or `--mode` override): `majority` (>50% of ok_weight) / `supermajority` (≥2/3) / `unanimous` (=ok_weight) / `threshold:N` (absolute).
- Bundle every successful reviewer's `final.txt` with weight metadata.
- Flag DEGRADED MODE when `ok_count < configured_count` or `ok_count == 1`.
- Append explicit instructions for the coordinator on how to apply the voting rule.

### Node / nvm strategy

`scripts/shared/nvm-exec.sh` resolves CLI paths in priority order:

1. `config.node.cli_paths.<cli>` (absolute path).
2. `nvm exec <version> <cli>` if `config.node.use_nvm == true` and `${NVM_DIR}/nvm.sh` exists. `version` is `config.xreview.node_version_per_cli.<cli>` falling back to `config.node.default_version`.
3. `PATH` lookup via `command -v`.

This avoids the macOS pitfall where `gemini`'s shebang `#!/usr/bin/env node` resolves to whatever `node` is first in `$PATH` (often v18 from a system install) instead of the v22 the package was built against.

### Config schema

```jsonc
{
  "xreview": {
    "reviewers": [
      {"cli": "claude", "model": "opus", "weight": 2, "required": true},
      {"cli": "gemini", "model": "default", "weight": 1, "required": false},
      {"cli": "codex",  "model": "default", "weight": 1, "required": false}
    ],
    "magi": {
      "mode": "majority",        // majority | supermajority | unanimous | threshold
      "threshold": null,         // required when mode == "threshold"
      "degraded_mode": "warn_user"
    },
    "fallback_policy": "lenient",          // lenient | strict
    "min_successful_reviewers": 1,
    "timeout_seconds": 3000,
    "quota_error_patterns": {"<cli>": ["regex", ...]},
    "auth_error_patterns":  {"<cli>": ["regex", ...]}
  },
  "node": {
    "use_nvm": true,
    "default_version": "22",
    "cli_paths": {}                        // absolute path overrides per cli
  },
  "output_language": "zh-TW"
}
```

Resolution order: `$MAESTRO_CONFIG_PATH` → `~/.config/maestro-workflow/config.json` → `<plugin>/config/default.json`.

## Tests

| Test | What it covers |
|------|----------------|
| `test/e2e-fallback.sh` | Mock adapters simulate RETURN / SKIP-quota / SKIP-auth; verifies event counts, `policy_pass=true` under lenient + 1 ok, MAGI degraded warning. Token-free. |
| `test/e2e-smoke.sh` | Real CLIs against a one-sentence prompt; verifies preflight + orchestrator + MAGI report end-to-end. Costs a small number of tokens per reviewer. |

Run `bash -n <script>` to syntax-check any shell file.

## Out of scope (Phase A)

- Slash commands (`/maestro.plan`, `/maestro.work`, etc.) — Phase B.
- Subagents — Phase C.
- Web-domain skills — Phase D.
- Setup wizard — Phase B.
- Semantic issue dedup / final consolidated MAGI verdict — done by the coordinator agent in Phase B.
