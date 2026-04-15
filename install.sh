#!/usr/bin/env bash
# bleeding-edge install.sh — MLX Engine ROCm setup for AMD GPUs
# "Little bones, little bones, everywhere I go" — Gord Downie
#
# Usage: ./install.sh [--port 8090] [--model mlx-community/Qwen3-4B-4bit]
#
# Detects your GPU, downloads the right binary, verifies, sets up systemd.
# No bullshit. No Docker. No Python. No GGUF.
set -euo pipefail

# ── Defaults ────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-$HOME/mlx-engine}"
MLX_PORT="${MLX_PORT:-8090}"
MLX_HOST="127.0.0.1"
DEFAULT_MODEL="mlx-community/Qwen3-4B-4bit"
RELEASE_TAG="b1004-tech-preview"
REPO="lemonade-sdk/lemon-mlx-engine"
SERVICE_NAME="mlx-engine"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[bleeding-edge]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
die()  { err "$1"; exit 1; }

# ── Parse args ──────────────────────────────────────────────
MODEL="$DEFAULT_MODEL"
SKIP_SERVICE=false
SKIP_VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --port) MLX_PORT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --no-service) SKIP_SERVICE=true; shift ;;
        --no-verify) SKIP_VERIFY=true; shift ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT         Server port (default: 8090)"
            echo "  --model MODEL       Default model to pre-load (default: $DEFAULT_MODEL)"
            echo "  --install-dir DIR   Install directory (default: ~/mlx-engine)"
            echo "  --no-service        Skip systemd service setup"
            echo "  --no-verify         Skip GPU verification"
            echo "  --help              Show this help"
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ── Banner ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  bleeding-edge installer                                ║${NC}"
echo -e "${BOLD}║  MLX Engine ROCm — pure C++ LLM inference               ║${NC}"
echo -e "${BOLD}║  \"Little bones\" — Gord Downie                           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Detect GPU ─────────────────────────────────────
log "Step 1/7: Detecting GPU..."

GPU_ARCH=""
if command -v rocminfo &>/dev/null; then
    GPU_ARCH=$(rocminfo 2>/dev/null | grep -oP 'gfx\d+' | head -1 || true)
fi

if [[ -z "$GPU_ARCH" ]]; then
    # Fallback: check lspci
    if lspci 2>/dev/null | grep -qi "radeon 8060\|strix halo"; then
        GPU_ARCH="gfx1151"
    elif lspci 2>/dev/null | grep -qi "strix point"; then
        GPU_ARCH="gfx1150"
    elif lspci 2>/dev/null | grep -qi "radeon rx 9"; then
        GPU_ARCH="gfx120X"
    elif lspci 2>/dev/null | grep -qi "radeon rx 7"; then
        GPU_ARCH="gfx110X"
    fi
fi

if [[ -z "$GPU_ARCH" ]]; then
    err "Could not detect GPU architecture"
    echo ""
    echo "Supported GPUs:"
    echo "  gfx1151  — Strix Halo (Ryzen AI MAX+ PRO 300)"
    echo "  gfx1150  — Strix Point"
    echo "  gfx110X  — RDNA3 (RX 7000 series)"
    echo "  gfx120X  — RDNA4 (RX 9000 series)"
    echo ""
    read -rp "Enter your GPU architecture manually: " GPU_ARCH
    [[ -z "$GPU_ARCH" ]] && die "No GPU architecture specified"
fi

# Map to release asset naming
case "$GPU_ARCH" in
    gfx1151) ASSET_TARGET="gfx1151" ;;
    gfx1150) ASSET_TARGET="gfx1150" ;;
    gfx1100|gfx1101|gfx1102|gfx1103) ASSET_TARGET="gfx110X" ;;
    gfx1200|gfx1201) ASSET_TARGET="gfx120X" ;;
    *) die "Unsupported GPU architecture: $GPU_ARCH" ;;
esac

ok "GPU detected: ${GPU_ARCH} (asset: ${ASSET_TARGET})"

# ── Step 2: Check kernel ───────────────────────────────────
log "Step 2/7: Checking kernel..."

KERNEL=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL" | cut -d. -f2)

if [[ "$KERNEL_MAJOR" -lt 6 ]] || [[ "$KERNEL_MAJOR" -eq 6 && "$KERNEL_MINOR" -lt 18 ]]; then
    warn "Kernel $KERNEL may be too old. CWSR fix requires 6.18.4+"
    warn "Proceeding anyway — inference may fail with GPU faults"
else
    ok "Kernel: $KERNEL"
fi

# Check CWSR
if grep -qr "cwsr_size" /sys/class/kfd/kfd/topology/nodes/*/properties 2>/dev/null; then
    ok "CWSR support: present"
else
    warn "CWSR properties not found — GPU dispatch may fail"
fi

# ── Step 3: Check dependencies ─────────────────────────────
log "Step 3/7: Checking dependencies..."

MISSING=()
for cmd in curl unzip; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if command -v gh &>/dev/null; then
    ok "GitHub CLI: $(gh --version | head -1)"
    USE_GH=true
else
    warn "GitHub CLI (gh) not found — using curl fallback"
    USE_GH=false
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    die "Missing dependencies: ${MISSING[*]}. Install them first."
fi

ok "Dependencies OK"

# ── Step 4: Download binary ────────────────────────────────
log "Step 4/7: Downloading MLX Engine for ${ASSET_TARGET}..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

ASSET_NAME="mlx-engine-${RELEASE_TAG}-ubuntu-rocm-tech-preview-${ASSET_TARGET}-x64.zip"

if [[ -f "chat" && -f "server" && -f "diagnose" ]]; then
    warn "Existing installation found at $INSTALL_DIR"
    read -rp "Overwrite? (y/N): " OVERWRITE
    [[ "$OVERWRITE" =~ ^[Yy]$ ]] || { ok "Keeping existing installation"; SKIP_DOWNLOAD=true; }
fi

if [[ "${SKIP_DOWNLOAD:-false}" != "true" ]]; then
    if [[ "$USE_GH" == "true" ]]; then
        gh release download "$RELEASE_TAG" -R "$REPO" -p "$ASSET_NAME" --clobber
    else
        DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${ASSET_NAME}"
        log "Downloading from: $DOWNLOAD_URL"
        curl -sL -o "$ASSET_NAME" "$DOWNLOAD_URL"
    fi

    if [[ ! -f "$ASSET_NAME" ]]; then
        die "Download failed. Check your internet connection and GPU target."
    fi

    log "Extracting..."
    unzip -o "$ASSET_NAME" -d .
    rm -f "$ASSET_NAME"
    chmod +x chat server diagnose
    ok "Downloaded and extracted"
fi

ok "Install directory: $INSTALL_DIR"
ls -la chat server diagnose

# ── Step 5: Verify GPU operations ──────────────────────────
if [[ "$SKIP_VERIFY" != "true" ]]; then
    log "Step 5/7: Verifying GPU operations..."
    echo ""

    if LD_LIBRARY_PATH="$INSTALL_DIR" "$INSTALL_DIR/diagnose" mlx-community/Qwen3-0.6B-4bit 2>&1 | head -15; then
        echo ""
        ok "GPU verification passed"
    else
        echo ""
        warn "GPU verification had issues — inference may still work"
        warn "Check kernel version and CWSR support"
    fi
else
    log "Step 5/7: Skipping GPU verification (--no-verify)"
fi

# ── Step 6: Test inference ─────────────────────────────────
log "Step 6/7: Testing inference..."

# Start server temporarily
LD_LIBRARY_PATH="$INSTALL_DIR" "$INSTALL_DIR/server" --port "$MLX_PORT" --host "$MLX_HOST" &
SERVER_PID=$!

# Wait for server to be ready (up to 15 seconds)
log "Waiting for server..."
for i in $(seq 1 15); do
    if curl -s "http://${MLX_HOST}:${MLX_PORT}/health" 2>/dev/null | grep -q "ok"; then
        break
    fi
    sleep 1
done

if curl -s "http://${MLX_HOST}:${MLX_PORT}/health" 2>/dev/null | grep -q "ok"; then
    ok "Server running on port $MLX_PORT"

    log "Loading model: $MODEL (first run downloads from HuggingFace)..."
    RESPONSE=$(curl -s --max-time 300 "http://${MLX_HOST}:${MLX_PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in 5 words.\"}], \"max_tokens\": 30, \"temperature\": 0}" 2>&1)

    if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'][:100])" 2>/dev/null; then
        ok "Inference test passed"
    else
        warn "Inference test returned unexpected response"
        echo "$RESPONSE" | head -3
    fi
else
    warn "Server failed to start — skipping inference test"
fi

# Stop test server
kill "$SERVER_PID" 2>/dev/null
wait "$SERVER_PID" 2>/dev/null || true
sleep 2

# ── Step 7: Systemd service ───────────────────────────────
if [[ "$SKIP_SERVICE" != "true" ]]; then
    log "Step 7/7: Setting up systemd service..."

    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    if [[ -f "$SERVICE_FILE" ]]; then
        warn "Service file already exists: $SERVICE_FILE"
        read -rp "Overwrite? (y/N): " OVERWRITE_SVC
        [[ "$OVERWRITE_SVC" =~ ^[Yy]$ ]] || { ok "Keeping existing service"; SKIP_SVC_WRITE=true; }
    fi

    if [[ "${SKIP_SVC_WRITE:-false}" != "true" ]]; then
        sudo tee "$SERVICE_FILE" > /dev/null << SVCEOF
[Unit]
Description=MLX Engine — C++ LLM Inference (ROCm) — bleeding-edge
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${INSTALL_DIR}
Environment=LD_LIBRARY_PATH=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/server --port ${MLX_PORT} --host ${MLX_HOST}
Restart=on-failure
RestartSec=5
ProtectSystem=full
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
SVCEOF

        sudo systemctl daemon-reload
        ok "Service file created: $SERVICE_FILE"
    fi

    read -rp "Enable and start the service now? (y/N): " START_SVC
    if [[ "$START_SVC" =~ ^[Yy]$ ]]; then
        sudo systemctl enable --now "$SERVICE_NAME"
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            ok "Service running: systemctl status $SERVICE_NAME"
        else
            warn "Service failed to start. Check: journalctl -u $SERVICE_NAME"
        fi
    else
        ok "Service installed but not started. Run: sudo systemctl enable --now $SERVICE_NAME"
    fi
else
    log "Step 7/7: Skipping systemd service (--no-service)"
fi

# ── Done ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Installation complete                                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Install dir:  $INSTALL_DIR"
echo "  GPU:          $GPU_ARCH"
echo "  Port:         $MLX_PORT"
echo "  Model:        $MODEL"
echo ""
echo "  Quick start:"
echo "    cd $INSTALL_DIR"
echo "    LD_LIBRARY_PATH=. ./chat mlx-community/Qwen3-4B-4bit"
echo ""
echo "  API server:"
echo "    LD_LIBRARY_PATH=. ./server --port $MLX_PORT"
echo ""
echo "  Service:"
echo "    sudo systemctl start $SERVICE_NAME"
echo "    curl http://localhost:$MLX_PORT/health"
echo ""
echo "  Docs: https://github.com/stampby/bleeding-edge"
echo "  Discord: https://discord.gg/dSyV646eBs"
echo ""
echo -e "  ${BOLD}\"Little bones, little bones, everywhere I go\"${NC}"
echo -e "  ${BOLD}Stamped by the architect.${NC}"
echo ""
