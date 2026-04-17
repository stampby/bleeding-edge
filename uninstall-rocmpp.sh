#!/usr/bin/env bash
# bleeding-edge uninstall-rocmpp.sh — Clean removal of ROCm C++ stack
# "Game over, man. Game over!" — Hudson
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[rocm++]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ROCm C++ — Uninstall                                    ║${NC}"
echo -e "${BOLD}║  This removes everything built by install-rocmpp.sh      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "This will remove:"
echo "  ~/therock/build/          (TheRock build artifacts, ~50GB)"
echo "  ~/rocm-cpp/tools/bench_*  (compiled benchmarks)"
echo "  ~/lemon-mlx-engine/build/ (engine build)"
echo "  ~/man-cave/build/         (FTXUI dashboard build)"
echo "  ~/.rocmpp.env             (environment file)"
echo "  Shell rc entries          (source ~/.rocmpp.env lines)"
echo "  ~/rocmpp-install-logs/    (build logs)"
echo ""
echo "This will NOT remove:"
echo "  ~/therock/                (source code — only build/ is deleted)"
echo "  ~/rocm-cpp/               (source code — only binaries deleted)"
echo "  ~/lemon-mlx-engine/       (source code — only build/ deleted)"
echo "  System ROCm packages      (pacman packages untouched)"
echo "  Models in ~/.cache/        (HuggingFace cache untouched)"
echo ""

read -rp "Proceed with uninstall? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

# Stop any running services
log "Stopping services..."
if systemctl is-active --quiet mlx-engine 2>/dev/null; then
    sudo systemctl stop mlx-engine
    sudo systemctl disable mlx-engine
    ok "mlx-engine service stopped"
fi

# Kill running processes
pkill -f "lemon-mlx-engine/build/server" 2>/dev/null && ok "Killed mlx server" || true
pkill -f "halo1bit-server" 2>/dev/null && ok "Killed halo1bit server" || true

# Remove TheRock build artifacts (the big one)
log "Removing TheRock build artifacts..."
if [[ -d "$HOME/therock/build" ]]; then
    rm -rf "$HOME/therock/build"
    ok "Removed ~/therock/build/ (Tensile kernels, LLVM objects, libraries)"
fi

# Remove compiled binaries
log "Removing compiled binaries..."
rm -f "$HOME/rocm-cpp/tools/bench_gemm" "$HOME/rocm-cpp/tools/bench_ternary" 2>/dev/null
ok "Removed rocm-cpp benchmarks"

if [[ -d "$HOME/lemon-mlx-engine/build" ]]; then
    rm -rf "$HOME/lemon-mlx-engine/build"
    ok "Removed lemon-mlx-engine build"
fi

if [[ -d "$HOME/man-cave/build" ]]; then
    rm -rf "$HOME/man-cave/build"
    ok "Removed man-cave build"
fi

if [[ -d "$HOME/halo-1bit/mlx-engine/build" ]]; then
    rm -rf "$HOME/halo-1bit/mlx-engine/build"
    ok "Removed halo-1bit build"
fi

# Remove environment
log "Removing environment..."
rm -f "$HOME/.rocmpp.env" 2>/dev/null
ok "Removed ~/.rocmpp.env"

# Clean shell rc entries
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$RC" ]]; then
        sed -i '/# ROCm C++ environment/d' "$RC"
        sed -i '/rocmpp.env/d' "$RC"
    fi
done
ok "Cleaned shell rc files"

# Remove logs
rm -rf "$HOME/rocmpp-install-logs" 2>/dev/null
ok "Removed install logs"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Uninstall complete                                      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Source code preserved — only build artifacts removed."
echo "  To rebuild: ./install-rocmpp.sh"
echo "  To fully remove source: rm -rf ~/therock ~/rocm-cpp ~/agent-cpp"
echo ""
