# Claude Code — Free Model Config

Run Anthropic's coding agents (Claude Code, OpenCode) on free/local LLMs
through a [LiteLLM](https://litellm.vercel.app/) proxy, with disciplined
engineering workflows [loaded as skills](#skills).

## Quick Start

All tools share one flow: configure `.env` → detect models → source env →
launch.

```bash
cp .env.example .env                # edit with your LiteLLM URL + key
./generate-settings env >> .env     # auto-detect best models

set -a; source .env; set +a         # load + export env vars
claude                              # Claude Code
```

> **Note:** `.env` files use `VAR=val` without `export` — `source .env` alone won't pass vars to the `claude` subprocess. `set -a` enables auto-export. Add a shell function to `~/.zshrc` for convenience:
>
> ```bash
> claude() { set -a; source /path/to/.env; set +a; command claude "$@"; }
> ```

## Per-Tool Setup

### Claude Code

```bash
# Install skills (see Skills section below first)
cp .env.example .env
./generate-settings env >> .env
set -a; source .env; set +a; claude
```

Add a shell function to `~/.zshrc` to skip the `set -a` dance every time:

```bash
claude() { set -a; source /path/to/claude-coder/.env; set +a; command claude "$@"; }
```

The `CLAUDE.md` file bakes in workflow rules — skills load automatically by
situation.

### OpenCode

Same env vars, different skills path:

```bash
cp .env.example .env
./generate-settings env >> .env
set -a; source .env; set +a; opencode
```

Skills go in `~/.config/opencode/skills/` (see Skills section).

### OpenClaw

Uses `openclaw.json` instead of env vars. Add a LiteLLM provider
and (optionally) an NVIDIA NIM provider for direct cloud access:

```json
{
  "providers": {
    "litellm": {
      "baseUrl": "http://LITELLM_HOST:LITELLM_PORT",
      "api": "openai-completions",
      "apiKey": "LITELLM_API_KEY",
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
      api_base: http://OLLAMA_HOST:OLLAMA_PORT
```

## Model Recommendations

| Role | Model | Runs On | Latency |
|------|-------|---------|---------|
| Haiku (fast) | `hermes3:8b` | Ollama (local) | ~2.5 s |
| Sonnet (capable) | `deepseek-v4-flash` | NVIDIA NIM (cloud) | ~1-18 s |
| Subagent | `hermes3:8b` | Ollama (local) | ~2.5 s |

> **Tip:** `chat_template_kwargs: {}` + `drop_params: true` are required for
> NVIDIA NIM models — `./tests/register-model.sh nvidia` handles this
> automatically. See [docs/litellm-setup.md](docs/litellm-setup.md).

Auto-detect yours: `./generate-settings models`

## Benchmarks

Latency and throughput measured against a real LiteLLM proxy (Ollama local +
NVIDIA NIM cloud). Run `./tests/benchmark.sh` in your own setup to compare.

Results below are **after** applying `chat_template_kwargs: {}` and
`drop_params: true` to NVIDIA NIM model registrations (see
`./tests/register-model.sh nvidia`). Without these flags, requests hang or
time out.

### Completion Latency

| Model | Task | Time (s) | Tokens | Tok/s |
|-------|------|----------|--------|-------|
| hermes3:8b | OK | 2.5 | 3 | — |
| hermes3:8b | Haiku | 2.9 | 150 | 52 |
| hermes3:8b | Explain | 2.6 | 130 | 50 |
| hermes3:8b | Tool call | 1.4 | — | — |
| deepseek-v4-flash | OK | 2.3 | 2 | — |
| deepseek-v4-flash | Haiku | 1.0 | 19 | 19 |
| deepseek-v4-flash | Explain | 18.4 | 86 | 5 |
| deepseek-v4-flash | Tool call | 4.5 | — | — |
| deepseek-v4-pro | Any | >60 | — | — |

### Summary

| Model | Avg Latency | Avg Throughput | Tool Support | Runs On |
|-------|------------|---------------|-------------|---------|
| **hermes3:8b** | **~2.5 s** | **~50 tok/s** | **Yes** | Ollama (local) |
| **deepseek-v4-flash** | **~1-18 s** | **~5-19 tok/s** | **Yes** | NVIDIA NIM (cloud) |
| deepseek-v4-pro | >60 s | — | — | NVIDIA NIM (cloud) |

**Bottom line:** `hermes3:8b` is the primary model — fast, reliable, great
tool support. `deepseek-v4-flash` works as a cloud fallback with 1M context
but latency varies (1-18 s). `deepseek-v4-pro` is unusable through the free
NVIDIA NIM tier.

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
./tests/check-litellm.sh      # proxy health check
./tests/benchmark.sh          # model latency (set -a; source .env; set +a first)
./tests/register-model.sh     # register models via LiteLLM API
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
├── tests/
│   ├── check-litellm.sh   # Proxy health check
│   ├── benchmark.sh       # Model latency benchmarks
│   └── register-model.sh  # Register models via API
├── .env                   # Credentials + model config (gitignored)
├── .env.example           # Template
└── .gitignore
```

## Credits

LiteLLM proxy — [BerriAI/litellm](https://github.com/BerriAI/litellm)
9arm-skills — [thananon/9arm-skills](https://github.com/thananon/9arm-skills)
Superpowers — [anomalyco/superpowers](https://github.com/anomalyco/superpowers)
Ollama — [ollama/ollama](https://github.com/ollama/ollama)
NVIDIA NIM — [build.nvidia.com](https://build.nvidia.com/explore/discover)
