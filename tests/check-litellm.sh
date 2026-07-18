#!/bin/bash
# check-litellm.sh — verify a LiteLLM proxy is working correctly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a && source "$SCRIPT_DIR/.env" && set +a
fi

LITELLM_URL="${1:-${LITELLM_URL:-http://localhost:4000}}"
API_KEY="${2:-${LITELLM_API_KEY:-}}"

PASS=0 FAIL=0
LITELLM_URL="${LITELLM_URL%/}"
TIMEOUT=30

pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "LiteLLM Check — $LITELLM_URL"
echo

# Test 1: Proxy reachable
echo "--- Test 1: Proxy reachable ---"
REACHABLE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -H "x-api-key: $API_KEY" "$LITELLM_URL/model/info" 2>/dev/null || echo "000")
if [[ "$REACHABLE" == "200" || "$REACHABLE" == "401" ]]; then
  pass "Proxy reachable: HTTP $REACHABLE"
else
  fail "Proxy not reachable: HTTP $REACHABLE"
fi

# Test 2: Model list
echo "--- Test 2: Model list ---"
MODEL_JSON=$(curl -s --max-time 10 \
  -H "x-api-key: $API_KEY" "$LITELLM_URL/model/info" 2>/dev/null || echo "{}")
MODEL_COUNT=$(echo "$MODEL_JSON" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(len(d.get('data', [])))
except: print(0)
" 2>/dev/null || echo "0")
if [[ "$MODEL_COUNT" -gt 0 ]]; then
  pass "Models registered: $MODEL_COUNT"
else
  fail "No models found"
fi

# Test 3: Tool-capable models
echo "--- Test 3: Tool-capable models ---"
FC_DATA=$(echo "$MODEL_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
fc = [m for m in d.get('data', [])
      if m.get('model_info', {}).get('supports_function_calling')
      and m.get('model_info', {}).get('mode') == 'chat']
for m in fc:
    ctx = int(m.get('model_info', {}).get('max_input_tokens', 0) or 0)
    print(f'{m[\"model_name\"]} ctx={ctx}')
print(f'COUNT={len(fc)}')
" 2>/dev/null || echo "COUNT=0")

FC_COUNT=$(echo "$FC_DATA" | grep "COUNT=" | sed 's/COUNT=//')
FC_NAMES=$(echo "$FC_DATA" | grep -v "COUNT=")

if [[ "$FC_COUNT" -gt 0 ]]; then
  pass "Tool-capable: $FC_COUNT models"
  echo "$FC_NAMES"
else
  fail "No tool-capable models"
fi

# Test 4: Chat completion (fastest tool-capable model)
echo "--- Test 4: Chat completion ---"
HAIKU=$(echo "$MODEL_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
fc = [m for m in d.get('data', [])
      if m.get('model_info', {}).get('supports_function_calling')
      and m.get('model_info', {}).get('mode') == 'chat']
if fc:
    best = min(fc, key=lambda m: int(m.get('model_info',{}).get('max_input_tokens',0) or 0))
    print(best['model_name'])
" 2>/dev/null || echo "")

if [[ -n "$HAIKU" ]]; then
  RAW=$(curl -s --max-time $TIMEOUT \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$HAIKU\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK in one word\"}],\"max_tokens\":10}" \
    "$LITELLM_URL/chat/completions" 2>/dev/null || echo '{"error":"curl failed"}')

  # Try to extract content from the response
  CONTENT=$(echo "$RAW" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'error' in d:
        print(f'ERROR: {d[\"error\"]}')
    elif 'choices' in d:
        print(d['choices'][0]['message']['content'][:50])
    else:
        print('UNEXPECTED')
except Exception as e:
    print(f'PARSE_ERR: {e}')
" 2>&1)
  
  if echo "$CONTENT" | grep -q "^ERROR\|^UNEXPECTED\|^PARSE_ERR"; then
    fail "Chat completion: $CONTENT"
  else
    pass "Chat completion with $HAIKU: \"$CONTENT\""
  fi
else
  fail "No model available"
fi

echo
echo "--- Results: $PASS passed, $FAIL failed ---"
exit $FAIL
