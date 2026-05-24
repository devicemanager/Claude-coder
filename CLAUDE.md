# Claude Code — Free Model Config

Configure Claude Code to run on free/local LLMs through a LiteLLM proxy, with
disciplined engineering workflows built in.

## Engineering Process

These rules apply to every session in this repo.

**Before touching code:**

| Situation | Do this first |
|-----------|---------------|
| Bug report / crash / test failure | Load `debug-mantra` / `systematic-debugging` |
| Feature request / new component | Load `brainstorming` + `writing-plans` |
| Any implementation | Load `test-driven-development` |

**While working:**

- Make focused, single-purpose commits
- Follow existing code conventions (read surrounding files first)
- Don't add comments unless asked

**Before claiming done:**

- Load `verification-before-completion` — run lint, typecheck, and tests
- Load `scrutinize` for PRs and non-trivial diffs

**After fixing a bug:**

- Load `post-mortem` — write root cause, mechanism, fix, validation

**Code review:**

- For requesting review: load `requesting-code-review`
- For receiving review: load `receiving-code-review`

**Status / leadership updates:**

- Load `management-talk` to rewrite engineering updates for VPs, PMs, etc.

## Skills Reference

Skills are installed globally in your skills directory
(`~/.config/opencode/skills/` or `~/.claude/skills/`). Load them by name with
the `Skill` tool when the situation above matches.

## Model Config

All models route through a LiteLLM proxy. Set the URL via `ANTHROPIC_BASE_URL` in
`settings.txt` (see First-time Setup below).

| Role | Model | Type |
|------|-------|------|
| Haiku (fast) | `hermes3:8b` | Local via Ollama |
| Sonnet (capable) | `deepseek-v4-flash` | Cloud via NVIDIA NIM |
| Subagent | `hermes3:8b` | Local via Ollama |

To generate or update `settings.txt`: `./generate-settings`

## Repo Structure

```
├── CLAUDE.md              # This file — project rules for Claude Code
├── README.md              # Setup instructions
├── generate-settings      # Auto-detect models from LiteLLM proxy
├── settings.txt           # Active config (gitignored)
├── settings.example.txt   # Template for manual config
├── .env                   # LiteLLM credentials (gitignored)
├── .env.example           # Template for credentials
└── .gitignore
```

## First-time Setup

```bash
cp .env.example .env           # Edit with your LiteLLM URL and key
cp settings.example.txt settings.txt
source settings.txt && claude
```

To auto-detect models from your LiteLLM proxy: `./generate-settings`
