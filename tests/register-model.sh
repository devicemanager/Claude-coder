#!/bin/bash
# register-model.sh — register or update a model in LiteLLM.
# Usage:
#   source ../.env && ./register-model.sh ollama hermes3:8b http://ollama-host:11434
#   source ../.env && ./register-model.sh nvidia deepseek-v4-flash nvapi-your-key
#   source ../.env && ./register-model.sh openai gpt-4o sk-your-openai-key
#
# Or from a JSON file:
#   ./register-model.sh path/to/model.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a && source "$SCRIPT_DIR/.env" && set +a
fi

API_URL="${LITELLM_URL%/}"
API_KEY="${LITELLM_API_KEY:-}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") <type> <name> [params...]
       $(basename "$0") model.json

Types:
  ollama <name> <api_base>
    Register an Ollama model (e.g. hermes3:8b, llama3.1:8b).
    Uses "ollama/<name>" as the upstream model.

  nvidia <name> <api_key>
    Register an NVIDIA NIM model (e.g. deepseek-v4-flash).
    Adds chat_template_kwargs{} and drop_params=true automatically.

  openai <name> <api_key> [api_base]
    Register any OpenAI-compatible model.
    Default api_base: https://api.openai.com/v1

JSON file format:
  {
    "model_name": "my-model",
    "litellm_params": {
      "model": "openai/...",
      "api_key": "...",
      "api_base": "..."
    },
    "model_info": {
      "mode": "chat",
      "max_input_tokens": 32768,
      "supports_function_calling": true
    }
  }

Environment: LITELLM_URL, LITELLM_API_KEY (from .env)
USAGE
  exit 1
}

call_api() {
  local payload="$1"
  local name
  name=$(echo "$payload" | python3 -c "import json,sys;print(json.load(sys.stdin)['model_name'])" 2>/dev/null || echo "unknown")

  echo "Registering '$name'..."
  RESPONSE=$(curl -s --max-time 15 \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "$API_URL/model/new")

  if echo "$RESPONSE" | python3 -c "import json,sys;d=json.load(sys.stdin);exit(0 if 'model_id' in d else 1)" 2>/dev/null; then
    echo "  OK — model ID: $(echo "$RESPONSE" | python3 -c "import json,sys;print(json.load(sys.stdin)['model_id'][:12])")"
  else
    echo "  ERROR: $RESPONSE" >&2
    return 1
  fi
}

# --- JSON file mode ---
if [[ $# -eq 1 ]] && [[ -f "$1" ]]; then
  PAYLOAD=$(cat "$1")
  call_api "$PAYLOAD"
  exit $?
fi

# --- Interactive mode ---
if [[ $# -lt 1 ]]; then
  usage
fi

TYPE="$1"
shift

case "$TYPE" in
  ollama)
    [[ $# -lt 2 ]] && usage
    NAME="$1"
    OLLAMA_HOST="$2"
    PAYLOAD=$(cat <<JSON
{
  "model_name": "$NAME",
  "litellm_params": {
    "model": "ollama/$NAME",
    "api_base": "$OLLAMA_HOST"
  },
  "model_info": {
    "mode": "chat",
    "max_input_tokens": 32768,
    "supports_function_calling": true
  }
}
JSON
)
    call_api "$PAYLOAD"
    ;;

  nvidia)
    [[ $# -lt 2 ]] && usage
    NAME="$1"
    NVIDIA_KEY="$2"
    PAYLOAD=$(cat <<JSON
{
  "model_name": "$NAME",
  "litellm_params": {
    "model": "openai/deepseek-ai/$NAME",
    "api_base": "https://integrate.api.nvidia.com/v1",
    "api_key": "$NVIDIA_KEY",
    "drop_params": true,
    "chat_template_kwargs": {},
    "input_cost_per_token": 0.0,
    "output_cost_per_token": 0.0
  },
  "model_info": {
    "mode": "chat",
    "max_input_tokens": 1000000,
    "supports_function_calling": true
  }
}
JSON
)
    call_api "$PAYLOAD"
    ;;

  openai)
    [[ $# -lt 2 ]] && usage
    NAME="$1"
    OPENAI_KEY="$2"
    BASE="${3:-https://api.openai.com/v1}"
    PAYLOAD=$(cat <<JSON
{
  "model_name": "$NAME",
  "litellm_params": {
    "model": "openai/$NAME",
    "api_base": "$BASE",
    "api_key": "$OPENAI_KEY",
    "drop_params": true
  },
  "model_info": {
    "mode": "chat",
    "supports_function_calling": true
  }
}
JSON
)
    call_api "$PAYLOAD"
    ;;

  *)
    usage
    ;;
esac
