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

Skills are installed into your skills directory (`~/.claude/skills/` or
`~/.config/opencode/skills/`). Load them by name with the `Skill` tool when
the situation above matches. See README for install instructions.

## Model Config

Models route through the LiteLLM proxy configured in `.env`. Run
`./generate-settings env >> .env` to append model settings, then
`source .env` before launching the agent.

## Repo Structure

```
├── CLAUDE.md              # This file
├── README.md              # Setup instructions
├── generate-settings      # Auto-detect models
├── .env                   # Credentials + model config (gitignored)
├── .env.example           # Template
└── .gitignore
```

## First-time Setup

```bash
cp .env.example .env
./generate-settings env >> .env
source .env && claude
```
