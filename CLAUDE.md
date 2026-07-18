# Claude Code — Free Model Config

Configure Claude Code to run on free/local LLMs through a LiteLLM proxy, with
disciplined engineering workflows built in.

## Engineering Process

These rules apply to every session in this repo. Skills marked with `(needs install)` are
referenced optionally but live in the [superpowers](https://github.com/anomalyco/superpowers)
repo which requires GitHub authentication.

**Available skills (9arm-skills, no auth required):**

| Skill | When to use |
|-------|-------------|
| `debug-mantra` | Bug report / crash / test failure |
| `scrutinize` | PR review, non-trivial diffs |
| `post-mortem` | After fixing a bug |
| `management-talk` | Status / leadership updates |

**Installation:**

```bash
./install-skills.sh
```

**While working:**

- Make focused, single-purpose commits
- Follow existing code conventions (read surrounding files first)
- Don't add comments unless asked

## Skills Reference

Skills are installed into your skills directory (`~/.claude/skills/` or
`~/.config/opencode/skills/`). Load them by name with the `Skill` tool when
the situation above matches. Run `./install-skills.sh` to install them.

## Model Config

Models route through the LiteLLM proxy configured in `.env`. Run
`./generate-settings env >> .env` to append model settings. Use
`set -a; source .env; set +a` to load and export vars before launching.

## Repo Structure

```
├── CLAUDE.md              # This file
├── README.md              # Setup instructions
├── generate-settings      # Auto-detect models
├── install-skills.sh      # Install engineering workflow skills
├── docs/
│   └── litellm-setup.md   # Full proxy setup + troubleshooting
├── tests/
│   ├── check-litellm.sh   # Proxy health check
│   ├── benchmark.sh       # Model latency benchmarks
│   └── register-model.sh  # Register models via LiteLLM API
├── .env                   # Credentials + model config (gitignored)
├── .env.example           # Template
└── .gitignore
```

## First-time Setup

```bash
cp .env.example .env
./generate-settings env >> .env
set -a; source .env; set +a; claude
```

> **Important:** `.env` variables aren't exported automatically. Always use
> `set -a` before `source .env` so the `claude` subprocess sees them. Add a
> shell function to `~/.zshrc` so this works from any directory.
