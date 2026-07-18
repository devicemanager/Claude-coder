#!/bin/bash
# benchmark.sh — latency benchmarks for tool-capable models through LiteLLM.
# Usage: source ../.env && ./benchmark.sh
# Output: markdown table of model → latency metrics.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a && source "$SCRIPT_DIR/.env" && set +a
fi

API_URL="${LITELLM_URL%/}/chat/completions"
API_KEY="${LITELLM_API_KEY:-}"
TIMEOUT=60

# Models to benchmark: haiku (fastest) and sonnet (most capable) picks
# Falls back to hardcoded defaults if not set in .env
HAIKU="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-hermes3:8b}"
SONNET="${ANTHROPIC_DEFAULT_SONNET_MODEL:-deepseek-v4-flash}"
PRO="${ANTHROPIC_DEFAULT_SONNET_MODEL:-deepseek-v4-pro}"
EXTRAS=("$HAIKU" "$SONNET" "$PRO")

# Helper: time a single completion
bench_completion() {
  local model=$1 prompt=$2 max_tokens=${3:-100}
  local start end elapsed first_byte

  start=$(date +%s%N)
  RAW=$(curl -s --max-time $TIMEOUT \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(cat <<JSON
{
  "model": "$model",
  "messages": [{"role": "user", "content": "$prompt"}],
  "max_tokens": $max_tokens,
  "stream": false
}
JSON
  )" \
    "$API_URL" 2>/dev/null || echo '{"error":"timeout"}')
  end=$(date +%s%N)
  elapsed=$(echo "scale=1; ($end - $start) / 1000000000" | bc)

  CONTENT=$(echo "$RAW" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'error' in d:
        print(f'ERR: {d[\"error\"][:80]}')
    elif 'choices' in d:
        c = d['choices'][0]['message']['content']
        print(c[:100].replace(chr(10),' '))
    else:
        print('UNEXPECTED')
except Exception as e:
    print(f'PARSE: {e}')
" 2>&1)

  TOKENS=$(echo "$RAW" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('usage',{}).get('completion_tokens','?'))
except:
    print('?')
" 2>/dev/null || echo '?')

  echo "$elapsed|$TOKENS|$CONTENT"
}

# Helper: time tool call
bench_toolcall() {
  local model=$1
  local start end elapsed

  start=$(date +%s%N)
  RAW=$(curl -s --max-time $TIMEOUT \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(cat <<JSON
{
  "model": "$model",
  "messages": [{"role": "user", "content": "What is 2+3? Use a calculator tool to compute it. Call the tool with the expression as input."}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "calculator",
      "description": "Evaluate a math expression",
      "parameters": {
        "type": "object",
        "properties": {
          "expr": {"type": "string", "description": "Math expression"}
        },
        "required": ["expr"]
      }
    }
  }],
  "tool_choice": "auto",
  "max_tokens": 200
}
JSON
  )" \
    "$API_URL" 2>/dev/null || echo '{"error":"timeout"}')
  end=$(date +%s%N)
  elapsed=$(echo "scale=1; ($end - $start) / 1000000000" | bc)

  HAS_TOOL=$(echo "$RAW" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'error' in d: print('ERROR')
    else:
        msg = d.get('choices',[{}])[0].get('message',{})
        tc = msg.get('tool_calls',[])
        print('YES' if tc else 'NO')
except:
    print('PARSE_ERR')
" 2>/dev/null || echo '?')

  echo "$elapsed|$HAS_TOOL"
}

echo "# LiteLLM Model Benchmarks"
echo "Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Proxy: $LITELLM_URL"
echo
echo "## Completion Latency"
echo
echo "| Model | Task | Time (s) | Tokens | Tok/s | Response |"
echo "|-------|------|----------|--------|-------|----------|"

MODELS=("$HAIKU" "$SONNET" "$PRO")
TASKS=("Say OK in one word" "Write a haiku about coding" "Explain the TCP/IP stack in 3 sentences")

for model in "${MODELS[@]}"; do
  for task in "${TASKS[@]}"; do
    result=$(bench_completion "$model" "$task" 150)
    IFS='|' read -r elapsed tokens content <<< "$result"
    if [[ "$tokens" != "?" ]] && [[ "$tokens" != "0" ]] && [[ "$(echo "$elapsed > 0" | bc)" -eq 1 ]]; then
      toks=$(echo "scale=1; $tokens / $elapsed" | bc)
    else
      toks="?"
    fi
    echo "| $model | ${task:0:30} | ${elapsed}s | $tokens | $toks | ${content:0:40} |"
  done
done

echo
echo "## Tool Calling"
echo
echo "| Model | Time (s) | Called? |"
echo "|-------|----------|---------|"

for model in "${MODELS[@]}"; do
  result=$(bench_toolcall "$model")
  IFS='|' read -r elapsed has_tool <<< "$result"
  echo "| $model | ${elapsed}s | $has_tool |"
done

echo
echo "## Context Windows (from proxy)"
echo
echo "| Model | Max Tokens | Runs On | Role |"
echo "|-------|-----------|---------|------|"

curl -s --max-time 10 \
  -H "x-api-key: $API_KEY" \
  "$LITELLM_URL/model/info" 2>/dev/null | \
  python3 -c "
import json,sys
d = json.load(sys.stdin)
fc = [m for m in d.get('data',[])
      if m.get('model_info',{}).get('supports_function_calling')
      and m.get('model_info',{}).get('mode') == 'chat']
fc.sort(key=lambda m: int(m.get('model_info',{}).get('max_input_tokens',0) or 0))
for m in fc:
    ctx = m.get('model_info',{}).get('max_input_tokens','?')
    name = m['model_name']
    role = 'Haiku' if ctx == min(int(c.get('model_info',{}).get('max_input_tokens',0) or 0) for c in fc) else 'Sonnet'
    if name == 'deepseek-v4-pro' or name == 'deepseek-v4-flash':
        run = 'NVIDIA NIM (cloud)'
    elif name.startswith('ollama') or ':' in name:
        run = 'Ollama (local)'
    else:
        run = '?'
    print(f'| {name} | {ctx:,} | {run} | {role} |')
"
