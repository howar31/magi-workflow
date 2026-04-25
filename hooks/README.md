# Optional git hooks

Drop-in git hooks that complement magi-workflow's discipline. They are
**optional** — the plugin works without them — but they help enforce the
guardrails locally.

## What's included

| Hook | What it does |
|------|--------------|
| `commit-msg` | Validates that the commit message follows [Conventional Commits](https://www.conventionalcommits.org/). Rejects commits like "wip", "fix stuff", or unprefixed subjects. |
| `pre-commit` | Auto-detects and runs the project's lint / type-check / format-check commands before committing. Exits non-zero on failure. |
| `pre-push` | Detects `WIP:` / `FIXME:` markers in commits being pushed; warns (does not block). |

All three are bash 3.2 compatible (macOS-friendly).

## Install for one repo

```bash
# from the project root
cp /opt/projects/magi-workflow/hooks/commit-msg .git/hooks/commit-msg
cp /opt/projects/magi-workflow/hooks/pre-commit .git/hooks/pre-commit
cp /opt/projects/magi-workflow/hooks/pre-push   .git/hooks/pre-push
chmod +x .git/hooks/{commit-msg,pre-commit,pre-push}
```

Or run the bundled installer:

```bash
bash /opt/projects/magi-workflow/hooks/install.sh /path/to/your/repo
```

## Install repo-wide via core.hooksPath

If you want the hooks tracked alongside your repo (so collaborators get
them automatically), copy them into `.githooks/` and run:

```bash
git config core.hooksPath .githooks
```

## Uninstall

```bash
rm .git/hooks/commit-msg .git/hooks/pre-commit .git/hooks/pre-push
```

Or, if you used `core.hooksPath`:

```bash
git config --unset core.hooksPath
```

## Skipping hooks (use sparingly)

Each hook supports `MAGI_SKIP_HOOKS=1` to bypass without removing them:

```bash
MAGI_SKIP_HOOKS=1 git commit -m "wip: experimental, will rebase"
```

Do **not** habit-form `--no-verify`. The hooks exist for a reason; if a
hook is wrong, fix the hook, don't bypass it.
