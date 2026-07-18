# LiteLLM Architecture & Why

This document explains the design decisions behind this LiteLLM proxy setup —
not just *what* the config does, but *why* it's set up this way.

## The Problem

Claude Code (and OpenCode, OpenClaw) speaks **Anthropic's Messages API**. Most
free and local models — Ollama, vLLM, NVIDIA NIM — speak **OpenAI's Chat
Completions API** or custom formats. These are not the same protocol, so you
can't point Claude Code at a local model directly.

## The Solution: LiteLLM as a Translation Proxy

LiteLLM sits between the client and the model backends, translating requests
from Anthropic format → whatever the backend needs:

```
Claude Code / OpenCode
    │  Anthropic Messages API
    ▼
┌──────────────────────────┐
│    LiteLLM Proxy         │  ← translates formats on the fly
│    (runs on host A)      │
└──────┬───────────┬───────┘
       │           │
       ▼           ▼
   Ollama        NVIDIA NIM
  (host B)       (cloud API)
```

The client doesn't know (or care) that the backend isn't Anthropic. It sends
standard Anthropic requests; LiteLLM translates and forwards.

## Why Two Machines?

This setup separates concerns across two hosts:

| Host | Role | Software |
|------|------|----------|
| **Host A — Proxy** | Runs LiteLLM, holds config + model registry | LiteLLM (Python), PostgreSQL (optional) |
| **Host B — Inference** | Runs Ollama, serves local models | Ollama |

**Why not run LiteLLM on the same machine as Ollama?**

- **Resource isolation.** LLM inference is GPU/memory intensive. Running the
  proxy on a separate machine means a runaway model can't take down the proxy.
- **Network flexibility.** Multiple clients on the LAN can share one proxy.
  You can point any machine at `http://PROXY_HOST:4000` without installing
  Python or Ollama on it.
- **Upgrade independence.** You can update LiteLLM or Ollama independently.
- **Cloud fallback path.** The proxy can route to NVIDIA NIM (cloud) without
  the Ollama machine needing internet access or NVIDIA API keys.

## Why `store_model_in_db: true`?

Traditional LiteLLM config puts all models in a YAML file:

```yaml
model_list:
  - model_name: hermes3:8b
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://OLLAMA_HOST:11434
```

With `store_model_in_db: true`, you instead register models through the LiteLLM
API at runtime:

```bash
curl -X POST "http://PROXY_HOST:4000/model/new" \
  -H "x-api-key: YOUR_ADMIN_KEY" \
  -d '{ "model_name": "hermes3:8b", ... }'
```

**Why this matters:**

- **No file editing.** Add or remove models without SSH'ing into the proxy
  host and restarting the service.
- **Scriptable registration.** The [`register-model.sh`](../tests/register-model.sh)
  helper script wraps the API calls — one command per model type.
- **Dynamic discovery.** The [`generate-settings`](../generate-settings) script
  queries the proxy's `/model/info` endpoint to list available models and
  auto-select the best ones for Claude Code.
- **Admin UI.** LiteLLM ships with a web UI at `/ui` for browsing and managing
  models visually.

The trade-off is you need a persistent database (SQLite works for single-user;
PostgreSQL for multi-user). The YAML-only approach is simpler but requires a
restart every time you change a model.

## Why `drop_params: true`?

Claude Code sends Anthropic-specific parameters that most non-Anthropic models
don't understand:

- `thinking` — for extended/chain-of-thought responses
- Anthropic-specific content block structures

Without `drop_params`, LiteLLM forwards these to the backend model, which
rejects them:

```
litellm.llms.custom_httpx.llm_http_handler: 422 - extras must be empty
```

`drop_params: true` tells LiteLLM to **strip any parameter the target model
doesn't support**. This is essential when mixing Anthropic-native clients with
non-Anthropic backends.

## Why Two Models?

This setup uses a **speed vs. capability** trade-off:

| Role | Model | Backend | Why |
|------|-------|---------|-----|
| Haiku / Subagent | `hermes3:8b` | Ollama (local LAN) | ~2.5s response, 50 tok/s. Fast enough for interactive use, great tool support. |
| Sonnet (capable) | `deepseek-v4-flash` | NVIDIA NIM (cloud) | 1M context window, stronger reasoning, but slower (~1-18s) on the free tier. |

**Haiku** (the fast/cheap role) handles quick turnarounds — simple edits,
subagent tasks, function calls.

**Sonnet** (the capable role) handles complex reasoning, large context, and
tasks that need the full 1M context window. Falls back to the cloud only when
needed.

This mirrors Anthropic's own Haiku/Sonnet tier split, just with free models.

## The NVIDIA NIM Quirk: `chat_template_kwargs`

NVIDIA NIM's DeepSeek V4 endpoint requires an empty `chat_template_kwargs: {}`
field in every request. Without it, tool calls are unreliable — the model may
accept the request but hang indefinitely.

The fix is baked into the model registration:

```json
{
  "model_name": "deepseek-v4-flash",
  "litellm_params": {
    "model": "openai/deepseek-ai/deepseek-v4-flash",
    "api_base": "https://integrate.api.nvidia.com/v1",
    "api_key": "YOUR_NVIDIA_KEY",
    "drop_params": true,
    "chat_template_kwargs": {}
  }
}
```

The [`register-model.sh nvidia`](../tests/register-model.sh) script handles
this automatically.

## Summary: The Data Flow

```
┌─────────────┐     Anthropic Messages API      ┌──────────────┐
│ Claude Code ├─────────────────────────────────►│ LiteLLM Proxy│
│ (your laptop)│  POST /v1/messages              │  (host A)    │
│             │  API key: sk-YOUR_ADMIN_KEY      │  :4000       │
└─────────────┘                                  └──────┬───────┘
                                                         │
                                          ┌──────────────┼──────────────┐
                                          │              │              │
                                     ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
                                     │ Ollama  │   │ NVIDIA  │   │  (more  │
                                     │ (host B)│   │ NIM API │   │ models) │
                                     │ :11434  │   │ (cloud) │   │         │
                                     └─────────┘   └─────────┘   └─────────┘
```

1. Claude Code sends an Anthropic-format request to `http://PROXY_HOST:4000/v1/messages`
2. LiteLLM looks up the requested model in its database
3. LiteLLM translates the request to the backend's native format (Ollama API,
   OpenAI API, etc.)
4. The backend generates a response
5. LiteLLM translates the response back to Anthropic format
6. Claude Code receives the response — it never knew the backend wasn't Anthropic

## What You Need to Provide

To replicate this setup, you need:

| Credential | Where to get it |
|-----------|----------------|
| `LITELLM_HOST` | IP or hostname of your proxy machine |
| `OLLAMA_HOST` | IP or hostname of your Ollama machine |
| `LITELLM_API_KEY` | Generated with `openssl rand -hex 32`, set as `master_key` in `litellm.yaml` |
| `NVIDIA_API_KEY` | Sign up at [build.nvidia.com](https://build.nvidia.com/) → API keys |
| `OLLAMA_PORT` | Default: `11434` |
| `LITELLM_PORT` | Default: `4000` |

All of these go in `.env` (which is gitignored). The `.env.example` file shows
the structure with placeholder values.