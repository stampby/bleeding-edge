#!/usr/bin/env bash
# burn-remote.sh — MLX Engine ROCm full burn via API
# Restarts server per model to avoid hipBLASLt aperture violations.
set -euo pipefail

API="http://localhost:8091"
RUNS=5
WARMUP=2
MAX_TOKENS=256
RESULTS_DIR="results"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
JSON_OUT="${RESULTS_DIR}/burn-mlx-${TIMESTAMP}.json"
CSV_OUT="${RESULTS_DIR}/burn-mlx-${TIMESTAMP}.csv"
PROMPT="Write a detailed technical analysis of distributed systems architecture, covering consensus algorithms, fault tolerance patterns, and scalability strategies. Include specific examples from real-world implementations."

MLX_BIN="${HOME}/mlx-engine-bin/server"
export LD_LIBRARY_PATH="${HOME}/mlx-engine-bin:/opt/rocm/lib"

MODELS=(
  # already burned:
  # "mlx-community/Qwen3-0.6B-4bit"      # 145.6 tok/s
  # "mlx-community/Qwen3-1.7B-4bit"      # 64.5 tok/s
  # "mlx-community/Qwen3-4B-4bit"        # 44.7 tok/s
  # "mlx-community/Qwen3-8B-4bit"        # 20.9 tok/s
  # "mlx-community/Phi-4-mini-instruct-4bit"  # 37.1 tok/s
  # "mlx-community/Qwen3-Coder-Next-4bit"    # warmup timeout (MoE 47GB)
  "mlx-community/Llama-3.2-1B-Instruct-4bit"
  "mlx-community/Llama-3.2-3B-Instruct-4bit"
  "mlx-community/gemma-3-4b-it-4bit"
  "mlx-community/Qwen2.5-72B-Instruct-4bit"
  "mlx-community/Qwen3.5-122B-A10B-4bit"
  "mlx-community/Falcon-E-3B-Instruct-1.58bit"
  "mlx-community/bitnet-b1.58-2B-4T"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${CYAN}[burn]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

kill_server() {
  pkill -9 -f "mlx-engine-bin/server" 2>/dev/null || true
  sleep 3
}

start_server() {
  kill_server
  nohup "$MLX_BIN" --port 8091 --host 0.0.0.0 > /tmp/mlx-burn-server.log 2>&1 &
  disown 2>/dev/null
  local retries=0
  while ! curl -s --max-time 2 "${API}/health" 2>/dev/null | grep -q "ok"; do
    retries=$((retries + 1))
    if [ "$retries" -gt 15 ]; then
      err "Server failed to start after 30s"
      return 1
    fi
    sleep 2
  done
  ok "Server ready"
}

mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  MLX Engine ROCm — Full Burn                            ║${NC}"
echo -e "${BOLD}║  ${#MODELS[@]} models · ${RUNS} runs · ${WARMUP} warmup · ${MAX_TOKENS} tokens       ║${NC}"
echo -e "${BOLD}║  API: ${API}  (restart per model)          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

RESULTS_JSON=()
PASS=0
FAIL=0

for model in "${MODELS[@]}"; do
  model_short=$(echo "$model" | sed 's|mlx-community/||')
  echo ""
  echo "═══════════════════════════════════════════════════════"
  log "Model: ${model_short}"

  # Fresh server for each model
  log "  Starting fresh server..."
  if ! start_server; then
    err "  FAILED: ${model_short} (server start)"
    RESULTS_JSON+=("{\"model\": \"${model_short}\", \"pass\": false, \"error\": \"server start failed\"}")
    FAIL=$((FAIL + 1))
    continue
  fi

  # Load test
  log "  Loading..."
  load_resp=$(curl -s --max-time 120 "${API}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${model}\", \"messages\": [{\"role\": \"user\", \"content\": \"Say hello.\"}], \"max_tokens\": 10, \"temperature\": 0}" 2>&1) || true

  if ! echo "$load_resp" | python3 -c "import sys,json; json.loads(sys.stdin.read(), strict=False)['choices']" 2>/dev/null; then
    err "  FAILED: ${model_short}"
    echo "  $load_resp" | head -2
    RESULTS_JSON+=("{\"model\": \"${model_short}\", \"pass\": false, \"error\": \"load failed\"}")
    FAIL=$((FAIL + 1))
    kill_server
    continue
  fi
  ok "  Loaded"

  # Warmup (non-fatal — if warmup hangs, skip model)
  warmup_ok=true
  for w in $(seq 1 "$WARMUP"); do
    log "  warmup ${w}/${WARMUP}..."
    if ! curl -s --max-time 120 "${API}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"${model}\", \"messages\": [{\"role\": \"user\", \"content\": \"${PROMPT}\"}], \"max_tokens\": ${MAX_TOKENS}, \"temperature\": 0}" > /dev/null 2>&1; then
      warn "  warmup failed/timed out"
      warmup_ok=false
      break
    fi
  done

  if [ "$warmup_ok" = false ]; then
    err "  FAILED: ${model_short} (warmup timeout)"
    RESULTS_JSON+=("{\"model\": \"${model_short}\", \"pass\": false, \"error\": \"warmup timeout\"}")
    FAIL=$((FAIL + 1))
    kill_server
    continue
  fi

  # Benchmark runs
  tps_list=""
  run_failed=false
  for r in $(seq 1 "$RUNS"); do
    start_ns=$(date +%s%N)
    resp=$(curl -s --max-time 120 "${API}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"${model}\", \"messages\": [{\"role\": \"user\", \"content\": \"${PROMPT}\"}], \"max_tokens\": ${MAX_TOKENS}, \"temperature\": 0}" 2>&1) || true
    end_ns=$(date +%s%N)
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

    tps=$(echo "$resp" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read(), strict=False)
ct = d.get('usage', {}).get('completion_tokens', 0)
if ct > 0:
    print(f'{ct / (${elapsed_ms} / 1000.0):.1f}')
else:
    print('0')
" 2>/dev/null || echo "0")

    ct=$(echo "$resp" | python3 -c "import sys,json; print(json.loads(sys.stdin.read(),strict=False).get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")

    if [ "$tps" = "0" ] || [ "$ct" = "0" ]; then
      warn "  run ${r}/${RUNS}: FAILED (server may have crashed)"
      run_failed=true
      break
    fi

    tps_list="${tps_list} ${tps}"
    log "  run ${r}/${RUNS}: ${tps} tok/s (${ct} tokens, ${elapsed_ms}ms)"
  done

  if [ "$run_failed" = true ]; then
    err "  FAILED: ${model_short} (inference crash)"
    RESULTS_JSON+=("{\"model\": \"${model_short}\", \"pass\": false, \"error\": \"inference crash\"}")
    FAIL=$((FAIL + 1))
    kill_server
    continue
  fi

  # Stats
  stats=$(python3 -c "
import statistics
vals = [float(x) for x in '${tps_list}'.split() if float(x) > 0]
if vals:
    m = statistics.mean(vals)
    s = statistics.stdev(vals) if len(vals) > 1 else 0.0
    print(f'{m:.1f} {s:.1f} {min(vals):.1f} {max(vals):.1f}')
else:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")

  mean=$(echo "$stats" | awk '{print $1}')
  stdev=$(echo "$stats" | awk '{print $2}')
  mn=$(echo "$stats" | awk '{print $3}')
  mx=$(echo "$stats" | awk '{print $4}')

  ok "  ${model_short}: ${mean} ±${stdev} tok/s (min=${mn} max=${mx})"
  RESULTS_JSON+=("{\"model\": \"${model_short}\", \"pass\": true, \"mean_tps\": ${mean}, \"stddev\": ${stdev}, \"min\": ${mn}, \"max\": ${mx}, \"runs\": ${RUNS}}")
  PASS=$((PASS + 1))

  # Kill server to get clean GPU state for next model
  log "  Stopping server..."
  kill_server
done

# Final cleanup
kill_server

# Write JSON
cat > "$JSON_OUT" << JSONEOF
{
  "results": [
$(printf '    %s,\n' "${RESULTS_JSON[@]}" | sed '$ s/,$//')
  ],
  "engine": "lemon-mlx-engine b1004-tech-preview",
  "rocm": "7.12.0",
  "gpu": "gfx1151",
  "hardware": "AMD Ryzen AI MAX+ PRO 395, 128GB unified",
  "kernel": "7.0.0-1-mainline",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%S)",
  "runs": ${RUNS},
  "warmup": ${WARMUP},
  "max_tokens": ${MAX_TOKENS}
}
JSONEOF

# Write CSV
echo "backend,model,avg_tok_s,stddev,pass" > "$CSV_OUT"
for r in "${RESULTS_JSON[@]}"; do
  echo "$r" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read(), strict=False)
print(f'mlx,{d[\"model\"]},{d.get(\"mean_tps\",0)},{d.get(\"stddev\",0)},{d[\"pass\"]}')
" >> "$CSV_OUT" 2>/dev/null
done

# Summary
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  BURN COMPLETE                                          ║${NC}"
echo -e "${BOLD}║  Passed: ${PASS}/${#MODELS[@]}  ·  Failed: ${FAIL}/${#MODELS[@]}                         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}  Model                          tok/s    ±stddev  ${NC}"
echo "  ─────────────────────────────────────────────────────"
for r in "${RESULTS_JSON[@]}"; do
  echo "$r" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read(), strict=False)
m = d['model'][:32].ljust(32)
if d['pass']:
    t = f\"{d['mean_tps']:.1f}\".rjust(7)
    s = f\"±{d['stddev']:.1f}\".rjust(8)
    print(f'  {m} {t}  {s}  ✓')
else:
    print(f'  {m}     —        —  ✗ {d.get(\"error\",\"\")}')
" 2>/dev/null
done
echo ""
echo "  JSON: ${JSON_OUT}"
echo "  CSV:  ${CSV_OUT}"
echo ""
echo "  Stamped by the architect. $(date)"
