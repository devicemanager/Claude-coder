# Claude Code — Free Model Config

Run Anthropic's coding agents (Claude Code, OpenCode) on free/local LLMs
through a [LiteLLM](https://litellm.vercel.app/) proxy, with disciplined
engineering workflows [loaded as skills](#skills).

## Quick Start

All tools share one flow: configure `.env` → detect models → source env →
launch.

```bash
cp .env.example .env          # edit with your LiteLLM URL + key
./generate-settings env > settings.txt   # auto-detect best models

source settings.txt && claude            # Claude Code
source settings.txt && opencode          # OpenCode
```

## Per-Tool Setup

### Claude Code

```bash
# Install skills (see Skills section below first)
cp .env.example .env
./generate-settings env > settings.txt
source settings.txt && claude
```

Uses `ANTHROPIC_*` env vars from `settings.txt`. The `CLAUDE.md` file bakes in
workflow rules — skills load automatically by situation.

### OpenCode

Same env vars, different skills path:

```bash
cp .env.example .env
./generate-settings env > settings.txt
source settings.txt && opencode
```

Skills go in `~/.config/opencode/skills/` (see Skills section).

### OpenClaw

Uses `openclaw.json` instead of env vars. Add a LiteLLM provider
and (optionally) an NVIDIA NIM provider for direct cloud access:

```json
{
  "providers": {
    "litellm": {
      "baseUrl": "http://LITELLM_HOST:4000",
      "api": "openai-completions",
      "apiKey": "sk-...",
      "models": [
        {"id": "hermes3:8b", "compat": {"supportsTools": true}},
        {"id": "deepseek-v4-flash", "compat": {"supportsTools": true}}
      ]
    },
    "nvidia-nim": {
      "baseUrl": "https://integrate.api.nvidia.com/v1",
      "api": "openai-completions",
      "apiKey": "nvapi-...",
      "auth": "api-key",
      "models": [
        {"id": "deepseek-ai/deepseek-v4-flash", "compat": {"supportsTools": true}}
      ]
    }
  }
}
```

### Hermes3:8b (local via Ollama)

```bash
ollama pull hermes3:8b
```

Then register it in your LiteLLM config (`litellm.yaml`):

```yaml
model_list:
  - model_name: hermes3:8b
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://OLLAMA_HOST:11434
```

## Model Recommendations

| Role | Model | Runs On |
|------|-------|---------|
| Haiku (fast) | `hermes3:8b` | Ollama (local) |
| Sonnet (capable) | `deepseek-v4-flash` | NVIDIA NIM (free cloud) |
| Subagent | `hermes3:8b` | Ollama (local) |

Auto-detect yours: `./generate-settings models`

## Skills

Skills teach the agent disciplined workflows. This repo references:

- **[9arm-skills](https://github.com/thananon/9arm-skills)** by
  [@thananon](https://github.com/thananon) — debug-mantra, scrutinize,
  post-mortem, management-talk
- **[superpowers](https://github.com/anomalyco/superpowers)** by
  [@anomalyco](https://github.com/anomalyco) — brainstorming, writing-plans,
  test-driven-development, verification-before-completion

Install:

```bash
# 9arm-skills
git clone https://github.com/thananon/9arm-skills.git /tmp/9arm-skills
for dir in /tmp/9arm-skills/skills/engineering/* /tmp/9arm-skills/skills/productivity/*; do
  ln -sfn "$dir" ~/.claude/skills/"$(basename "$dir")"
  ln -sfn "$dir" ~/.config/opencode/skills/"$(basename "$dir")" 2>/dev/null || true
done

# superpowers
git clone https://github.com/anomalyco/superpowers.git /tmp/superpowers
for dir in /tmp/superpowers/skills/*/; do
  ln -sfn "$dir" ~/.claude/skills/"$(basename "$dir")"
  ln -sfn "$dir" ~/.config/opencode/skills/"$(basename "$dir")" 2>/dev/null || true
done
```

## Scripts

```
./generate-settings           # print shell env vars (default)
./generate-settings env       # same as above
./generate-settings models    # list available models
./generate-settings json      # JSON output
```

Override model selection:

```bash
HAIKU_MODEL="llama3.1:8b" SONNET_MODEL="qwen3.6:latest" ./generate-settings
```

## Repo Structure

```
├── CLAUDE.md              # Engineering rules for Claude Code
├── README.md
├── generate-settings      # Auto-detect models from LiteLLM proxy
├── settings.txt           # Active config (gitignored, created by setup)
├── settings.example.txt   # Manual config template
├── .env                   # LiteLLM credentials (gitignored)
├── .env.example           # Template
└── .gitignore
```

## Credits

LiteLLM proxy — [BerriAI/litellm](https://github.com/BerriAI/litellm)
9arm-skills — [thananon/9arm-skills](https://github.com/thananon/9arm-skills)
Superpowers — [anomalyco/superpowers](https://github.com/anomalyco/superpowers)
Ollama — [ollama/ollama](https://github.com/ollama/ollama)
NVIDIA NIM — [build.nvidia.com](https://build.nvidia.com/explore/discover)
