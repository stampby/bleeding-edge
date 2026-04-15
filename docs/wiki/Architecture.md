# Architecture — Why MLX Wins

## The Three Backends

### Vulkan llamacpp (Stable)
- C++ with Vulkan compute shaders
- GGUF model format only
- Wait for GGUF conversion on new model releases
- ~82 tok/s on MoE models (3B active)

### vLLM ROCm (Production Serving)
- Python + C++ with Triton/HIP kernels
- HuggingFace native models
- PagedAttention, continuous batching, prefix caching
- First-run Triton JIT: 20-350 seconds
- ~117 tok/s on 0.6B, 2.3 tok/s on 72B dense

### MLX ROCm (Bleeding Edge)
- Pure C++ — compiled HIP kernels, no Python runtime
- HuggingFace native models (safetensors)
- Designed for unified memory (Apple Silicon → Strix Halo)
- Cold start in seconds
- ~151 tok/s on 0.6B, 29-85% faster than vLLM

## Why MLX is Faster

### 1. No Python Overhead
vLLM spawns Python processes, loads PyTorch, initializes CUDA/HIP contexts. MLX is a single compiled binary.

### 2. No Triton JIT
vLLM uses Triton to compile attention kernels at runtime for your GPU. First load of each model size takes 20-350 seconds. MLX uses pre-compiled HIP kernels — instant.

### 3. Unified Memory Native
MLX was designed from day one for Apple's unified memory architecture. Strix Halo has the same design — CPU and GPU share the same memory pool. No copies, no PCIe bottleneck.

### 4. No Subprocess Device Issues
vLLM's EngineCore subprocess had Triton HIP device enumeration failures on gfx1151 (Triton Error 101: invalid device ordinal). MLX runs in a single process — no fork, no device inheritance problems.

## When to Use What

| Use Case | Best Backend |
|----------|-------------|
| Single user, fastest tok/s | **MLX** |
| Multi-user serving | **vLLM** (PagedAttention) |
| GGUF models specifically | **Vulkan llamacpp** |
| Day-one new model access | **MLX** or **vLLM** |
| NPU simultaneous | Any (NPU is separate silicon) |

## The Stack

```
┌──────────────────────────────────────────┐
│  Applications (Discord agents, chat, API) │
├──────────────────────────────────────────┤
│  Lemonade SDK 10.2 — Model Router        │
├────────────┬────────────┬────────────────┤
│ MLX Engine │ vLLM ROCm  │ llamacpp Vulkan│
│ (bleeding) │ (PR #1537) │ (stable)       │
├────────────┴────────────┴────────────────┤
│  ROCm 7.12 (portable) / 7.2.1 (system)  │
├──────────────────────────────────────────┤
│  AMD Strix Halo gfx1151, 128GB unified   │
└──────────────────────────────────────────┘
```
