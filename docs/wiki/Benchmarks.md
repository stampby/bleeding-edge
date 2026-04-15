# Benchmarks

## MLX Engine ROCm — gfx1151 (Strix Halo)

**Engine:** lemon-mlx-engine b1004-tech-preview
**ROCm:** 7.12.0
**Method:** 5 runs, 2 warmup, 200 max tokens, mean ± stddev

| Model | tok/s | ±StdDev |
|-------|-------|---------|
| Qwen3-0.6B-4bit | 151.2 | ±0.1 |
| Qwen3-1.7B-4bit | 66.4 | ±0.0 |
| Qwen3-4B-4bit | 46.9 | ±0.0 |
| Phi-4-mini-instruct-4bit | 38.3 | ±0.0 |
| Qwen3-Coder-Next-4bit | 26.7 | ±0.0 |
| Qwen3-8B-4bit | 21.7 | ±0.0 |

## vLLM ROCm — gfx1151

**Engine:** vLLM 0.19.0 + ROCm 7.12.0 via Lemonade PR #1537

| Model | tok/s | ±StdDev | Type |
|-------|-------|---------|------|
| Qwen3-0.6B | 116.7 | ±0.2 | FP16 |
| Llama-3.2-1B-Instruct | 110.4 | ±0.0 | AWQ |
| Llama-3.2-3B-Instruct | 50.5 | ±0.1 | AWQ |
| Qwen3.5-2B | 44.0 | ±0.0 | FP16 |
| Qwen3-4B-AWQ | 42.8 | ±0.0 | AWQ |
| Qwen3-4B | 25.4 | ±0.0 | FP16 |
| Phi-4-mini | 25.1 | ±0.0 | FP16 |
| Qwen3-8B-AWQ | 22.8 | ±0.0 | AWQ |
| Qwen3-8B | 12.3 | ±0.0 | FP16 |
| Qwen3.5-9B | 11.6 | ±0.0 | FP16 |
| Qwen2.5-72B-AWQ | 2.3 | ±0.1 | AWQ (72B dense) |

## Vulkan llamacpp — gfx1151

**Backend:** llama.cpp Vulkan via Lemonade SDK 10.2.0

| Model | tok/s | ±StdDev | Notes |
|-------|-------|---------|-------|
| Qwen3.5-35B-A3B (MoE) | 83.7 | ±0.1 | ~3B active params |
| Qwen3-Coder-30B (MoE) | 83.7 | ±0.1 | ~3B active params |

## Head-to-Head Comparison

```
Backend Progression — Qwen3-0.6B on gfx1151

  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌

  +83% from Vulkan to MLX.
```
