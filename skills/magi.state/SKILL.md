---
name: magi.state
description: Terse "where am I, what's next" printer for magi-workflow projects. Outputs only the current project state, sprint dir (if any), suggested next command, and any active warnings — typically 3–6 lines. Use this when you're mid-flow and just need a quick orientation; reach for /magi.help when you want the full command roster, workflow diagram, and flag reference.
disable-model-invocation: true
---

# /magi.state — current state + next-step (terse)

You are the coordinator. This skill is a read-only quick-look printer.
**Do not modify any files, do not call subagents, do not invoke external
CLIs.** Output is 3–6 lines of plain text — kept minimal so the user can
scan it in under two seconds and find their way back to the workflow.

This is a deliberate subset of `/magi.help` Section E. Use `/magi.help`
when the full roster + diagram + flag list is wanted; use this skill when
only the current state and the suggested next command are needed.

## 0. Resolve paths

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[[ -z "$PLUGIN_ROOT" ]] && PLUGIN_ROOT="$(cd "$(dirname "$BASH_SOURCE[0]")/../.." 2>/dev/null && pwd)"
USER_CONFIG="$HOME/.config/magi-workflow/config.json"
```

Verify `$PLUGIN_ROOT/skills` is a directory. If not, the plugin is
installed incorrectly — print a one-line error pointing to the install
instructions and stop.

## 0.1. Output language

Read `output_language` from `$USER_CONFIG` if it exists; default `zh-TW`.
Missing config is **not** an error — like `/magi.help`, this skill must
work before `/magi.setup` has ever been run.

```bash
LANG_PREF="zh-TW"
if [[ -f "$USER_CONFIG" ]]; then
  LANG_PREF=$(jq -r '.output_language // "zh-TW"' "$USER_CONFIG" 2>/dev/null || echo "zh-TW")
fi
```

The fixed labels (`State:`, `Sprint:`, `Next:`) and state names stay
English. The parenthetical hint after the suggested command follows
`LANG_PREF`.

## 0.2. State preflight (fail-soft)

```bash
STATE_JSON=""
if STATE_RAW=$(bash "$PLUGIN_ROOT/scripts/shared/detect-state.sh" 2>/dev/null); then
  STATE_JSON="$STATE_RAW"
fi
```

Fallback rules (single-line outputs, then exit cleanly):

- `STATE_JSON` empty (not in a git repo, or the script errored before
  emitting JSON): print
  `Not in a git repository — run /magi.help for the command roster.`
- `STATE_JSON` non-empty but `jq -r .state` returns null/empty: print
  `State detection failed — run /magi.help for the static reference.`

Do **not** fall back to a roster or diagram — that is `/magi.help`'s job.

## 1. Render

<!-- KEEP IN SYNC: skills/magi.help/SKILL.md § Section E mapping table -->

Extract fields:

```bash
state=$(jq -r .state <<<"$STATE_JSON")
sprint_dir=$(jq -r '.sprint_dir // ""' <<<"$STATE_JSON")
has_diff=$(jq -r .has_diff <<<"$STATE_JSON")
hotfix=$(jq -r .hotfix_mode <<<"$STATE_JSON")
```

Mapping (state → suggested next command). **Must remain identical to
`/magi.help` Section E.** When a new state is added, update both files in
the same commit:

| State | Suggestion |
|-------|------------|
| `BOOTSTRAP` | `/magi.init`（`/magi.setup` first if no `~/.config/magi-workflow/config.json` exists） |
| `INITIALIZED` | `/magi.plan "<description>"` 或 bare `/magi.plan` 從 `docs/BACKLOG.md` 選取 |
| `PLANNING` | `/magi.tasks`（hotfix → `/magi.go`；可選 `/magi.review-plan` 先 review） |
| `PLAN_REVIEWED` | `/magi.tasks` |
| `TASKS_READY` | `/magi.go` |
| `IN_PROGRESS` | 繼續 `/magi.go`；若 `has_diff` 為 true 也可 `/magi.review-code` |
| `WORK_DONE` | `/magi.review-code` |
| `CODE_REVIEWED` | `/magi.commit` |

### Output layout

```
State: <state>
Sprint: <sprint_dir>           # omit this line entirely when sprint_dir is empty
Next:  <suggested-command>     # one line; parenthetical hint per LANG_PREF
                               # blank line follows when warnings exist
⚠ <warning.reason>
   → <warning.suggest>
⚠ <warning.reason>
   → <warning.suggest>
```

Concrete example (state=PLANNING, one warning):

```
State: PLANNING
Sprint: docs/03-add-state-skill
Next:  /magi.tasks  （或 hotfix → /magi.go；可選 /magi.review-plan 先 review）

⚠ MAGI_PLAN_REVIEW.md outdated (PLAN.md modified after last review)
   → /magi.review-plan
```

Concrete example (state=BOOTSTRAP, no warnings):

```
State: BOOTSTRAP
Next:  /magi.init  （若尚未跑過 /magi.setup,先執行 /magi.setup）
```

Surface every entry from `STATE_JSON.warnings[]` after the suggestion.
Each warning is two lines: `⚠ <reason>` followed by `   → <suggest>`.

## Conventions

- **No writes**: this skill never modifies config, state, sprint folders,
  or any project file. Read-only.
- **No subagents, no external CLIs**: just `jq` against the JSON from
  `detect-state.sh`.
- **Single purpose, no flags in v1**: do not accept `--json`,
  `--verbose`, `<state>` overrides, or any other argument. The point of
  this skill is "scan in two seconds"; every flag dilutes that. Future
  expansion is an explicit decision, not creep.
- **Mapping parity**: the state→suggestion table must stay identical to
  `/magi.help` Section E. The `<!-- KEEP IN SYNC -->` marker above
  flags this requirement; CI / human reviewers should reject changes
  that drift the two tables.
- **Output language**: fixed labels (`State:`, `Sprint:`, `Next:`) and
  state names stay English; parenthetical prose follows `LANG_PREF`.
- **Always allowed**: this skill works in every project state, including
  BOOTSTRAP and outside a git repo (with the fallback line). Reflected
  in `scripts/shared/detect-state.sh`'s `allow "magi.state"`.
