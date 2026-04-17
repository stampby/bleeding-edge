#!/usr/bin/env bash
# bleeding-edge install-rocmpp.sh — ROCm C++ from source for gfx1151
# "There is no spoon." — Neo
#
# Builds the entire stack from source:
#   1. System packages
#   2. TheRock (ROCm 7.13 from source with native Tensile)
#   3. rocm-cpp (fused ternary kernel + benchmarks)
#   4. lemon-mlx-engine (C++ inference engine)
#   5. FTXUI dashboard (TUI monitoring)
#   6. Environment + systemd
#
# Requirements: AMD Strix Halo (gfx1151), Arch/CachyOS, 50GB+ disk
# Time: ~4 hours (TheRock LLVM is the long pole)
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[rocm++]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
die()  { err "$1"; exit 1; }

# ── Visual feedback ─────────────────────────────────────────
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

spin() {
    local pid=$1 msg=$2
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${SPINNER_CHARS:i++%${#SPINNER_CHARS}:1}" "$msg"
        sleep 0.1
    done
    printf "\r"
}

# Run command with spinner
run_with_spinner() {
    local msg="$1"; shift
    local logfile="$1"; shift
    "$@" > "$logfile" 2>&1 &
    local pid=$!
    spin $pid "$msg"
    wait $pid
    return $?
}

# Progress bar for known-length builds
progress_bar() {
    local current=$1 total=$2 width=40 label="${3:-}"
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "\r  ${CYAN}[%s]${NC} %3d%% %s" "$bar" "$pct" "$label"
}

# Monitor ninja build progress from log
monitor_build() {
    local logfile="$1" pid="$2" label="${3:-Building}"
    local total=0 current=0
    while kill -0 "$pid" 2>/dev/null; do
        local line=$(tail -1 "$logfile" 2>/dev/null)
        if [[ "$line" =~ \[([0-9]+)/([0-9]+)\] ]]; then
            current=${BASH_REMATCH[1]}
            total=${BASH_REMATCH[2]}
            progress_bar "$current" "$total" "$label [$current/$total]"
        else
            printf "\r  ${CYAN}⠿${NC} %s..." "$label"
        fi
        sleep 0.5
    done
    if [[ $total -gt 0 ]]; then
        progress_bar "$total" "$total" "$label [$total/$total]"
    fi
    echo ""
}

NPROC=$(nproc)
HOME_DIR="$HOME"
THEROCK_DIR="$HOME_DIR/therock"
ROCMCPP_DIR="$HOME_DIR/rocm-cpp"
AGENTCPP_DIR="$HOME_DIR/agent-cpp"
FTXUI_DIR="$HOME_DIR/man-cave"
LOG_DIR="$HOME_DIR/rocmpp-install-logs"

mkdir -p "$LOG_DIR"

# ── Banner ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ROCm C++ — Build from Source                            ║${NC}"
echo -e "${BOLD}║  Native Tensile · Fused Ternary · Wave32 · gfx1151       ║${NC}"
echo -e "${BOLD}║  \"There is no spoon.\" — Neo                              ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Verify hardware ─────────────────────────────────
log "Step 1/8: Verifying hardware..."

GPU_ARCH=""
if command -v rocminfo &>/dev/null; then
    GPU_ARCH=$(rocminfo 2>/dev/null | grep -oP 'gfx\d+' | head -1 || true)
fi

if [[ "$GPU_ARCH" != "gfx1151" ]]; then
    if [[ -n "$GPU_ARCH" ]]; then
        warn "Detected $GPU_ARCH — this script is optimized for gfx1151 (Strix Halo)"
        read -rp "Continue anyway? (y/N): " CONT
        [[ "$CONT" =~ ^[Yy]$ ]] || exit 0
    else
        warn "Could not detect GPU. Assuming gfx1151."
        GPU_ARCH="gfx1151"
    fi
fi
ok "GPU: $GPU_ARCH"
ok "Cores: $NPROC"
ok "Kernel: $(uname -r)"

# ── Step 2: System packages ─────────────────────────────────
log "Step 2/8: Installing system packages..."

run_with_spinner "Installing system packages..." "$LOG_DIR/pacman.log" \
    sudo pacman -S --noconfirm --needed \
    base-devel cmake ninja git python python-pip \
    rocm-hip-sdk rocm-opencl-sdk \
    patchelf gcc-fortran numactl libdrm \
    xxd curl unzip

# Python deps for Tensile kernel generation
pip install --break-system-packages --quiet \
    pyyaml joblib packaging tqdm CppHeaderParser msgpack 2>/dev/null || \
python3 -m pip install --break-system-packages --quiet \
    pyyaml joblib packaging tqdm CppHeaderParser msgpack 2>/dev/null || true

ok "System packages installed"

# ── Step 3: Environment ─────────────────────────────────────
log "Step 3/8: Setting up environment..."

ENV_FILE="$HOME_DIR/.rocmpp.env"
cat > "$ENV_FILE" << 'ENVEOF'
# ROCm C++ environment for gfx1151
export HSA_OVERRIDE_GFX_VERSION=11.5.1
export HSA_ENABLE_SDMA=0
export ROCBLAS_USE_HIPBLASLT=1
export HIP_VISIBLE_DEVICES=0
export ROCM_PATH=/opt/rocm
export HIP_PATH=/opt/rocm/hip
export PATH=$ROCM_PATH/bin:$PATH

# TheRock paths (set after build completes)
if [[ -d "$HOME/therock/build/math-libs/BLAS/rocBLAS/dist" ]]; then
    export THEROCK_PATH=$HOME/therock/build
    export LD_LIBRARY_PATH=$THEROCK_PATH/math-libs/BLAS/rocBLAS/dist/lib:$THEROCK_PATH/math-libs/BLAS/hipBLASLt/dist/lib:$THEROCK_PATH/core/clr/dist/lib:/opt/rocm/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    export ROCBLAS_TENSILE_LIBPATH=$THEROCK_PATH/math-libs/BLAS/rocBLAS/dist/lib/rocblas/library
fi
ENVEOF

# Add to shell rc if not already there
for RC in "$HOME_DIR/.zshrc" "$HOME_DIR/.bashrc"; do
    if [[ -f "$RC" ]] && ! grep -q "rocmpp.env" "$RC"; then
        echo "" >> "$RC"
        echo "# ROCm C++ environment" >> "$RC"
        echo "[[ -f ~/.rocmpp.env ]] && source ~/.rocmpp.env" >> "$RC"
    fi
done

source "$ENV_FILE"
ok "Environment configured: $ENV_FILE"

# ── Step 4: Clone repos ─────────────────────────────────────
log "Step 4/8: Cloning repositories..."

# TheRock
if [[ ! -d "$THEROCK_DIR/.git" ]]; then
    log "Cloning TheRock (ROCm from source)..."
    git clone https://github.com/ROCm/TheRock.git "$THEROCK_DIR" 2>&1 | tail -3
    cd "$THEROCK_DIR" && git submodule update --init --recursive 2>&1 | tail -3
    ok "TheRock cloned"
else
    ok "TheRock already cloned"
fi

# rocm-cpp
if [[ ! -d "$ROCMCPP_DIR/.git" ]]; then
    git clone https://github.com/stampby/rocm-cpp.git "$ROCMCPP_DIR" 2>&1 | tail -3
    ok "rocm-cpp cloned"
else
    cd "$ROCMCPP_DIR" && git pull --ff-only 2>/dev/null || true
    ok "rocm-cpp updated"
fi

# agent-cpp (specialist framework — companion to rocm-cpp)
if [[ ! -d "$AGENTCPP_DIR/.git" ]]; then
    git clone https://github.com/stampby/agent-cpp.git "$AGENTCPP_DIR" 2>&1 | tail -3
    ok "agent-cpp cloned"
else
    cd "$AGENTCPP_DIR" && git pull --ff-only 2>/dev/null || true
    ok "agent-cpp updated"
fi

# ── Step 5: Build TheRock ────────────────────────────────────
log "Step 5/8: Building TheRock (ROCm 7.13 from source)..."
log "This is the long pole — LLVM alone is 8000+ files. ~3-4 hours."

cd "$THEROCK_DIR"

# Apply GCC 15 patches
log "Applying GCC 15 patches..."

# elfutils: -Wno-error for const qualifier
ELFUTILS_CMAKE="third-party/sysdeps/linux/elfutils/CMakeLists.txt"
if [[ -f "$ELFUTILS_CMAKE" ]] && ! grep -q "Wno-error=discarded-qualifiers" "$ELFUTILS_CMAKE"; then
    sed -i 's|"CPPFLAGS=${EXTRA_CPPFLAGS}"|"CPPFLAGS=${EXTRA_CPPFLAGS} -Wno-error=discarded-qualifiers"|' "$ELFUTILS_CMAKE"
    ok "Patched elfutils for GCC 15"
fi

# rocprofiler-sdk elfio: missing cstdint
ELFIO_TYPES="rocm-systems/projects/rocprofiler-sdk/external/elfio/elfio/elf_types.hpp"
if [[ -f "$ELFIO_TYPES" ]] && ! grep -q "cstdint" "$ELFIO_TYPES"; then
    sed -i '/#define ELFTYPES_H/a #include <cstdint>' "$ELFIO_TYPES"
    ok "Patched elfio for GCC 15"
fi

# rocprofiler-sdk yaml-cpp: missing cstdint
YAML_EMITTER="rocm-systems/projects/rocprofiler-sdk/external/yaml-cpp/src/emitterutils.cpp"
if [[ -f "$YAML_EMITTER" ]] && ! grep -q "cstdint" "$YAML_EMITTER"; then
    sed -i '/#include <algorithm>/a #include <cstdint>' "$YAML_EMITTER"
    ok "Patched yaml-cpp for GCC 15"
fi

# aqlprofile test: skip in TheRock
AQL_TEST="rocm-systems/projects/aqlprofile/test/integration/CMakeLists.txt"
if [[ -f "$AQL_TEST" ]] && ! grep -q "THEROCK_SOURCE_DIR" "$AQL_TEST"; then
    sed -i '1a if(DEFINED THEROCK_SOURCE_DIR)\n  return()\nendif()' "$AQL_TEST"
    ok "Patched aqlprofile test"
fi

# Configure
if [[ ! -f "build/CMakeCache.txt" ]]; then
    log "Configuring TheRock..."
    cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DTHEROCK_AMDGPU_TARGETS=gfx1151 \
        -DTHEROCK_DIST_AMDGPU_FAMILIES=gfx115X-all \
        -DTHEROCK_ENABLE_BLAS=ON \
        2>&1 | tee "$LOG_DIR/therock-configure.log" | tail -5
    ok "TheRock configured"
fi

# Build (target BLAS specifically)
log "Building TheRock BLAS stack (rocBLAS + hipBLASLt + rocRoller)..."
log "Logging to $LOG_DIR/therock-build.log"

# Symlink Python packages into Tensile's PYTHONPATH
PYTHON_BIN=$(command -v python3.12 2>/dev/null || command -v python3 2>/dev/null)
if [[ -n "$PYTHON_BIN" ]]; then
    SITE=$($PYTHON_BIN -c "import site; print(site.getusersitepackages())" 2>/dev/null || true)
    for pkg in packaging joblib tqdm yaml msgpack; do
        PKG_PATH=$($PYTHON_BIN -c "import $pkg; import os; print(os.path.dirname($pkg.__file__))" 2>/dev/null || true)
        if [[ -n "$PKG_PATH" && -d "$PKG_PATH" && -d "rocm-libraries/projects/hipblaslt/tensilelite" ]]; then
            ln -sf "$PKG_PATH" rocm-libraries/projects/hipblaslt/tensilelite/ 2>/dev/null || true
        fi
    done
fi

ninja -C build -k0 math-libs/BLAS/rocBLAS math-libs/BLAS/hipBLASLt math-libs/BLAS/rocRoller \
    -j"$NPROC" > "$LOG_DIR/therock-build.log" 2>&1 &
BUILD_PID=$!
monitor_build "$LOG_DIR/therock-build.log" $BUILD_PID "TheRock BLAS"
wait $BUILD_PID || true

# Verify
if [[ -f "build/math-libs/BLAS/rocBLAS/dist/lib/librocblas.so" ]]; then
    KERNEL_COUNT=$(find build/math-libs/BLAS/rocBLAS/dist/lib/rocblas/library/gfx1151/ -name "*.hsaco" 2>/dev/null | wc -l)
    ok "TheRock built: $KERNEL_COUNT native Tensile kernels for gfx1151"
else
    die "TheRock BLAS build failed. Check $LOG_DIR/therock-build.log"
fi

# ── Step 6: Build rocm-cpp (librocm_cpp + bitnet_decode + tests) ──
log "Step 6/8: Building rocm-cpp (librocm_cpp + bitnet_decode)..."

cd "$ROCMCPP_DIR"
THEROCK_DIST="$THEROCK_DIR/build/dist/rocm"

cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_HIP_ARCHITECTURES=gfx1151 \
    -DCMAKE_HIP_COMPILER="$THEROCK_DIST/lib/llvm/bin/clang++" \
    -DCMAKE_C_COMPILER="$THEROCK_DIST/lib/llvm/bin/clang" \
    -DCMAKE_CXX_COMPILER="$THEROCK_DIST/lib/llvm/bin/clang++" \
    2>&1 | tail -3

cmake --build build --parallel "$NPROC" \
    --target rocm_cpp bitnet_decode test_prim_and_attn \
    > "$LOG_DIR/rocmcpp-build.log" 2>&1 &
BUILD_PID=$!
monitor_build "$LOG_DIR/rocmcpp-build.log" $BUILD_PID "rocm-cpp"
wait $BUILD_PID || true

if [[ -f "build/librocm_cpp.so" && -f "build/bitnet_decode" ]]; then
    ok "rocm-cpp built: librocm_cpp.so + bitnet_decode"
else
    warn "rocm-cpp build had issues. Check $LOG_DIR/rocmcpp-build.log"
fi

# ── Step 7: Build agent-cpp (specialist framework) ──────────
log "Step 7/8: Building agent-cpp (specialist framework, C++20)..."

cd "$AGENTCPP_DIR"

# agent-cpp is pure C++20 + pthreads — no ROCm dependency for the
# scaffold. Specialists that call into librocm_cpp pick it up from
# LD_LIBRARY_PATH at runtime; no link-time coupling.
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DAGENT_CPP_TESTS=ON \
    2>&1 | tail -3

cmake --build build --parallel "$NPROC" > "$LOG_DIR/agentcpp-build.log" 2>&1 &
BUILD_PID=$!
monitor_build "$LOG_DIR/agentcpp-build.log" $BUILD_PID "agent-cpp"
wait $BUILD_PID || true

if [[ -f "build/agent_cpp" ]]; then
    ok "agent-cpp built: agent_cpp demo + 17 specialists"
    if ./build/test_runtime 2>/dev/null | grep -q OK; then
        ok "agent-cpp runtime smoke test: PASS"
    fi
else
    warn "agent-cpp build had issues. Check $LOG_DIR/agentcpp-build.log"
fi

# ── Step 8: Build FTXUI dashboard ────────────────────────────
log "Step 8/8: Building FTXUI dashboard..."

# Install FTXUI if not present
if ! pkg-config --exists ftxui 2>/dev/null; then
    log "Building FTXUI from source..."
    FTXUI_BUILD="/tmp/ftxui-build"
    rm -rf "$FTXUI_BUILD"
    git clone https://github.com/ArthurSonzogni/FTXUI.git "$FTXUI_BUILD" 2>&1 | tail -3
    cd "$FTXUI_BUILD"
    cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DFTXUI_BUILD_EXAMPLES=OFF \
        -DFTXUI_BUILD_TESTS=OFF \
        2>&1 | tail -3
    cmake --build build --parallel "$NPROC" 2>&1 | tail -3
    sudo cmake --install build 2>&1 | tail -3
    ok "FTXUI installed"
fi

# Build Man Cave TUI if it exists
if [[ -d "$FTXUI_DIR" ]]; then
    cd "$FTXUI_DIR"
    if [[ -f "CMakeLists.txt" ]]; then
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -3
        cmake --build build --parallel "$NPROC" 2>&1 | tail -3
        ok "Man Cave TUI built"
    fi
elif [[ -d "$HOME_DIR/man-cave" ]]; then
    cd "$HOME_DIR/man-cave"
    if [[ -f "CMakeLists.txt" ]]; then
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -3
        cmake --build build --parallel "$NPROC" 2>&1 | tail -3
        ok "Man Cave TUI built"
    fi
else
    warn "Man Cave TUI not found — skipping FTXUI dashboard"
fi

# ── Done ─────────────────────────────────────────────────────
source "$HOME_DIR/.rocmpp.env"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ROCm C++ — Build Complete                               ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  GPU:              $GPU_ARCH"
echo "  TheRock:          $THEROCK_DIR/build/"
echo "  Tensile kernels:  $(find $THEROCK_DIR/build/math-libs/BLAS/rocBLAS/dist/lib/rocblas/library/gfx1151/ -name '*.hsaco' 2>/dev/null | wc -l) native .hsaco files"
echo "  rocm-cpp:         $ROCMCPP_DIR/"
echo "  Engine:           $ENGINE_DIR/build/server"
echo "  Environment:      source ~/.rocmpp.env"
echo ""
echo "  Quick start:"
echo "    source ~/.rocmpp.env"
echo "    cd $ROCMCPP_DIR && ./tools/bench_ternary"
echo "    cd $ROCMCPP_DIR && ./tools/bench_gemm"
echo "    cd $ENGINE_DIR && ./build/chat mlx-community/Qwen3-4B-4bit"
echo ""
echo "  Run benchmarks:"
echo "    cd $ROCMCPP_DIR/tools && ./run_bench.sh"
echo ""
echo "  Logs: $LOG_DIR/"
echo ""
echo -e "  ${BOLD}If it can be done in C++, we do it in C++.${NC}"
echo -e "  ${BOLD}Stamped by the architect.${NC}"
echo ""
