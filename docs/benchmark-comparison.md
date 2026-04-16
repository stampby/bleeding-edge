# Benchmark Comparison — MLX ROCm vs vLLM vs NPU+ROCm Hybrid

**Hardware:** AMD Strix Halo (Ryzen AI MAX+ 395) · gfx1151 · 128 GB unified · 50 TOPS NPU
**OS:** CachyOS (Arch) · Kernel 7.0.0-1-mainline · ROCm 7.12.0
**Date:** 2026-04-15

All numbers: **tok/s generation** · 5-run mean · 200-256 tokens

---

## Head-to-Head: Same Model Across Backends

| Model | Size | MLX ROCm | vLLM ROCm | Vulkan (1-bit) | NPU (FLM) | Fastest |
|-------|------|------:|------:|------:|------:|---------|
| **Qwen3-0.6B** | 0.6B | **151.2** | 130.6 | — | 94.4 | MLX (+16% vs vLLM) |
| **Qwen3-1.7B** | 1.7B | **66.4** | 47.1 | — | — | MLX (+41%) |
| **Qwen3-4B** | 4B | **46.9** | 41.5 (AWQ) | — | — | MLX (+13%) |
| **Qwen3-8B** | 8B | **21.7** | 22.3 (AWQ) | — | 10.8 | vLLM (+3%) |
| **Phi-4-mini** | 3.8B | **38.3** | 24.9 | — | — | MLX (+54%) |
| **Llama-3.2-1B** | 1B | — | 110.4 | — | 61.7 | vLLM* |
| **Llama-3.2-3B** | 3B | — | 50.5 | — | 24.9 | vLLM* |
| **Bonsai-1.7B** | 1.7B | — | — | **136.8** | — | Vulkan 1-bit |
| **Bonsai-8B** | 8.2B | — | — | **63.8** | — | Vulkan 1-bit |

*MLX Llama models failed warmup — ROCm kernel gap, not architecture

---

## MLX ROCm Advantage

| Model | MLX tok/s | vLLM tok/s | Delta | % Faster |
|-------|------:|------:|------:|------:|
| Qwen3-0.6B | 151.2 | 130.6 | +20.6 | **+16%** |
| Qwen3-1.7B | 66.4 | 47.1 | +19.3 | **+41%** |
| Qwen3-4B | 46.9 | 41.5 | +5.4 | **+13%** |
| Phi-4-mini | 38.3 | 24.9 | +13.4 | **+54%** |
| Qwen3-8B | 21.7 | 22.3 | -0.6 | -3% |

**MLX wins 4/5** comparisons. vLLM edges ahead at 8B (AWQ quantization advantage — MLX uses 4-bit, vLLM uses AWQ which is better for larger models).

**Average MLX advantage: +29%** across comparable models.

---

## NPU (FastFlowLM) — Zero GPU Impact

| Model | NPU tok/s | TTFT | RAM | Note |
|-------|------:|------:|------:|------|
| Qwen3-0.6B | 94.4 | 0.46s | 0.7 GB | Fastest NPU model |
| Llama-3.2-1B | 61.7 | 0.38s | 1.3 GB | Best TTFT |
| Gemma3-1B | 38.9 | 0.53s | 1.2 GB | |
| Llama-3.2-3B | 24.9 | 0.77s | 2.7 GB | |
| Qwen3-8B | 10.8 | 1.28s | 5.6 GB | Largest NPU model |

**Key:** NPU uses **zero GPU memory**. Always-on agents, voice, embeddings run on NPU while GPU handles big models. This is the hybrid advantage — not competing, complementing.

---

## Vulkan 1-Bit (Prism/Bonsai) — The Wild Card

| Model | Params | Weight Size | pp512 t/s | tg128 t/s |
|-------|--------|-------------|------:|------:|
| Bonsai-1.7B | 1.72B | 231 MB | 3,120.8 | **136.8** |
| Bonsai-4B | 4.02B | 540 MB | 1,401.3 | **85.0** |
| Bonsai-8B | 8.19B | 1.07 GB | 831.4 | **63.8** |
| Qwen3-Coder-Next | 79.67B MoE | 17.6 GB | 712.4 | **64.9** |

Natively-trained 1-bit models beat everything at equivalent sizes. 8B in 1 GB at 64 tok/s. 80B MoE at 65 tok/s in 17 GB. Prompt processing is absurd (3K+ tok/s at 1.7B).

---

## The Full Stack — Three Engines, One Machine

```
┌──────────────────────────────────────────────────────────┐
│                    lemond (router)                        │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  MLX ROCm    │  │   vLLM       │  │  NPU (FLM)   │   │
│  │  GPU (iGPU)  │  │  GPU (iGPU)  │  │  XDNA2       │   │
│  │              │  │              │  │              │   │
│  │  Qwen3-4B    │  │  Qwen3-8B   │  │  Qwen3-0.6B  │   │
│  │  46.9 tok/s  │  │  22.3 tok/s  │  │  94.4 tok/s  │   │
│  │  4-bit MLX   │  │  AWQ ROCm    │  │  FLM int8    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │  Prism       │  │  halo-1bit (this project)        │  │
│  │  Vulkan      │  │  MLX ROCm · 1.58-bit ternary    │  │
│  │              │  │  Custom HIP kernel (Phase 2)     │  │
│  │  Bonsai-8B   │  │  BitNet-2B-4T                    │  │
│  │  63.8 tok/s  │  │  1.22 tok/s (Phase 1)            │  │
│  │  1-bit native│  │  QAT training in progress         │  │
│  └──────────────┘  └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**Total throughput when all run simultaneously:**
- GPU: MLX or vLLM handling coding/reasoning (20-150 tok/s)
- NPU: FLM handling agents/voice/embeddings (10-94 tok/s, zero GPU cost)
- Vulkan: 1-bit models for fast local inference (64-137 tok/s)

---

## Regressions for AMD Dev

1. **vLLM Qwen3-1.7B**: Huge variance (2.5-47.7 tok/s, stddev=26). Something wrong with batch scheduling at this size.
2. **vLLM load times**: 100-330s for some models (Phi-4-mini: 102s, Qwen3.5-4B: 332s). MLX loads same models in 3-5s.
3. **vLLM Gemma-3-4b-it**: Load failure.
4. **vLLM Qwen3.5-0.8B**: Load failure.
5. **MLX ROCm**: BitNet-2B and Falcon-E 1.58-bit fail warmup (WMMA kernel gaps for non-standard quant).
6. **MLX ROCm**: All models >8B fail (32B, 72B, 122B, DeepSeek-V3) — likely memory management or kernel compilation timeout.

---

*Generated from [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge) bench.sh results*
