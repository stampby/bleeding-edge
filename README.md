<!-- "Cubically Contained" — The Headstones -->
<!-- If you found this, you're one of us. -->

# bleeding-edge

> *"Cubically Contained" — The Headstones*

The experimental branch of [halo-ai CORE](https://github.com/stampby/halo-ai-core). This is where the next generation gets tested before it ships.

**Current focus:** MLX Engine ROCm — pure C++ LLM inference on AMD Strix Halo.

---

## Why MLX

We tested three inference backends on the same hardware, same day. Same desk.

```
Backend Progression — Strix Halo gfx1151, 128GB unified

  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌

  +83% improvement from Vulkan to MLX.
```

MLX wins because it's pure C++ — no Python, no Triton JIT, no subprocess overhead. Designed for unified memory from day one (Apple Silicon → Strix Halo).

---

## Benchmarks

### MLX Engine ROCm — 5 runs, mean ± stddev, 200 tokens

| Model | tok/s | ±StdDev | Notes |
|-------|-------|---------|-------|
| Qwen3-0.6B-4bit | **151.2** | ±0.1 | Routing / triage |
| Qwen3-1.7B-4bit | **66.4** | ±0.0 | Fast general |
| Qwen3-4B-4bit | **46.9** | ±0.0 | Sweet spot |
| Phi-4-mini-instruct-4bit | **38.3** | ±0.0 | Microsoft Phi |
| Qwen3-Coder-Next-4bit | **26.7** | ±0.0 | Latest coding model |
| Qwen3-8B-4bit | **21.7** | ±0.0 | Heavy reasoning |

### Head-to-Head: MLX vs vLLM vs Vulkan

| Model | MLX | vLLM | Vulkan | MLX vs Vulkan |
|-------|-----|------|--------|---------------|
| Qwen3-0.6B | **151.2** | 116.7 | 82.5 | **+83%** |
| Qwen3-4B | **46.9** | 25.4 | — | **+85% vs vLLM** |
| Qwen3-8B | **21.7** | 12.3 | — | **+76% vs vLLM** |
| Phi-4-mini | **38.3** | 25.1 | — | **+53% vs vLLM** |

### vLLM ROCm (for comparison)

Tested via [lemonade-sdk/lemonade PR #1537](https://github.com/lemonade-sdk/lemonade/pull/1537):

| Model | tok/s | Notes |
|-------|-------|-------|
| Qwen3-0.6B (FP16) | 116.7 | |
| Llama-3.2-1B (AWQ) | 110.4 | |
| Llama-3.2-3B (AWQ) | 50.5 | |
| Qwen3-4B (AWQ) | 42.8 | |
| Qwen3-8B (AWQ) | 22.8 | |
| Qwen2.5-72B (AWQ) | 2.3 | 72B dense on 128GB unified |

---

## Quick Start

### Pre-built Binary (30 seconds)

```bash
mkdir -p ~/mlx-engine && cd ~/mlx-engine

# Download for Strix Halo (gfx1151)
gh release download b1004-tech-preview \
  -R lemonade-sdk/lemon-mlx-engine \
  -p '*gfx1151*'

unzip mlx-engine-*-gfx1151-x64.zip -d .
chmod +x chat server diagnose

# Verify GPU
LD_LIBRARY_PATH=. ./diagnose mlx-community/Qwen3-1.7B-4bit

# Chat
LD_LIBRARY_PATH=. ./chat mlx-community/Qwen3-4B-4bit

# API server
LD_LIBRARY_PATH=. ./server --port 8090
```

Models auto-download from HuggingFace. No GGUF. No conversion. No waiting.

### Full Setup Guide

See [docs/mlx-setup-guide.md](docs/mlx-setup-guide.md) — every command, every dependency, every gotcha. No bullshit.

---

## Hardware

```
AMD Ryzen AI MAX+ PRO 395
Radeon 8060S (gfx1151)
128GB unified memory
CachyOS (Arch Linux), kernel 7.0.0-1-mainline
```

---

## Stack

| Layer | What |
|-------|------|
| **Inference** | MLX Engine ROCm (bleeding-edge) / Vulkan llamacpp (stable) |
| **Model Router** | Lemonade SDK 10.2.0 |
| **NPU** | Lemonade FLM (XDNA2) — runs alongside GPU |
| **TTS** | Kokoro v1 |
| **ASR** | Whisper Large v3 Turbo |
| **Image** | SD-Turbo + Flux via sd-cpp |
| **Cognitive** | Living Mind Cortex v2.0 |

---

## Related

- [halo-ai-core](https://github.com/stampby/halo-ai-core) — Stable release
- [lemon-mlx-engine](https://github.com/lemonade-sdk/lemon-mlx-engine) — Upstream MLX engine
- [Lemonade SDK](https://github.com/lemonade-sdk/lemonade) — Model router
- [r/MidlifeCrisisAI](https://reddit.com/r/MidlifeCrisisAI) — Benchmarks, stories, community

---

*"Little bones, little bones, everywhere I go" — Gord Downie*

*Designed and built by the architect.*
