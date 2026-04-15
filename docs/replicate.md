# How to Replicate These Benchmarks

> *Don't take our word for it. Run it yourself.*

Everything you need to reproduce the 4-backend benchmark on Strix Halo. Glass walls — nothing hidden.

---

## What You Need

### Hardware
- AMD Strix Halo (gfx1151) — any Ryzen AI MAX+ PRO 300 series
  - Bosgame M5, ASUS NUC 14 Pro AI, or any gfx1151 system
  - 64GB or 128GB unified memory
  - NPU: RyzenAI aie2p (50 TOPS) — for FLM backend
- Also works on: gfx1150 (Strix Point), gfx110X (RDNA3), gfx120X (RDNA4)

### Software
- Arch Linux / CachyOS (or any distro with ROCm 7.2.1+)
- Kernel 7.0.0+ (required for NPU — XDNA2 driver)
- ROCm 7.2.1 (system install)
- `curl`, `unzip`, `python3`, `gh` (GitHub CLI), `bc`
- ~80GB free disk space (models + binaries + vLLM)

### Time
- Full setup (all 4 backends): ~1 hour
- Full benchmark run: ~45 minutes
- MLX only (quick test): 10 minutes

---

## Step 1: Verify Your Hardware

```bash
# GPU
rocminfo | grep "Marketing Name"
# Should show: Radeon 8060S Graphics (gfx1151)

# NPU
rocminfo | grep -A1 "aie2p"
# Should show: RyzenAI-npu5

# Kernel
uname -r
# Must be 7.0.0+ for NPU support

# ROCm
cat /opt/rocm/.info/version
# Should be 7.2.1+

# Memory
free -g | awk '/^Mem:/{print $2 "GB"}'
```

---

## Step 2: Backend 1 — MLX Engine (ROCm GPU)

MLX Engine is a pure C++ inference engine using hipBLASLt on ROCm. No Python. HuggingFace models load directly — no GGUF conversion.

```bash
mkdir -p ~/mlx-engine && cd ~/mlx-engine

# Download pre-built binary for your GPU
GPU_TARGET=gfx1151  # change for your GPU

gh release download b1004-tech-preview \
  -R lemonade-sdk/lemon-mlx-engine \
  -p "mlx-engine-b1004-tech-preview-ubuntu-rocm-tech-preview-${GPU_TARGET}-x64.zip"

unzip mlx-engine-*-${GPU_TARGET}-x64.zip -d .
chmod +x chat server diagnose

# Verify GPU operations pass
LD_LIBRARY_PATH=.:/opt/rocm/lib ./diagnose mlx-community/Qwen3-1.7B-4bit

# Start the server (port 8080)
LD_LIBRARY_PATH=.:/opt/rocm/lib ./server --host 0.0.0.0 --port 8080

# Test — models auto-download from HuggingFace on first use
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"mlx-community/Qwen3-4B-4bit","messages":[{"role":"user","content":"Hello"}],"max_tokens":32}'
```

**Available models (auto-download):**
- `mlx-community/Qwen3-0.6B-4bit` (0.4 GB)
- `mlx-community/Qwen3-1.7B-4bit` (1.1 GB)
- `mlx-community/Qwen3-4B-4bit` (2.6 GB)
- `mlx-community/Qwen3-8B-4bit` (5.0 GB)
- `mlx-community/Phi-4-mini-instruct-4bit` (2.5 GB)

---

## Step 3: Backend 2 — vLLM (ROCm GPU)

vLLM is a production LLM server with PagedAttention and continuous batching. Runs through lemond (Lemonade SDK daemon).

```bash
# Clone and build Lemonade from the test-vllm branch
git clone https://github.com/lemonade-sdk/lemonade.git
cd lemonade
git fetch origin test-vllm
git checkout test-vllm

# Build lemond
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j$(nproc) --target lemond
cd ..

# Start lemond (port 13399)
./build/lemond --host 0.0.0.0 --port 13399

# Verify vLLM models are available
curl -s http://localhost:13399/v1/models | python3 -m json.tool | grep vllm

# Test — first load takes 1-2 minutes (Triton JIT compilation)
curl -X POST http://localhost:13399/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-0.6B-vllm","messages":[{"role":"user","content":"Hello"}],"max_tokens":32}'
```

**Available vLLM models (14 total):**
- `Qwen3-0.6B-vllm`, `Qwen3-1.7B-vllm`, `Qwen3-4B-AWQ-vllm`, `Qwen3-8B-AWQ-vllm`
- `Phi-4-mini-instruct-vllm`, `Llama-3.2-1B-Instruct-vllm`, `Llama-3.2-3B-Instruct-vllm`
- `Qwen3.5-0.8B-vllm`, `Qwen3.5-2B-vllm`, `Qwen3.5-4B-vllm`, `Qwen3.5-9B-vllm`
- `Gemma-3-4b-it-vllm`, `Qwen3-4B-vllm`, `Qwen3-8B-vllm`

**Note:** vLLM through lemond also provides FLM (NPU) models simultaneously.

---

## Step 4: Backend 3 — Prism llama.cpp (Vulkan 1-bit)

Prism is a llama.cpp fork that supports TQ1_0 (1-bit ternary) quantization. Runs on Vulkan — no ROCm required.

```bash
mkdir -p ~/prism-llamacpp && cd ~/prism-llamacpp

# Download pre-built Prism binary
gh release download prism-b8796-e2d6742 \
  -R PrismML-Eng/llama.cpp \
  -p '*ubuntu-vulkan*'

tar xzf llama-prism-*-vulkan-x64.tar.gz

# Download 1-bit model
pip install huggingface-hub
huggingface-cli download Qwen/Qwen3-Coder-Next-UD --include "*.gguf" \
  --local-dir ~/models/Qwen3-Coder-Next-TQ1_0

# Start server (port 8081)
cd llama-prism-*/
./llama-server \
  --host 0.0.0.0 --port 8081 \
  --model ~/models/Qwen3-Coder-Next-TQ1_0/*.gguf \
  --ctx-size 4096 --n-gpu-layers 999

# Test
curl -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-Coder-Next","messages":[{"role":"user","content":"Hello"}],"max_tokens":32}'
```

---

## Step 5: Backend 4 — lemond/FLM (NPU)

FastFlowLM runs models on the RyzenAI NPU. Zero GPU memory used. Requires kernel 7.0+ for the XDNA2 driver.

```bash
# Install Lemonade SDK and NPU packages (Arch/CachyOS)
sudo pacman -S lemonade xrt-plugin-amdxdna fastflowlm

# Fix memlock limits for NPU (REQUIRED)
echo "$(whoami) soft memlock unlimited" | sudo tee -a /etc/security/limits.d/99-npu.conf
echo "$(whoami) hard memlock unlimited" | sudo tee -a /etc/security/limits.d/99-npu.conf
# Log out and back in for limits to apply

# Verify NPU
flm validate
# Should show: NPU with 8 columns, firmware 1.1.0.0+, memlock unlimited

# If using the test-vllm branch lemond (Step 3), it already serves FLM models too.
# Otherwise, start standalone:
lemond --host 0.0.0.0 --port 13399

# Test NPU inference
curl -X POST http://localhost:13399/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-0.6b-FLM","messages":[{"role":"user","content":"Hello"}],"max_tokens":32}'
```

**Available FLM (NPU) models:**
- `qwen3-0.6b-FLM` (0.7 GB) — 94 tok/s
- `llama3.2-1b-FLM` (1.3 GB) — 62 tok/s
- `gemma3-1b-FLM` (1.2 GB) — 39 tok/s
- `llama3.2-3b-FLM` (2.7 GB) — 25 tok/s
- `qwen3-8b-FLM` (5.6 GB) — 11 tok/s
- `whisper-v3-turbo-FLM` (0.6 GB) — ASR

---

## Step 6: Run the Standardized Benchmark

```bash
git clone https://github.com/stampby/bleeding-edge.git
cd bleeding-edge

# Start all backends (each in a separate terminal or backgrounded)
# then:
chmod +x bench.sh
./bench.sh
```

The script:
1. Auto-detects which backends are running
2. Warms up each model
3. Runs 3 rounds of 256-token generation
4. Reports mean ± stddev for each model
5. Saves results to `results/` as CSV and JSON

---

## Methodology

| Parameter | Value |
|-----------|-------|
| Generation length | 256 tokens |
| Rounds | 3 per model |
| Warmup | 1 round discarded |
| Temperature | 0.0 (deterministic) |
| Prompt | "Explain the concept of nuclear fusion..." (technical, forces reasoning) |
| Measurement | Wall-clock time, `tokens / elapsed_seconds` |
| Reported | Mean ± sample standard deviation |

---

## Expected Results (Strix Halo gfx1151, 128GB)

```
BACKEND     MODEL                    HARDWARE      TOK/S    ±STDDEV
─────────────────────────────────────────────────────────────────────
mlx         Qwen3-0.6B-4bit          GPU-ROCm      149.3    ±0.3
mlx         Qwen3-1.7B-4bit          GPU-ROCm       65.2    ±0.2
mlx         Qwen3-4B-4bit            GPU-ROCm       44.5    ±0.1
mlx         Phi-4-mini-4bit          GPU-ROCm       37.0    ±0.2
mlx         Qwen3-8B-4bit            GPU-ROCm       20.8    ±0.1
vllm        Qwen3-0.6B               GPU-ROCm      130.6    ±0.6
vllm        Qwen3-1.7B               GPU-ROCm       47.1    ±0.2
vllm        Qwen3-4B-AWQ             GPU-ROCm       41.5    ±0.1
vllm        Phi-4-mini               GPU-ROCm       24.9    ±0.0
vllm        Qwen3-8B-AWQ             GPU-ROCm       22.3    ±0.1
prism       Qwen3-Coder-Next-TQ1_0   GPU-Vulkan     65.6    ±0.8
lemond      Qwen3-0.6B-FLM           NPU-FLM        94.4    ±0.2
lemond      Llama-3.2-1B-FLM         NPU-FLM        61.7    ±0.2
lemond      Gemma3-1B-FLM            NPU-FLM        38.9    ±0.0
lemond      Llama-3.2-3B-FLM         NPU-FLM        24.9    ±0.0
lemond      Qwen3-8B-FLM             NPU-FLM        10.8    ±0.0
```

Your numbers may vary ±5% depending on thermal state and memory configuration.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| MLX diagnose fails | Check kernel 6.18.4+ and ROCm 7.2.1 |
| vLLM first load slow | Normal — Triton JIT compiles HIP kernels on first run |
| NPU `flm validate` fails | Check `ulimit -l` is unlimited, reboot after setting limits |
| MLX crashes switching models | Unload first: `curl -X POST http://localhost:8080/unload` |
| Prism no Vulkan | Install `vulkan-radeon` package |

---

## Reporting Your Results

Run these benchmarks on different hardware? Open an issue with:

1. GPU model and architecture (gfx1151, gfx1150, etc.)
2. Memory (64GB, 128GB)
3. Kernel version
4. `bench.sh` output

We'll add it to the comparison.

---

*Designed and built by the architect.*
