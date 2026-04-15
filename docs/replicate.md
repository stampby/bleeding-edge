# How to Replicate These Benchmarks

> *Don't take our word for it. Run it yourself.*

This document contains everything you need to reproduce the MLX vs vLLM vs Vulkan benchmarks on Strix Halo from scratch.

---

## What You Need

### Hardware
- AMD Strix Halo (gfx1151) — any Ryzen AI MAX+ PRO 300 series
  - Bosgame M5, ASUS NUC 14 Pro AI, or any gfx1151 system
  - 64GB or 128GB unified memory
- Also works on: gfx1150 (Strix Point), gfx110X (RDNA3), gfx120X (RDNA4)

### Software
- Linux kernel 6.18.4+ (CWSR fix required)
- `curl`, `unzip`, `python3`, `gh` (GitHub CLI)
- ~50GB free disk space (models + binaries)

### Time
- MLX pre-built setup: 5 minutes
- Full benchmark run: ~30 minutes
- vLLM comparison (optional): ~2 hours (includes Triton JIT)

---

## Step 1: Verify Your GPU

```bash
# Check GPU architecture
lspci | grep -i display
# Should show: AMD Radeon 8060S or similar

# Check kernel
uname -r
# Must be 6.18.4+ or 7.0+

# Check CWSR (required for GPU dispatch)
grep -E "cwsr_size|ctl_stack_size" /sys/class/kfd/kfd/topology/nodes/*/properties
# Should show values for your GPU node
```

---

## Step 2: Install MLX Engine

```bash
mkdir -p ~/mlx-engine && cd ~/mlx-engine

# Download pre-built binary for your GPU
# gfx1151 = Strix Halo
# gfx1150 = Strix Point
# gfx110X = RDNA3 (RX 7000)
# gfx120X = RDNA4 (RX 9000)

GPU_TARGET=gfx1151  # Change this for your GPU

gh release download b1004-tech-preview \
  -R lemonade-sdk/lemon-mlx-engine \
  -p "mlx-engine-b1004-tech-preview-ubuntu-rocm-tech-preview-${GPU_TARGET}-x64.zip"

unzip mlx-engine-*-${GPU_TARGET}-x64.zip -d .
chmod +x chat server diagnose

# Verify GPU operations
LD_LIBRARY_PATH=. ./diagnose mlx-community/Qwen3-1.7B-4bit
```

If diagnose passes, you're good. If it fails, check your kernel version and GPU.

---

## Step 3: Run the Benchmark

### The Benchmark Script

Save this as `bench.py`:

```python
#!/usr/bin/env python3 -u
"""MLX Engine benchmark — reproduces the halo-ai bleeding-edge results."""
import requests, time, json, statistics, sys
sys.stdout.reconfigure(line_buffering=True)

BASE = "http://localhost:8090"
RUNS = 5
WARMUP = 2
MAX_TOKENS = 200
PROMPT = [{"role": "user", "content": "Write a Python function that checks if a number is prime and explain your approach step by step."}]
WARMUP_PROMPT = [{"role": "user", "content": "What is 2+2? Reply in one sentence."}]

MODELS = [
    "mlx-community/Qwen3-0.6B-4bit",
    "mlx-community/Qwen3-1.7B-4bit",
    "mlx-community/Qwen3-4B-4bit",
    "mlx-community/Qwen3-8B-4bit",
    "mlx-community/Phi-4-mini-instruct-4bit",
    "mlx-community/Qwen3-Coder-Next-4bit",
]

def bench(model, messages, max_tokens):
    start = time.time()
    r = requests.post(f"{BASE}/v1/chat/completions", json={
        "model": model, "messages": messages,
        "max_tokens": max_tokens, "temperature": 0,
    }, timeout=600)
    elapsed = time.time() - start
    if r.status_code != 200:
        return None
    comp = r.json().get("usage", {}).get("completion_tokens", 0)
    return comp / elapsed if elapsed > 0 and comp > 0 else None

print(f"{'Model':<35} {'Mean tok/s':>10} {'±StdDev':>8} {'Min':>6} {'Max':>6}")
print("-" * 70)

for model in MODELS:
    name = model.split("/")[-1]
    # Warmup
    for _ in range(WARMUP):
        bench(model, WARMUP_PROMPT, 20)
        time.sleep(1)
    # Benchmark
    rates = []
    for i in range(RUNS):
        tps = bench(model, PROMPT, MAX_TOKENS)
        if tps:
            rates.append(tps)
        time.sleep(1)
    if rates:
        mean = statistics.mean(rates)
        std = statistics.stdev(rates) if len(rates) > 1 else 0
        print(f"{name:<35} {mean:>10.1f} {std:>7.1f} {min(rates):>6.1f} {max(rates):>6.1f}")
    else:
        print(f"{name:<35} {'FAIL':>10}")
```

### Run It

```bash
# Terminal 1: Start the server
cd ~/mlx-engine
LD_LIBRARY_PATH=. ./server --port 8090

# Terminal 2: Run the benchmark
python3 bench.py
```

First run downloads models from HuggingFace (~15GB total). Subsequent runs use cache.

### Expected Results (Strix Halo gfx1151, 128GB)

```
Model                              Mean tok/s  ±StdDev    Min    Max
----------------------------------------------------------------------
Qwen3-0.6B-4bit                       151.2      0.1  151.0  151.3
Qwen3-1.7B-4bit                        66.4      0.0   66.3   66.4
Qwen3-4B-4bit                          46.9      0.0   46.9   46.9
Qwen3-8B-4bit                          21.7      0.0   21.7   21.7
Phi-4-mini-instruct-4bit               38.3      0.0   38.1   38.3
Qwen3-Coder-Next-4bit                  26.7      0.0   26.7   26.7
```

Your numbers may vary ±5% depending on thermal state and memory configuration.

---

## Step 4: Compare with vLLM (Optional)

To reproduce the vLLM comparison, follow the [Lemonade PR #1537](https://github.com/lemonade-sdk/lemonade/pull/1537) test plan:

```bash
# Clone and build Lemonade from the test-vllm branch
git clone https://github.com/lemonade-sdk/lemonade.git
cd lemonade
git checkout test-vllm
./setup.sh
cmake --build --preset default -j$(nproc)

# Start server
./build/lemond --port 8083

# Install vLLM ROCm backend
curl -s -X POST http://localhost:8083/v1/install \
  -H "Content-Type: application/json" \
  -d '{"recipe": "vllm", "backend": "rocm"}'

# Load and test a model
curl -s -X POST http://localhost:8083/v1/load \
  -H "Content-Type: application/json" \
  -d '{"model_name": "Qwen3-0.6B-vllm"}'

curl -s -X POST http://localhost:8083/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-0.6B-vllm","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":30}'
```

---

## Step 5: Compare with Vulkan llamacpp (Optional)

If you have Lemonade SDK installed:

```bash
# Load model via Vulkan backend
lemonade load Qwen3-0.6B-GGUF --llamacpp-backend vulkan

# Benchmark via completions API
curl -s http://localhost:13305/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-0.6B-GGUF", "prompt": "Write a prime checker", "max_tokens": 200, "temperature": 0}'
```

---

## Methodology

All benchmarks in this repository follow the same protocol:

- **Runs:** 5 per model
- **Warmup:** 2 runs discarded
- **Max tokens:** 200
- **Temperature:** 0 (deterministic)
- **Prompt:** "Write a Python function that checks if a number is prime and explain your approach step by step."
- **Measurement:** Wall-clock time (request → response), `completion_tokens / elapsed_seconds`
- **Reported:** Mean ± sample standard deviation

---

## Reporting Your Results

If you run these benchmarks on different hardware, we'd love to see your numbers. Open an issue on this repo with:

1. GPU model and architecture (gfx1151, gfx1150, etc.)
2. Memory (64GB, 128GB, etc.)
3. Kernel version
4. Your benchmark output

We'll add it to the comparison table.

---

*Designed and built by the architect.*
