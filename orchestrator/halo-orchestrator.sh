#!/bin/bash
# ============================================================
# halo-orchestrator — GPU/NPU Auto-Placement for Lemond
# "The only way to do great work is to love what you do."
#   — Steve Jobs (wrong guy, but right quote)
#
# Monitors GPU VRAM, utilization, NPU state, and automatically
# places models on the optimal backend via lemond's API.
#
# Architecture:
#   [request] → lemond(:13305) → orchestrator decides backend
#   GPU ROCm  (vLLM/MLX)  — big dense models, high throughput
#   GPU Vulkan (llamacpp)  — MoE models, GGUF, fallback
#   NPU XDNA2 (FLM)       — small models, whisper, always-on
#
# Placement rules:
#   1. Models ≤4B params → NPU if available, else GPU
#   2. MoE models → Vulkan llamacpp (always)
#   3. Dense models → MLX ROCm (primary), vLLM ROCm (fallback)
#   4. GPU VRAM >80% → spill to NPU or Vulkan
#   5. Whisper/TTS → NPU always (dedicated)
#   6. Multiple small models → pack NPU first, overflow GPU
# ============================================================
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Config ---
LEMOND_HOST="${LEMOND_HOST:-localhost}"
LEMOND_PORT="${LEMOND_PORT:-13305}"
LEMOND_URL="http://${LEMOND_HOST}:${LEMOND_PORT}"
POLL_INTERVAL="${POLL_INTERVAL:-10}"   # seconds between placement checks
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/halo-orchestrator.log"
STATE_FILE="/tmp/halo-orchestrator-state.json"

# GPU sysfs paths (Strix Halo)
GPU_SYSFS="/sys/devices/pci0000:00/0000:00:08.1/0000:c5:00.0"
GPU_VRAM_USED="${GPU_SYSFS}/mem_info_vram_used"
GPU_VRAM_TOTAL="${GPU_SYSFS}/mem_info_vram_total"
GPU_BUSY="${GPU_SYSFS}/gpu_busy_percent"
GPU_GTT_USED="${GPU_SYSFS}/mem_info_gtt_used"
GPU_GTT_TOTAL="${GPU_SYSFS}/mem_info_gtt_total"

# NPU
NPU_DEV="/dev/accel0"
NPU_FW="/sys/devices/pci0000:00/0000:00:08.2/0000:c6:00.1/fw_version"

# Thresholds
GPU_VRAM_HIGH_PCT=80     # spill to other backends above this
GPU_VRAM_CRIT_PCT=95     # refuse GPU placement above this
GPU_BUSY_HIGH_PCT=90     # consider GPU overloaded
NPU_MAX_MODELS=2         # max concurrent models on NPU
SMALL_MODEL_CUTOFF_B=4   # models ≤ this (billions) prefer NPU

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Logging ---
mkdir -p "$LOG_DIR"
log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
info() { echo -e "${GREEN}[ORCH]${NC} $*"; log "INFO  $*"; }
warn() { echo -e "${YELLOW}[ORCH]${NC} $*"; log "WARN  $*"; }
error(){ echo -e "${RED}[ORCH]${NC} $*"; log "ERROR $*"; }

# ============================================================
# Hardware Queries
# ============================================================

gpu_vram_used_mb() {
    if [[ -r "$GPU_VRAM_USED" ]]; then
        echo $(( $(cat "$GPU_VRAM_USED") / 1048576 ))
    else
        echo 0
    fi
}

gpu_vram_total_mb() {
    if [[ -r "$GPU_VRAM_TOTAL" ]]; then
        echo $(( $(cat "$GPU_VRAM_TOTAL") / 1048576 ))
    else
        echo 512  # Strix Halo default dedicated VRAM
    fi
}

gpu_gtt_used_mb() {
    if [[ -r "$GPU_GTT_USED" ]]; then
        echo $(( $(cat "$GPU_GTT_USED") / 1048576 ))
    else
        echo 0
    fi
}

gpu_gtt_total_mb() {
    if [[ -r "$GPU_GTT_TOTAL" ]]; then
        echo $(( $(cat "$GPU_GTT_TOTAL") / 1048576 ))
    else
        echo 0
    fi
}

gpu_busy_pct() {
    if [[ -r "$GPU_BUSY" ]]; then
        cat "$GPU_BUSY"
    else
        echo 0
    fi
}

gpu_vram_pct() {
    local used total
    used=$(gpu_vram_used_mb)
    total=$(gpu_vram_total_mb)
    if [[ $total -eq 0 ]]; then
        echo 0
    else
        echo $(( used * 100 / total ))
    fi
}

npu_available() {
    [[ -c "$NPU_DEV" ]] && return 0 || return 1
}

npu_fw_version() {
    if [[ -r "$NPU_FW" ]]; then
        cat "$NPU_FW"
    else
        echo "unknown"
    fi
}

gpu_temp() {
    # Try rocm-smi first, fall back to hwmon
    local temp
    temp=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
    if [[ -n "$temp" ]]; then
        echo $(( temp / 1000 ))
    else
        echo "?"
    fi
}

# ============================================================
# Lemond API
# ============================================================

lemond_get() {
    curl -sf --connect-timeout 3 --max-time 10 "${LEMOND_URL}$1" 2>/dev/null
}

lemond_post() {
    curl -sf --connect-timeout 3 --max-time 30 \
        -X POST -H "Content-Type: application/json" \
        -d "$2" "${LEMOND_URL}$1" 2>/dev/null
}

lemond_models() {
    lemond_get "/v1/models" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for m in data.get('data', []):
        print(m.get('id', 'unknown'))
except: pass
" 2>/dev/null
}

lemond_status() {
    lemond_get "/internal/status" 2>/dev/null || \
    lemond_get "/api/status" 2>/dev/null || \
    echo "{}"
}

# ============================================================
# Model Classification
# ============================================================

# Classify a model by name → size bucket + architecture
classify_model() {
    local model="$1"
    local model_lower
    model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    # Architecture: moe or dense
    local arch="dense"
    if echo "$model_lower" | grep -qiE 'moe|mixtral|qwen.*moe|dbrx|grok|switch|arctic|jamba|deepseek.*v[23]|a[0-9]+b'; then
        # Check for MoE indicators: explicit MoE tag, known MoE models, AxB naming
        if echo "$model_lower" | grep -qiE 'mixtral|dbrx|grok|switch|arctic|jamba'; then
            arch="moe"
        elif echo "$model_lower" | grep -qiP '\d+b\.a\d+b|\d+b-a\d+b'; then
            arch="moe"
        elif echo "$model_lower" | grep -qi 'moe'; then
            arch="moe"
        fi
    fi

    # Size extraction (billions of params)
    local size_b=0
    if [[ "$model_lower" =~ ([0-9]+\.?[0-9]*)b ]]; then
        size_b="${BASH_REMATCH[1]}"
    fi

    # Task type
    local task="llm"
    if echo "$model_lower" | grep -qiE 'whisper|speech|asr|stt'; then
        task="stt"
    elif echo "$model_lower" | grep -qiE 'kokoro|tts|bark|parler|f5-tts|piper'; then
        task="tts"
    elif echo "$model_lower" | grep -qiE 'stable.*diff|flux|sdxl|comfy|imagen'; then
        task="image"
    fi

    echo "${size_b}|${arch}|${task}"
}

# ============================================================
# Placement Engine
# ============================================================

# Decide which backend a model should go on
# Returns: mlx | vllm | llamacpp | flm
decide_placement() {
    local model="$1"
    local classification
    classification=$(classify_model "$model")

    local size_b arch task
    IFS='|' read -r size_b arch task <<< "$classification"

    local vram_pct busy_pct has_npu
    vram_pct=$(gpu_vram_pct)
    busy_pct=$(gpu_busy_pct)
    has_npu=false
    npu_available && has_npu=true

    echo "[$(date '+%H:%M:%S')] DECIDE model=$model size=${size_b}B arch=$arch task=$task vram=${vram_pct}% gpu_busy=${busy_pct}% npu=$has_npu" >> "$LOG_FILE"

    # Rule 1: Audio models → NPU always
    if [[ "$task" == "stt" || "$task" == "tts" ]]; then
        if $has_npu; then
            echo "flm"
            return
        fi
        # No NPU — fall through to GPU
    fi

    # Rule 2: MoE → Vulkan llamacpp (always — MLX is slow on MoE)
    if [[ "$arch" == "moe" ]]; then
        echo "llamacpp"
        return
    fi

    # Rule 3: GPU overloaded → NPU for small models, Vulkan for big
    if [[ $vram_pct -ge $GPU_VRAM_CRIT_PCT ]]; then
        if $has_npu && (( $(echo "$size_b <= $SMALL_MODEL_CUTOFF_B" | bc -l 2>/dev/null || echo 1) )); then
            echo "flm"
            return
        fi
        echo "llamacpp"  # Vulkan as last resort
        return
    fi

    # Rule 4: Small models (≤4B) → NPU if available and not overloaded
    if (( $(echo "$size_b <= $SMALL_MODEL_CUTOFF_B" | bc -l 2>/dev/null || echo 1) )) && [[ "$size_b" != "0" ]]; then
        if $has_npu; then
            echo "flm"
            return
        fi
    fi

    # Rule 5: Dense models → MLX ROCm (primary)
    if [[ $vram_pct -lt $GPU_VRAM_HIGH_PCT ]]; then
        echo "mlx"
        return
    fi

    # Rule 6: GPU under pressure but not critical → vLLM (better memory management)
    if [[ $vram_pct -lt $GPU_VRAM_CRIT_PCT ]]; then
        echo "vllm"
        return
    fi

    # Default fallback
    echo "llamacpp"
}

# ============================================================
# Status Dashboard
# ============================================================

show_status() {
    local vram_used vram_total vram_pct gtt_used gtt_total busy temp
    vram_used=$(gpu_vram_used_mb)
    vram_total=$(gpu_vram_total_mb)
    vram_pct=$(gpu_vram_pct)
    gtt_used=$(gpu_gtt_used_mb)
    gtt_total=$(gpu_gtt_total_mb)
    busy=$(gpu_busy_pct)
    temp=$(gpu_temp)

    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Halo Orchestrator v${VERSION} — System Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}GPU (Radeon 8060S / gfx1151)${NC}"
    echo -e "    VRAM:        ${vram_used} / ${vram_total} MB (${vram_pct}%)"
    echo -e "    GTT:         ${gtt_used} / ${gtt_total} MB"
    echo -e "    Utilization: ${busy}%"
    echo -e "    Temperature: ${temp}°C"
    echo ""

    if npu_available; then
        echo -e "  ${BOLD}NPU (XDNA2 RyzenAI)${NC}"
        echo -e "    Status:      ${GREEN}available${NC}"
        echo -e "    Firmware:    $(npu_fw_version)"
    else
        echo -e "  ${BOLD}NPU${NC}"
        echo -e "    Status:      ${RED}not available${NC}"
    fi
    echo ""

    echo -e "  ${BOLD}Lemond (${LEMOND_URL})${NC}"
    local models
    models=$(lemond_models 2>/dev/null)
    if [[ -n "$models" ]]; then
        echo -e "    Status:      ${GREEN}running${NC}"
        echo -e "    Models loaded:"
        while IFS= read -r m; do
            local placement
            placement=$(decide_placement "$m")
            echo -e "      ${CYAN}$m${NC} → $placement"
        done <<< "$models"
    else
        echo -e "    Status:      ${RED}not reachable${NC}"
    fi
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════${NC}"
}

# ============================================================
# Placement Advisor (dry-run for a model)
# ============================================================

advise() {
    local model="$1"
    local classification placement
    classification=$(classify_model "$model")
    placement=$(decide_placement "$model" 2>/dev/null)

    local size_b arch task
    IFS='|' read -r size_b arch task <<< "$classification"

    echo -e "${CYAN}Model:${NC}    $model"
    echo -e "${CYAN}Size:${NC}     ${size_b}B params"
    echo -e "${CYAN}Arch:${NC}     $arch"
    echo -e "${CYAN}Task:${NC}     $task"
    echo -e "${CYAN}Placement:${NC} ${GREEN}${BOLD}$placement${NC}"
    echo ""

    case "$placement" in
        mlx)     echo "  → MLX Engine ROCm (hipBLASLt, HuggingFace native)" ;;
        vllm)    echo "  → vLLM ROCm (PagedAttention, AWQ/GPTQ)" ;;
        llamacpp)echo "  → llama.cpp Vulkan (GGUF, MoE optimized)" ;;
        flm)     echo "  → FLM NPU (XDNA2, low power, always-on)" ;;
    esac
}

# ============================================================
# Model Loading — wire placement to lemond CLI
# ============================================================

# Query lemond's registry to find which backend a model is registered under
model_registered_backend() {
    local model="$1"
    lemonade backends list 2>/dev/null | grep -i "^${model}" | awk '{print $NF}' | head -1
}

# Load a model on the recommended backend
load_model() {
    local model="$1"
    local ctx="${2:-4096}"
    local placement

    placement=$(decide_placement "$model")
    info "Model:     $model"
    info "Placement: $placement"

    # Check if model is already loaded
    local loaded
    loaded=$(lemond_models 2>/dev/null)
    if echo "$loaded" | grep -qi "^${model}$"; then
        warn "Model '$model' is already loaded"
        return 0
    fi

    # Check what backend the model is registered under in lemond
    local registered
    registered=$(model_registered_backend "$model")
    local actual_placement="$placement"
    local load_target="$model"

    # Resolve backend conflicts — GGUF can't run on MLX/vLLM, etc.
    case "$placement" in
        mlx|vllm)
            if [[ "$registered" == "llamacpp" ]]; then
                warn "Model '$model' is GGUF — cannot load on $placement (needs HF format)"
                warn "Falling back to llamacpp vulkan"
                actual_placement="llamacpp"
            fi
            ;;
        flm)
            if [[ "$registered" != "flm" ]]; then
                # Try to find FLM variant
                local flm_variant
                flm_variant=$(lemonade backends list 2>/dev/null | grep -i "$(echo "$model" | sed 's/-GGUF//' | sed 's/-FLM//').*FLM" | awk '{print $1}' | head -1)
                if [[ -n "$flm_variant" ]]; then
                    info "Found FLM variant: $flm_variant"
                    load_target="$flm_variant"
                else
                    warn "No FLM variant for '$model' — falling back to llamacpp vulkan"
                    actual_placement="llamacpp"
                fi
            fi
            ;;
    esac

    # Execute the load
    local exit_code=0
    info "Loading:   $load_target → $actual_placement"
    echo ""

    case "$actual_placement" in
        llamacpp)
            info "Command:   lemonade load $load_target --llamacpp vulkan --ctx-size $ctx"
            lemonade load "$load_target" --llamacpp vulkan --ctx-size "$ctx" 2>&1 | while IFS= read -r line; do
                echo -e "  ${CYAN}│${NC} $line"
            done
            exit_code=${PIPESTATUS[0]}
            ;;
        flm)
            info "Command:   lemonade load $load_target"
            lemonade load "$load_target" 2>&1 | while IFS= read -r line; do
                echo -e "  ${CYAN}│${NC} $line"
            done
            exit_code=${PIPESTATUS[0]}
            ;;
        kokoro)
            info "Command:   lemonade load $load_target"
            lemonade load "$load_target" 2>&1 | while IFS= read -r line; do
                echo -e "  ${CYAN}│${NC} $line"
            done
            exit_code=${PIPESTATUS[0]}
            ;;
        whispercpp)
            info "Command:   lemonade load $load_target --whispercpp vulkan"
            lemonade load "$load_target" --whispercpp vulkan 2>&1 | while IFS= read -r line; do
                echo -e "  ${CYAN}│${NC} $line"
            done
            exit_code=${PIPESTATUS[0]}
            ;;
        *)
            # mlx, vllm, or anything else — let lemond decide
            info "Command:   lemonade load $load_target --ctx-size $ctx"
            lemonade load "$load_target" --ctx-size "$ctx" 2>&1 | while IFS= read -r line; do
                echo -e "  ${CYAN}│${NC} $line"
            done
            exit_code=${PIPESTATUS[0]}
            ;;
    esac

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        info "Loaded $load_target on $actual_placement"
        log "LOADED model=$load_target backend=$actual_placement vram=$(gpu_vram_pct)% gpu_busy=$(gpu_busy_pct)%"
    else
        error "Failed to load model (exit $exit_code)"
        error "Check: lemonade logs"
        return 1
    fi
}

# Unload a model
unload_model() {
    local model="$1"

    # Check if model is loaded
    local loaded
    loaded=$(lemond_models 2>/dev/null)
    if ! echo "$loaded" | grep -qi "^${model}$"; then
        warn "Model '$model' is not loaded"
        return 0
    fi

    info "Unloading: $model"
    lemonade unload "$model" 2>&1 | while IFS= read -r line; do
        echo -e "  ${CYAN}│${NC} $line"
    done

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        info "Model unloaded"
        echo "[$(date -Iseconds)] UNLOADED model=$model vram=$(gpu_vram_pct)%" >> "$LOG_FILE"
    else
        error "Failed to unload model"
        return 1
    fi
}

# Rebalance — check all loaded models and suggest moves
rebalance() {
    info "Analyzing loaded models for rebalancing..."
    echo ""

    local models
    models=$(lemond_models 2>/dev/null)
    if [[ -z "$models" ]]; then
        warn "No models loaded"
        return
    fi

    local moves=0
    while IFS= read -r model; do
        local current_backend recommended
        # Determine what backend it's currently on from registry
        current_backend=$(model_registered_backend "$model")
        recommended=$(decide_placement "$model")

        # Map registered backend to our placement names
        local current_placement="unknown"
        case "$current_backend" in
            llamacpp)   current_placement="llamacpp" ;;
            flm)        current_placement="flm" ;;
            kokoro)     current_placement="kokoro" ;;
            whispercpp) current_placement="whispercpp" ;;
            sd-cpp)     current_placement="sdcpp" ;;
            *)          current_placement="$current_backend" ;;
        esac

        if [[ "$current_placement" != "$recommended" ]]; then
            echo -e "  ${YELLOW}MOVE${NC}  $model: $current_placement → ${GREEN}$recommended${NC}"
            moves=$((moves + 1))
        else
            echo -e "  ${GREEN}OK${NC}    $model: $current_placement"
        fi
    done <<< "$models"

    echo ""
    if [[ $moves -gt 0 ]]; then
        info "$moves model(s) could be rebalanced"
        info "Run 'halo-orchestrator.sh place <model>' to move individual models"
    else
        info "All models optimally placed"
    fi
}

# ============================================================
# Daemon Mode — watch and rebalance
# ============================================================

daemon_loop() {
    info "Orchestrator daemon started (poll every ${POLL_INTERVAL}s)"
    info "GPU sysfs: $GPU_SYSFS"
    npu_available && info "NPU: available (fw $(npu_fw_version))" || warn "NPU: not available"

    while true; do
        local vram_pct busy_pct
        vram_pct=$(gpu_vram_pct)
        busy_pct=$(gpu_busy_pct)

        # Write state for external consumers
        cat > "$STATE_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "gpu": {
        "vram_used_mb": $(gpu_vram_used_mb),
        "vram_total_mb": $(gpu_vram_total_mb),
        "vram_pct": $vram_pct,
        "gtt_used_mb": $(gpu_gtt_used_mb),
        "gtt_total_mb": $(gpu_gtt_total_mb),
        "busy_pct": $busy_pct,
        "temp_c": $(gpu_temp)
    },
    "npu": {
        "available": $(npu_available && echo true || echo false),
        "fw_version": "$(npu_fw_version)"
    },
    "thresholds": {
        "vram_high_pct": $GPU_VRAM_HIGH_PCT,
        "vram_crit_pct": $GPU_VRAM_CRIT_PCT,
        "busy_high_pct": $GPU_BUSY_HIGH_PCT
    }
}
EOF

        # Alert on high utilization
        if [[ $vram_pct -ge $GPU_VRAM_CRIT_PCT ]]; then
            warn "GPU VRAM critical: ${vram_pct}% — new models will spill to NPU/Vulkan"
        elif [[ $vram_pct -ge $GPU_VRAM_HIGH_PCT ]]; then
            warn "GPU VRAM high: ${vram_pct}% — approaching spill threshold"
        fi

        if [[ $busy_pct -ge $GPU_BUSY_HIGH_PCT ]]; then
            warn "GPU utilization high: ${busy_pct}%"
        fi

        sleep "$POLL_INTERVAL"
    done
}

# ============================================================
# CLI
# ============================================================

usage() {
    cat << EOF
${BOLD}halo-orchestrator v${VERSION}${NC} — GPU/NPU Auto-Placement for Lemond

${BOLD}Usage:${NC}
  ./halo-orchestrator.sh <command> [options]

${BOLD}Commands:${NC}
  status              Show system status (GPU, NPU, loaded models)
  advise <model>      Recommend backend for a model (dry-run)
  place <model>       Load model on recommended backend via lemond
  unload <model>      Unload a model from lemond
  rebalance           Analyze all loaded models, suggest optimal moves
  daemon              Run as background daemon (poll + rebalance)
  metrics             Output JSON metrics (for dashboards)

${BOLD}Options:${NC}
  --poll <seconds>    Daemon poll interval (default: 10)
  --port <port>       Lemond port (default: 13305)
  -h, --help          Show this help

${BOLD}Placement Rules:${NC}
  Audio (whisper/tts)     → NPU always
  MoE models              → Vulkan llamacpp (MLX is slow on MoE)
  Dense ≤${SMALL_MODEL_CUTOFF_B}B              → NPU if available
  Dense >4B               → MLX ROCm (primary)
  GPU VRAM >${GPU_VRAM_HIGH_PCT}%          → vLLM (better memory mgmt)
  GPU VRAM >${GPU_VRAM_CRIT_PCT}%          → spill to NPU/Vulkan

${BOLD}Examples:${NC}
  ./halo-orchestrator.sh status
  ./halo-orchestrator.sh advise Qwen3-8B
  ./halo-orchestrator.sh advise Mixtral-8x22B
  ./halo-orchestrator.sh advise whisper-large-v3-turbo
  ./halo-orchestrator.sh daemon --poll 15
EOF
    exit 0
}

# Parse CLI
COMMAND="${1:-}"
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --poll)     POLL_INTERVAL="$2"; shift 2 ;;
        --port)     LEMOND_PORT="$2"; LEMOND_URL="http://${LEMOND_HOST}:${LEMOND_PORT}"; shift 2 ;;
        --ctx-size) CTX_SIZE="$2"; shift 2 ;;
        -h|--help)  usage ;;
        *)
            # Might be a model name for advise/place
            MODEL_ARG="$1"
            shift
            ;;
    esac
done

case "$COMMAND" in
    status)
        show_status
        ;;
    advise)
        if [[ -z "${MODEL_ARG:-}" ]]; then
            error "Usage: halo-orchestrator.sh advise <model-name>"
            exit 1
        fi
        advise "$MODEL_ARG"
        ;;
    place)
        if [[ -z "${MODEL_ARG:-}" ]]; then
            error "Usage: halo-orchestrator.sh place <model-name>"
            exit 1
        fi
        load_model "$MODEL_ARG" "${CTX_SIZE:-4096}"
        ;;
    unload)
        if [[ -z "${MODEL_ARG:-}" ]]; then
            error "Usage: halo-orchestrator.sh unload <model-name>"
            exit 1
        fi
        unload_model "$MODEL_ARG"
        ;;
    rebalance)
        rebalance
        ;;
    daemon)
        daemon_loop
        ;;
    metrics)
        # One-shot JSON output
        cat << EOF
{
    "gpu_vram_used_mb": $(gpu_vram_used_mb),
    "gpu_vram_total_mb": $(gpu_vram_total_mb),
    "gpu_vram_pct": $(gpu_vram_pct),
    "gpu_busy_pct": $(gpu_busy_pct),
    "gpu_temp_c": $(gpu_temp),
    "npu_available": $(npu_available && echo true || echo false),
    "npu_fw": "$(npu_fw_version)"
}
EOF
        ;;
    ""|"-h"|"--help")
        usage
        ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        ;;
esac
