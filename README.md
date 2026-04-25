# maestro-workflow

> 多模型協作的軟體工程 workflow plugin（for Claude Code）

讓不同階段使用不同 AI 模型發揮各自所長：Opus 規劃、Gemini + Codex + Opus 並行審議、Sonnet 實作、再用 MAGI 加權投票收斂結果。

## 現在進度

🚧 **Phase A 完成（orchestrator 基礎建設）**。Skills (`/maestro.*` slash command)、subagent、setup wizard 尚未實作 — 完整路線見 [`SPEC.md`](SPEC.md)。

目前已可用：
- 多 CLI 並行 fan-out（claude / gemini / codex）
- 事件流協定（START / RETURN / SKIP / FAIL / ALL_DONE）
- Quota / auth 自動降級偵測
- MAGI 加權投票 4 種模式（majority / supermajority / unanimous / threshold）
- nvm 相容（避開 `#!/usr/bin/env node` 找錯版本的坑）

尚未可用：
- 透過 `claude plugin add` 安裝後當 plugin 用
- `/maestro.plan` / `/maestro.work` / `/maestro.review` 等 slash command
- 自動 onboarding wizard

## 安裝（暫時用法）

```bash
git clone https://github.com/howar31/maestro-workflow.git /opt/projects/maestro-workflow
cd /opt/projects/maestro-workflow
./scripts/shared/preflight.sh
```

`preflight.sh` 會檢查 `claude` / `gemini` / `codex` 三家 CLI 是否可用，輸出 JSON 健檢報告。

### 環境需求

- macOS 或 Linux（已測試 macOS arm64）
- `bash` 3.2+（macOS 內建即可）
- `jq`、`gtimeout`（建議 `brew install jq coreutils`）
- `claude` CLI（必要）
- `gemini` CLI（選用，需 `GEMINI_API_KEY` env 或登入）
- `codex` CLI（選用）
- nvm + Node 20/22（用 npm-based CLI 時建議）

## 試跑

```bash
# Mock adapter 測試（不耗 token，驗證 fallback 邏輯）
./test/e2e-fallback.sh

# 真實 CLI 測試（每家 reviewer 跑一次 short prompt）
./test/e2e-smoke.sh
```

## 多模型架構速覽

```
你的需求
   │
   ▼
[Coordinator: Opus]            ← 你的 Claude Code session
   │ 規劃
   ▼
PLAN.md / SPEC.md
   │
   ▼
[orchestrator.sh]              ← 平行 fan-out
   ├─ claude:opus
   ├─ gemini:default
   └─ codex:default
   │
   ▼
[magi-consensus.sh]            ← 加權投票收斂
   │
   ▼
🧠 MAGI Report → 給 coordinator → 給你決策
```

## Config

預設 config 在 `config/default.json`。覆寫請放 `~/.config/maestro-workflow/config.json`。

```jsonc
{
  "xreview": {
    "reviewers": [
      {"cli": "claude", "model": "opus", "weight": 2, "required": true},
      {"cli": "gemini", "model": "default", "weight": 1, "required": false},
      {"cli": "codex",  "model": "default", "weight": 1, "required": false}
    ],
    "magi": {"mode": "majority", "degraded_mode": "warn_user"},
    "fallback_policy": "lenient",
    "min_successful_reviewers": 1
  },
  "node": {"use_nvm": true, "default_version": "22"}
}
```

完整 schema 見 [`SPEC.md`](SPEC.md)。

## 設計守則

- **顯式優先**：所有副作用大的動作都需手動觸發；plugin 不在背後悄悄改檔
- **退化透明**：reviewer 失敗時 MAGI 報告會明確標示「DEGRADED MODE」
- **領域中性**：核心流程（plan / tasks / work / review）不寫死任何技術領域；web 是第一個 add-on
- **不硬綁 Opus 4.7**：用短名 `opus` / `sonnet`，未來換代不需改 plugin

## License

MIT
