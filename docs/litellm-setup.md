# LiteLLM Setup Guide

## Why a proxy?

Claude Code speaks **Anthropic's Messages API**. Local models (Ollama, vLLM)
and cloud providers (NVIDIA NIM, OpenAI) speak **OpenAI's Chat Completions
API** or custom formats. These are not the same protocol.

[LiteLLM](https://litellm.vercel.app/) sits between them:

```
Claude Code / OpenCode
    │  Anthropic Messages API
    ▼
┌─────────────────────┐
│   LiteLLM Proxy     │  ← translates formats
│   (proxy host)
└─────────┬───────────┘
    │              │
    ▼              ▼
Ollama        NVIDIA NIM
(local)       (cloud)
```

Without LiteLLM, you would need a model that natively speaks the Anthropic
protocol — very few open models do. LiteLLM handles the translation so Claude
Code can talk to any model provider.

## Architecture

This setup runs LiteLLM on a server and connects the proxy to:

| Backend | Host | Models |
|---------|------|--------|
| Ollama | `$OLLAMA_HOST` | hermes3:8b, llama3.1:8b, qwen3.6, etc. |
| NVIDIA NIM | `integrate.api.nvidia.com` | deepseek-v4-flash (cloud) |

Clients (Claude Code, OpenCode, OpenClaw) point their `ANTHROPIC_BASE_URL` at
the LiteLLM proxy and never talk to Ollama or NVIDIA directly.

## Installation

### 1. Install LiteLLM on a server

LiteLLM runs anywhere with Python. This guide uses `uv` (fast Python package
manager), but `pip` works too.

```bash
# Install uv (one-time)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create a project directory
mkdir -p /opt/litellm
cd /opt/litellm

# Create virtualenv and install litellm
uv venv
uv pip install litellm[proxy]

# Verify
uv run litellm --help
```

**Alternative with pip:**
```bash
python3 -m venv /opt/litellm/.venv
/opt/litellm/.venv/bin/pip install litellm[proxy]
```

### 2. Create the config file

Create `/opt/litellm/litellm.yaml`:

```yaml
general_settings:
  master_key: "sk-your-random-admin-key"   # protects the proxy API
  store_model_in_db: true                   # manage models via API/UI

litellm_settings:
  drop_params: true                         # ! important — see below
```

- `master_key`: Acts as the API key for all client requests. Generate one:
  `openssl rand -hex 32`.
- `store_model_in_db: true`: Lets you add/remove models through the LiteLLM
  API or Admin UI instead of editing YAML.
- `drop_params: true`: Claude Code sends parameters (like `thinking`) that
  smaller models don't support. Without this, the proxy rejects the request.

**Optional — PostgreSQL for persistence:**
```yaml
general_settings:
  database_url: "postgresql://user:pass@localhost/litellm_db"
  master_key: "sk-your-admin-key"
  store_model_in_db: true

litellm_settings:
  drop_params: true
```

### 3. Start the proxy

```bash
cd /opt/litellm
uv run litellm --config /opt/litellm/litellm.yaml --port "$LITELLM_PORT"
```

The proxy listens on the configured host and port. Test it:

```bash
curl "http://localhost:$LITELLM_PORT/health"
```

### 4. Register models

With `store_model_in_db: true`, models are registered through the API:

```bash
curl -X POST "http://localhost:$LITELLM_PORT/model/new" \
  -H "x-api-key: sk-your-admin-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "hermes3:8b",
    "litellm_params": {
      "model": "ollama/hermes3:8b",
      "api_base": "http://$OLLAMA_HOST:$OLLAMA_PORT"
    }
  }'
```

**Ollama models** use `ollama/<model-name>` with `api_base` pointing to the
Ollama host.

**NVIDIA NIM models** use `openai/<model-path>` with the NVIDIA API key:

```bash
curl -X POST "http://localhost:$LITELLM_PORT/model/new" \
  -H "x-api-key: sk-your-admin-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "deepseek-v4-flash",
    "litellm_params": {
      "model": "openai/deepseek-ai/deepseek-v4-flash",
      "api_base": "https://integrate.api.nvidia.com/v1",
      "api_key": "nvapi-your-nvidia-key"
    }
  }'
```

**Verify registered models:**

```bash
curl -s -H "x-api-key: sk-your-admin-key" \
  "http://localhost:$LITELLM_PORT/model/info" | python3 -m json.tool
```

### 5. Run LiteLLM as a service

On Linux (systemd):

```bash
cat > /etc/systemd/system/litellm.service << 'EOF'
[Unit]
Description=LiteLLM Proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/litellm
ExecStart=/usr/local/bin/uv run litellm --config /opt/litellm/litellm.yaml --port "$LITELLM_PORT"
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now litellm
```

## Client Configuration

### Claude Code

```bash
export ANTHROPIC_BASE_URL="http://$LITELLM_HOST:$LITELLM_PORT"
export ANTHROPIC_AUTH_TOKEN="sk-your-admin-key"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="hermes3:8b"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash"
export CLAUDE_CODE_SUBAGENT_MODEL="hermes3:8b"
export ANTHROPIC_MODEL="sonnet"
claude
```

### OpenCode (same env vars)

```bash
source .env
opencode
```

### OpenClaw

Add a `litellm` provider in `openclaw.json`:

```json
{
  "providers": {
    "litellm": {
      "baseUrl": "http://$LITELLM_HOST:$LITELLM_PORT",
      "api": "openai-completions",
      "apiKey": "sk-your-admin-key",
      "models": [
        {"id": "hermes3:8b", "compat": {"supportsTools": true}},
        {"id": "deepseek-v4-flash", "compat": {"supportsTools": true}}
      ]
    }
  }
}
```

## Problems Encountered

### `drop_params: true`

When Claude Code sends a request, it includes Anthropic-specific parameters
like `thinking` (for extended thinking models). Most local models don't
recognize these and return an error:

```
litellm.llms.custom_httpx.llm_http_handler: 
  litellm.llms.custom_httpx.llm_http_handler: 422 
  - extras must be empty
```

The fix is `drop_params: true` in `litellm_settings` — LiteLLM strips any
parameters the target model doesn't support.

### `chat_template_kwargs` (NVIDIA NIM)

DeepSeek V4 on NVIDIA NIM requires a `chat_template_kwargs` field in the
request body. Without it, the model accepts the request but never responds
(the connection hangs). The fix is registering the model with this parameter:

```bash
curl -X POST "http://localhost:$LITELLM_PORT/model/new" \
  -H "x-api-key: sk-your-admin-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "deepseek-v4-flash",
    "litellm_params": {
      "model": "openai/deepseek-ai/deepseek-v4-flash",
      "api_base": "https://integrate.api.nvidia.com/v1",
      "api_key": "nvapi-your-key",
      "chat_template_kwargs": {}
    }
  }'
```

### Function Calling Support

Not all models support tool/function calling. Check before using a model as a
Claude Code agent:

```bash
curl -s -H "x-api-key: sk-your-admin-key" \
  "http://localhost:$LITELLM_PORT/model/info" | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data.get('data', []):
    info = m.get('model_info', {})
    fc = 'fc' if info.get('supports_function_calling') else '  '
    print(f'{m[\"model_name\"]:30s} {fc}')
"
```

Models without `fc` cannot use tools and will fail in Claude Code.

### ANTHROPIC_BASE_URL trailing slash

The URL must NOT have a trailing slash. `http://host:$LITELLM_PORT/chat/completions` is
correct; `http://host:$LITELLM_PORT//chat/completions` returns 404. If your config adds
a trailing slash, remove it.

### API Key Mismatch

LiteLLM has two key concepts:
- `master_key`: The single admin key set in `litellm.yaml`. All clients use
  this as their `ANTHROPIC_AUTH_TOKEN`.
- Virtual keys: Optional scoped keys generated through the LiteLLM Admin UI.
  Not needed for single-user setups.

## Testing Your Setup

Run the check-litellm script from this repo:

```bash
./tests/check-litellm.sh http://your-litellm-host:$LITELLM_PORT sk-your-admin-key
```

It tests:
1. Proxy health (`/health`)
2. Model list (`/model/info`)
3. Function-calling capable models
4. A real chat completion request

## Performance

| Model | Avg Response Time | Location |
|-------|-----------------|----------|
| hermes3:8b (via Ollama) | ~3.5s | Local network |
| deepseek-v4-flash (NVIDIA NIM) | ~70s | Cloud |

Local models are ~20x faster for simple queries. The cloud fallback is useful
for complex tasks where a larger model matters more than speed.
