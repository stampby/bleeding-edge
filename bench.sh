#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# halo-benchmarks — Standardized LLM Inference Benchmark Suite
# Stamped by the architect
# "I'll be back." — T-800
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
PROMPT="Explain the concept of nuclear fusion in detail, covering the physics, current research approaches, and potential timeline for commercial viability."
MAX_TOKENS=256
WARMUP_ROUNDS=1
BENCH_ROUNDS=3
RESULTS_DIR="$(dirname "$0")/results"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RESULTS_FILE="${RESULTS_DIR}/bench-${TIMESTAMP}.json"
CSV_FILE="${RESULTS_DIR}/bench-${TIMESTAMP}.csv"

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════════════════════════╗"
  echo "  ║        HALO BENCHMARK SUITE — BURN IT DOWN        ║"
  echo "  ║           AMD Strix Halo · gfx1151 · NPU          ║"
  echo "  ╚═══════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Hardware detection ──────────────────────────────────────────────
detect_hardware() {
  GPU_NAME=$(rocminfo 2>/dev/null | grep "Marketing Name" | grep -v CPU | head -1 | sed 's/.*: *//' || echo "unknown")
  CPU_NAME=$(lscpu 2>/dev/null | grep "Model name" | sed 's/.*: *//' || echo "unknown")
  MEM_TOTAL=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
  KERNEL=$(uname -r)
  ROCM_VER=$(cat /opt/rocm/.info/version 2>/dev/null || echo "unknown")
  NPU_NAME=$(rocminfo 2>/dev/null | grep -A1 "aie2p" | grep "Marketing" | sed 's/.*: *//' || echo "none")
}

# ── Benchmark one model ────────────────────────────────────────────
bench_model() {
  local backend="$1"    # mlx | prism | lemond
  local port="$2"
  local model="$3"
  local label="$4"      # display name
  local hw="$5"         # GPU-ROCm | GPU-Vulkan | NPU-FLM

  echo -e "${YELLOW}[${backend}]${NC} ${BOLD}${label}${NC} (${hw}) on :${port}"

  # Warmup
  for ((i=1; i<=WARMUP_ROUNDS; i++)); do
    echo -ne "  warmup ${i}/${WARMUP_ROUNDS}... "
    local warmup_resp
    warmup_resp=$(curl -s --max-time 180 -X POST "http://localhost:${port}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"max_tokens\":16}" 2>&1)
    if echo "$warmup_resp" | grep -qi "error\|failed\|unsupported"; then
      echo -e "${RED}FAILED — skipping${NC}"
      echo ""
      return 0
    fi
    echo "done"
  done

  # Benchmark rounds
  local tok_sum=0
  local ttft_sum=0
  local tok_values=""

  for ((i=1; i<=BENCH_ROUNDS; i++)); do
    echo -ne "  round ${i}/${BENCH_ROUNDS}... "

    local resp
    resp=$(curl -s --max-time 300 -X POST "http://localhost:${port}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${PROMPT}\"}],\"max_tokens\":${MAX_TOKENS},\"temperature\":0.0}" 2>&1 || true)

    if [ -z "$resp" ] || echo "$resp" | grep -qi "error"; then
      echo -e "${RED}FAILED${NC}"
      continue
    fi

    # Extract metrics — handle different response formats
    local comp_tokens ttft tps

    # Try lemond format (decoding_speed_tps)
    tps=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); u=d.get('usage',{}); print(u.get('decoding_speed_tps', 0))" 2>/dev/null || echo "0")
    ttft=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); u=d.get('usage',{}); print(u.get('prefill_duration_ttft', 0))" 2>/dev/null || echo "0")
    comp_tokens=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")

    # Try llama.cpp format (timings.predicted_per_second)
    if [ "$(echo "$tps" | cut -d. -f1)" = "0" ]; then
      tps=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('timings',{}).get('predicted_per_second',0))" 2>/dev/null || echo "0")
      ttft=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('timings',{}); print(t.get('prompt_ms',0)/1000)" 2>/dev/null || echo "0")
    fi

    # MLX doesn't return timing — measure externally
    if [ "$(echo "$tps" | cut -d. -f1)" = "0" ] && [ "$comp_tokens" -gt 0 ] 2>/dev/null; then
      # Re-run with timing
      local start_ms end_ms elapsed
      start_ms=$(date +%s%N)
      resp=$(curl -s --max-time 300 -X POST "http://localhost:${port}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${PROMPT}\"}],\"max_tokens\":${MAX_TOKENS},\"temperature\":0.0}" 2>&1)
      end_ms=$(date +%s%N)
      elapsed=$(echo "scale=3; ($end_ms - $start_ms) / 1000000000" | bc)
      comp_tokens=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")
      if [ "$comp_tokens" -gt 0 ] 2>/dev/null; then
        tps=$(echo "scale=1; $comp_tokens / $elapsed" | bc)
      fi
    fi

    echo -e "  ${GREEN}${tps} tok/s${NC} (${comp_tokens} tokens)"

    tok_sum=$(echo "$tok_sum + $tps" | bc)
    ttft_sum=$(echo "$ttft_sum + $ttft" | bc)
    tok_values="${tok_values}${tps},"
  done

  # Calculate averages
  local avg_tps avg_ttft
  avg_tps=$(echo "scale=1; $tok_sum / $BENCH_ROUNDS" | bc)
  avg_ttft=$(echo "scale=3; $ttft_sum / $BENCH_ROUNDS" | bc)

  # Calculate stddev
  local stddev
  stddev=$(python3 -c "
import statistics
vals = [float(x) for x in '${tok_values}'.strip(',').split(',') if x]
print(f'{statistics.stdev(vals):.1f}' if len(vals) > 1 else '0.0')
" 2>/dev/null || echo "0.0")

  echo -e "  ${BOLD}→ AVG: ${avg_tps} ±${stddev} tok/s  TTFT: ${avg_ttft}s${NC}"
  echo ""

  # Append to results
  echo "{\"backend\":\"${backend}\",\"model\":\"${label}\",\"hardware\":\"${hw}\",\"port\":${port},\"avg_tps\":${avg_tps},\"stddev\":${stddev},\"avg_ttft\":${avg_ttft},\"rounds\":${BENCH_ROUNDS},\"max_tokens\":${MAX_TOKENS},\"timestamp\":\"${TIMESTAMP}\"}" >> "${RESULTS_FILE}.tmp"
  echo "${backend},${label},${hw},${avg_tps},${stddev},${avg_ttft},${comp_tokens}" >> "${CSV_FILE}"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  banner
  detect_hardware
  mkdir -p "$RESULTS_DIR"

  echo -e "${BOLD}Hardware:${NC}"
  echo "  CPU: ${CPU_NAME}"
  echo "  GPU: ${GPU_NAME}"
  echo "  NPU: ${NPU_NAME}"
  echo "  RAM: ${MEM_TOTAL}GB unified"
  echo "  Kernel: ${KERNEL}"
  echo "  ROCm: ${ROCM_VER}"
  echo ""

  # CSV header
  echo "backend,model,hardware,avg_tok_s,stddev,avg_ttft_s,completion_tokens" > "${CSV_FILE}"

  # ── Check which backends are up ───────────────────────────────
  MLX_UP=false; PRISM_UP=false; LEMOND_UP=false

  curl -s http://localhost:8080/health > /dev/null 2>&1 && MLX_UP=true
  curl -s http://localhost:8081/health > /dev/null 2>&1 && PRISM_UP=true
  curl -s http://localhost:13399/health > /dev/null 2>&1 && LEMOND_UP=true

  echo -e "${BOLD}Backends:${NC}"
  $MLX_UP && echo -e "  ${GREEN}✓${NC} MLX Engine :8080 (ROCm)" || echo -e "  ${RED}✗${NC} MLX Engine :8080"
  $PRISM_UP && echo -e "  ${GREEN}✓${NC} Prism llama.cpp :8081 (Vulkan)" || echo -e "  ${RED}✗${NC} Prism llama.cpp :8081"
  $LEMOND_UP && echo -e "  ${GREEN}✓${NC} lemond :13399 (NPU/FLM)" || echo -e "  ${RED}✗${NC} lemond :13399"
  echo ""

  echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}          STARTING BURN — ${BENCH_ROUNDS} rounds each${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
  echo ""

  # ── MLX Engine benchmarks (ROCm GPU) ──────────────────────────
  if $MLX_UP; then
    echo -e "${CYAN}── MLX Engine (ROCm · hipBLASLt · gfx1151) ──${NC}"
    bench_model "mlx" 8080 "mlx-community/Qwen3-0.6B-4bit"  "Qwen3-0.6B-4bit"  "GPU-ROCm"
    bench_model "mlx" 8080 "mlx-community/Qwen3-1.7B-4bit"  "Qwen3-1.7B-4bit"  "GPU-ROCm"
    bench_model "mlx" 8080 "mlx-community/Qwen3-4B-4bit"    "Qwen3-4B-4bit"    "GPU-ROCm"
    bench_model "mlx" 8080 "mlx-community/Qwen3-8B-4bit"    "Qwen3-8B-4bit"    "GPU-ROCm"
    bench_model "mlx" 8080 "mlx-community/Phi-4-mini-instruct-4bit" "Phi-4-mini-4bit" "GPU-ROCm"
  fi

  # ── Prism llama.cpp benchmarks (Vulkan GPU) ───────────────────
  if $PRISM_UP; then
    echo -e "${CYAN}── Prism llama.cpp (Vulkan · gfx1151) ──${NC}"
    bench_model "prism" 8081 "Qwen3-Coder-Next" "Qwen3-Coder-Next-TQ1_0" "GPU-Vulkan"
  fi

  # ── lemond/FLM benchmarks (NPU) ──────────────────────────────
  if $LEMOND_UP; then
    echo -e "${CYAN}── lemond/FastFlowLM (RyzenAI NPU · aie2p) ──${NC}"
    bench_model "lemond" 13399 "qwen3-0.6b-FLM"  "Qwen3-0.6B-FLM"  "NPU-FLM"
    bench_model "lemond" 13399 "qwen3-8b-FLM"    "Qwen3-8B-FLM"    "NPU-FLM"
    bench_model "lemond" 13399 "llama3.2-1b-FLM"  "Llama-3.2-1B-FLM" "NPU-FLM"
    bench_model "lemond" 13399 "llama3.2-3b-FLM"  "Llama-3.2-3B-FLM" "NPU-FLM"
    bench_model "lemond" 13399 "gemma3-1b-FLM"  "Gemma3-1B-FLM"  "NPU-FLM"
  fi

  # ── Finalize results ──────────────────────────────────────────
  if [ -f "${RESULTS_FILE}.tmp" ]; then
    echo "[" > "$RESULTS_FILE"
    sed '$ ! s/$/,/' "${RESULTS_FILE}.tmp" >> "$RESULTS_FILE"
    echo "]" >> "$RESULTS_FILE"
    rm "${RESULTS_FILE}.tmp"
  fi

  echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}                    BURN COMPLETE${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo "Results: ${RESULTS_FILE}"
  echo "CSV:     ${CSV_FILE}"
  echo ""

  # Print summary table
  echo -e "${BOLD}SUMMARY${NC}"
  echo "─────────────────────────────────────────────────────────────"
  printf "%-8s %-28s %-12s %10s\n" "BACKEND" "MODEL" "HARDWARE" "TOK/S"
  echo "─────────────────────────────────────────────────────────────"
  while IFS=, read -r be mo hw tps sd ttft ct; do
    [ "$be" = "backend" ] && continue
    printf "%-8s %-28s %-12s %7s ±%s\n" "$be" "$mo" "$hw" "$tps" "$sd"
  done < "$CSV_FILE"
  echo "─────────────────────────────────────────────────────────────"
  echo ""
  echo -e "${GREEN}\"I'll be back.\" — T-800${NC}"
}

main "$@"
