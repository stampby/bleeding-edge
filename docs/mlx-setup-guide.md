# MLX Engine on AMD Strix Halo — Setup from Scratch

> *"Little bones, little bones, everywhere I go" — Gord Downie*

No bullshit. Every command. Every dependency. Every gotcha. Tested on CachyOS (Arch) with kernel 7.0.0-1-mainline on Ryzen AI MAX+ PRO 395 / Radeon 8060S (gfx1151) with 128GB unified memory.

---

## What This Is

[lemon-mlx-engine](https://github.com/lemonade-sdk/lemon-mlx-engine) is a pure C++ inference engine built on Apple's MLX framework, ported to AMD GPUs via ROCm. No Python. No Triton. No GGUF conversion. Point it at a HuggingFace model ID and it runs.

On Strix Halo gfx1151, MLX is **29-85% faster** than vLLM ROCm across all tested models.

---

## Prerequisites

### Hardware
- AMD Strix Halo (gfx1151) with unified memory
- Works on: gfx1150 (Strix Point), gfx110X (RDNA3), gfx120X (RDNA4)

### Kernel
- Linux 6.18.4+ required (CWSR fix for GPU dispatch)
- Tested: CachyOS kernel 7.0.0-1-mainline
- Check: `uname -r`

### System ROCm
- System ROCm 7.2.1 from Arch packages is fine — **do not upgrade it**
- The MLX pre-built binary bundles what it needs
- Check: `pacman -Q rocm-hip-sdk`

---

## Option A: Pre-built Binary (Recommended)

The fastest path. Pre-built for your exact GPU. No compilation.

### 1. Download the binary

```bash
mkdir -p ~/mlx-engine && cd ~/mlx-engine

# For gfx1151 (Strix Halo)
gh release download b1004-tech-preview \
  -R lemonade-sdk/lemon-mlx-engine \
  -p 'mlx-engine-b1004-tech-preview-ubuntu-rocm-tech-preview-gfx1151-x64.zip'

# For other GPUs, replace gfx1151 with:
#   gfx1150  — Strix Point
#   gfx110X  — RDNA3 (RX 7000 series)
#   gfx120X  — RDNA4 (RX 9000 series)
```

### 2. Extract

```bash
unzip mlx-engine-*-gfx1151-x64.zip -d .
chmod +x chat server diagnose
```

You should have:
```
chat        — Interactive chat CLI
server      — OpenAI-compatible API server
diagnose    — GPU diagnostic tool
libgfortran.so.5
liblapacke.so.3
libopenblas.so
```

### 3. Verify GPU operations

```bash
LD_LIBRARY_PATH=. ./diagnose mlx-community/Qwen3-1.7B-4bit
```

This downloads the model (~1GB) and tests:
- Basic GPU matmul
- bf16 matmul via hipBLASLt
- Quantized matmul
- RMS normalization
- RoPE
- Forward pass
- End-to-end token generation

Expected output:
```
=== INFERENCE PIPELINE DIAGNOSTICS ===
Loading model: mlx-community/Qwen3-1.7B-4bit
Model loaded.

--- TEST 1: Basic GPU ops ---
[DIAG] matmul(ones, 2*ones) expect=8       shape=(4,4) min=8.000000 max=8.000000
[hipBLASLt] first call
[DIAG] bf16 matmul expect=8                shape=(4,4) min=8.000000 max=8.000000
```

If this works, your GPU and ROCm are good.

### 4. Interactive chat

```bash
LD_LIBRARY_PATH=. ./chat mlx-community/Qwen3-4B-4bit
```

Models auto-download from HuggingFace on first use. Type your message at the `>` prompt. Type `quit` to exit.

Useful flags:
```bash
# Disable thinking/reasoning (Qwen3 models)
./chat mlx-community/Qwen3-8B-4bit --no-think

# System prompt
./chat mlx-community/Qwen3-4B-4bit --system-prompt "You are a helpful coding assistant"

# KV cache quantization to save memory for large models
./chat mlx-community/Qwen3.5-32B-4bit --kv-bits 4

# More tokens
./chat mlx-community/Qwen3-8B-4bit --max-tokens 4096
```

### 5. API server

```bash
# Start the server
LD_LIBRARY_PATH=. ./server --port 8090

# Or pre-load a model
LD_LIBRARY_PATH=. ./server mlx-community/Qwen3-4B-4bit --port 8090
```

Test it:
```bash
# Health check
curl http://localhost:8090/health

# List cached models
curl http://localhost:8090/v1/models

# Chat completion (auto-loads model on first request)
curl http://localhost:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mlx-community/Qwen3-4B-4bit",
    "messages": [{"role": "user", "content": "What is 2+2?"}],
    "max_tokens": 100
  }'
```

The server is OpenAI-compatible. Any tool that talks to OpenAI talks to this.

### 6. Run as a systemd service

```bash
# Create service file
sudo tee /etc/systemd/system/mlx-engine.service << 'EOF'
[Unit]
Description=MLX Engine — C++ LLM Inference (ROCm)
After=network.target

[Service]
Type=simple
User=bcloud
WorkingDirectory=/home/bcloud/mlx-engine
Environment=LD_LIBRARY_PATH=/home/bcloud/mlx-engine
ExecStart=/home/bcloud/mlx-engine/server --port 8090 --host 127.0.0.1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now mlx-engine.service
systemctl status mlx-engine.service
```

---

## Option B: Build from Source

For when you want to modify the engine or build with a specific ROCm version.

### The Problem

Building on Arch/CachyOS with system ROCm 7.2.1 fails because:
1. **rocwmma** doesn't support gfx1151 (needs ROCm 7.12+)
2. **GCC 15** has a `std::optional` constraint regression

### The Solution: TheROCk Nightly Tarball

TheROCk provides ROCm 7.12 as a standalone tarball. Install it alongside system ROCm without replacing anything.

#### 1. Download TheROCk 7.12 for gfx1151

```bash
# Find latest tarball
curl -s "https://therock-nightly-tarball.s3.amazonaws.com/?prefix=therock-dist-linux-gfx1151-7.12" \
  | grep -oP 'therock-dist-linux-gfx1151-[^<]+\.tar\.gz' \
  | sort -V | tail -1

# Download and extract (adjust filename to latest)
sudo mkdir -p /opt/rocm-7.12-gfx1151
curl -sL "https://therock-nightly-tarball.s3.amazonaws.com/therock-dist-linux-gfx1151-7.12.0a20260311.tar.gz" \
  | sudo tar xzf - -C /opt/rocm-7.12-gfx1151 --strip-components=1

# Verify
ls /opt/rocm-7.12-gfx1151/lib/cmake/hip/
```

#### 2. Install build dependencies

```bash
# Arch/CachyOS
sudo pacman -S --needed cmake ninja rust libcurl-compat openssl zlib
```

#### 3. Clone and build

```bash
git clone https://github.com/lemonade-sdk/lemon-mlx-engine.git
cd lemon-mlx-engine
git checkout b1004-tech-preview

mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DMLX_BUILD_ROCM=ON \
  -DCMAKE_PREFIX_PATH=/opt/rocm-7.12-gfx1151 \
  -DCMAKE_HIP_ARCHITECTURES=gfx1151 \
  -G Ninja

ninja -j$(nproc)
```

#### 4. Verify

```bash
ls chat server diagnose
./diagnose mlx-community/Qwen3-1.7B-4bit
```

### Alternative: Podman Container Build

If native build fights you, build in Ubuntu 24.04:

```bash
podman run --rm \
  -v $(pwd):/src:Z \
  -v /tmp/mlx-output:/output:Z \
  ubuntu:24.04 bash -c '
    apt-get update && apt-get install -y cmake ninja-build git curl libcurl4-openssl-dev \
      libssl-dev pkg-config build-essential wget gnupg2 libopenblas-dev
    curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    # Install ROCm from TheRock (not AMD apt — broken rocwmma)
    # ... (download TheRock tarball as above)
    cd /src && mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DMLX_BUILD_ROCM=ON \
      -DCMAKE_PREFIX_PATH=/opt/rocm -DCMAKE_HIP_ARCHITECTURES=gfx1151 -G Ninja
    ninja -j$(nproc)
    cp chat server diagnose /output/
  '
```

---

## Available Models

Models auto-download from HuggingFace. Use the `mlx-community/` prefix.

### Tested on Strix Halo gfx1151

| Model | Size | tok/s | Status |
|-------|------|-------|--------|
| Qwen3-0.6B-4bit | ~0.4GB | 150.9 | PASS |
| Qwen3-1.7B-4bit | ~1.0GB | 66.3 | PASS |
| Qwen3-4B-4bit | ~2.3GB | 46.9 | PASS |
| Qwen3-8B-4bit | ~4.7GB | 21.7 | PASS |
| Phi-4-mini-instruct-4bit | ~2.2GB | 38.1 | PASS |

### Large Models (128GB unified)

```
mlx-community/Qwen3-Coder-Next-4bit      — Latest coding model
mlx-community/Qwen3.5-32B-4bit           — 32B dense
mlx-community/Qwen2.5-72B-Instruct-4bit  — 72B dense
mlx-community/Qwen3.5-122B-A10B-4bit     — 122B MoE
mlx-community/DeepSeek-V3-4bit           — 105B (67B active)
```

### 1-bit Models

```
mlx-community/bitnet-b1.58-2B-4T                — Ternary 1.58-bit
mlx-community/Falcon-E-3B-Instruct-1.58bit      — Extreme quantization
```

### Day-one Access

Any model on `mlx-community` works. When a new model drops on HuggingFace:

```bash
# No GGUF conversion. No waiting. Just run it.
./chat mlx-community/NEW-MODEL-4bit
```

---

## Architecture Notes

### Why MLX is Faster than vLLM on Strix Halo

| | MLX Engine | vLLM ROCm |
|---|---|---|
| Language | C++ | Python + C++ |
| Kernel compilation | Pre-compiled HIP | Triton JIT (20-350s first run) |
| Cold start | Seconds | Minutes |
| Memory model | Unified-native (MLX designed for it) | Adapted from discrete GPU |
| Dependencies | None (static binary) | Python 3.12, torch, triton, etc. |
| Model format | HuggingFace safetensors | HuggingFace safetensors |

### What MLX Doesn't Have (Yet)

- Continuous batching (vLLM's strength for multi-user serving)
- PagedAttention (vLLM's memory optimization for concurrent requests)
- Prefix caching across requests

For single-user/low-concurrency inference: **MLX wins.**
For multi-user production serving: **vLLM wins.**

---

## Gotchas

1. **LD_LIBRARY_PATH** — The pre-built binary needs its bundled libs. Always run with `LD_LIBRARY_PATH=.` or set it in the systemd service.

2. **Model architecture support** — Tech preview. Llama-3.2 and Gemma-3 had reshape errors. Qwen3, Qwen3.5, and Phi work.

3. **First model download** — Models download from HuggingFace on first use. A 4B model is ~2.3GB. Budget download time on first run.

4. **Thinking tokens** — Qwen3 models generate `<think>` reasoning tokens. Use `--no-think` to disable if you want direct answers.

5. **System ROCm** — Don't upgrade system ROCm to match the binary. The pre-built has everything it needs. System ROCm 7.2.1 is fine.

---

## Performance Reference

### MLX vs vLLM vs Vulkan llamacpp — Same Hardware

```
Backend Progression on Strix Halo gfx1151 (Qwen3-0.6B):

  Vulkan llamacpp    82.5 tok/s   ████████████████████░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ████████████████████████████░░░
  MLX ROCm          150.9 tok/s   ██████████████████████████████▌

  +83% improvement from Vulkan to MLX. Same chip. Same desk. Same day.
```

---

*Designed and built by the architect.*
*Stamped.*
