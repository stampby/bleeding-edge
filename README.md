<!-- "Cubically Contained" — The Headstones -->
<!-- "Little bones, little bones, everywhere I go" — Gord Downie -->
<!-- If you found this, you're one of us. -->

<div align="center">

🌐 **English** | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

### the next generation of local ai inference on amd strix halo

**rocm c++ · native tensile · fused ternary kernel · 153 tok/s · wave32 · built from source**

*stamped by the architect*

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ROCm](https://img.shields.io/badge/TheRock_7.13-ED1C24?style=flat&logo=amd&logoColor=white)](https://github.com/ROCm/TheRock)
[![rocm-cpp](https://img.shields.io/badge/rocm--cpp-1bit_monster-00d4ff?style=flat)](https://github.com/stampby/rocm-cpp)
[![agent-cpp](https://img.shields.io/badge/agent--cpp-17_specialists-00d4ff?style=flat)](https://github.com/stampby/agent-cpp)
[![Lemonade](https://img.shields.io/badge/Lemonade_10.2.0-00d4ff?style=flat&logo=amd&logoColor=white)](https://github.com/lemonade-sdk/lemonade)
[![Discord](https://img.shields.io/badge/Discord-halo--ai-5865F2?style=flat&logo=discord&logoColor=white)](https://discord.gg/dSyV646eBs)
[![Reddit](https://img.shields.io/badge/Reddit-r/MidlifeCrisisAI-FF4500?style=flat&logo=reddit&logoColor=white)](https://www.reddit.com/r/MidlifeCrisisAI/)
[![Wiki](https://img.shields.io/badge/Wiki-10_pages-00d4ff?style=flat&logo=github&logoColor=white)](https://github.com/stampby/bleeding-edge/wiki)
[![Self Hosted](https://img.shields.io/badge/Self_Hosted-100%25_Local-purple?style=flat)](https://github.com/stampby/bleeding-edge)
[![halo-ai core](https://img.shields.io/badge/halo--ai_core-stable-green?style=flat)](https://github.com/stampby/halo-ai-core)

</div>

---

> *"Cubically Contained" — The Headstones*

The experimental branch of [halo-ai CORE](https://github.com/stampby/halo-ai-core). This is where the next generation gets tested before it ships.

---

## the progression

Five phases. Same hardware. Each one faster than the last.

```
Backend Progression — Strix Halo gfx1151, 128GB unified

  Phase 1  vLLM ROCm              116.7 tok/s   ███████████████████████░░░░░░░
  Phase 2  MLX ROCm C++           151.2 tok/s   ██████████████████████████████
  Phase 3  Vulkan (llama.cpp)      47.4 tok/s   █████████░░░░░░░░░░░░░░░░░░░░  (sustained)
  Phase 4  MLX C++ + TheRock      153.3 tok/s   ██████████████████████████████▌ (native Tensile)
  Phase 5  Fused Ternary GEMV      37.5 μs/layer ← first on gfx1151

  Phase 4: ROCm 7.13 built from source. 55 native Tensile kernels.
  Phase 5: Wave32 fused ternary kernel. No dequantize. No multiply.
```

### rocm c++ — native tensile results (2026-04-16)

```
GEMM Benchmark (FP16 TFLOPS)  — System vs TheRock Native Tensile

  Shape                 System    TheRock    Change
  ──────────────────────────────────────────────────
  2560x6912x2560        25.04     32.97      +32%   ← BitNet FFN
  GEMV 1x2560            0.06      0.07      +15%   ← decode path
  GEMV 1x4096            0.04      0.05      +18%   ← decode path

Fused Ternary GEMV — Wave32, no dequantize

  Shape (MxK)          Time (μs)    Correct
  ──────────────────────────────────────────
  2560x2560 (Q/K/V/O)    37.5        ✓
  6912x2560 (FFN up)     109.3       ✓
  2560x6912 (FFN down)   104.0       ✓
  4096x4096 (7B size)     98.6       ✓
```

> source + benchmarks: [rocm-cpp](https://github.com/stampby/rocm-cpp) · wiki: [bleeding-edge wiki](https://github.com/stampby/bleeding-edge/wiki)

---

## benchmarks — standardized burn (2026-04-15)

4 backends. 16 models. 256 token generation. 3 rounds. stddev < 1 tok/s. `bench.sh` in this repo.

### mlx engine rocm — hipBLASLt (gfx1151)

| model | size | tok/s | ±stddev |
|-------|------|------:|--------:|
| Qwen3-0.6B-4bit | 0.4 GB | **149.3** | ±0.3 |
| Qwen3-1.7B-4bit | 1.1 GB | **65.2** | ±0.2 |
| Qwen3-4B-4bit | 2.6 GB | **44.5** | ±0.1 |
| Phi-4-mini-4bit | 2.5 GB | **37.0** | ±0.2 |
| Qwen3-8B-4bit | 5.0 GB | **20.8** | ±0.1 |

| model | mlx | vllm | vulkan | mlx advantage |
|-------|-----|------|--------|---------------|
| Qwen3-0.6B | **151.2** | 116.7 | 82.5 | **+83% vs vulkan** |
| Qwen3-4B | **46.9** | 25.4 | — | **+85% vs vllm** |
| Qwen3-8B | **21.7** | 12.3 | — | **+76% vs vllm** |
| Phi-4-mini | **38.3** | 25.1 | — | **+53% vs vllm** |

### vllm rocm (gfx1151)

| model | size | tok/s | ±stddev |
|-------|------|------:|--------:|
| Qwen3-0.6B | 1.2 GB | **130.6** | ±0.6 |
| Qwen3-1.7B | 3.4 GB | **47.1** | ±0.2 |
| Qwen3-4B-AWQ | 2.5 GB | **41.5** | ±0.1 |
| Phi-4-mini | 7.6 GB | **24.9** | ±0.0 |
| Qwen3-8B-AWQ | 4.9 GB | **22.3** | ±0.1 |

### head-to-head — four backends

| model | mlx rocm | vllm rocm | vulkan | npu |
|-------|------:|------:|------:|------:|
| Qwen3-0.6B | **149.3** | 130.6 | 82.5 | 94.4 |
| Qwen3-1.7B | **65.2** | 47.1 | — | — |
| Qwen3-4B | **44.5** | 41.5 (AWQ) | — | — |
| Qwen3-8B | **20.8** | 22.3 (AWQ) | — | 10.8 |

> raw csv: [results/RESULTS-20260415.csv](results/RESULTS-20260415.csv) · [wiki/Benchmarks](docs/wiki/Benchmarks.md)

### three backends, one machine — GPU + NPU + Vulkan simultaneous

256 token generation, 3 rounds, stddev reported. `bench.sh` in this repo. all three backends running simultaneously.

**Prism llama.cpp — Vulkan 1-bit (native + ternary)**

| model | params | quant | size | pp512 t/s | tg128 t/s |
|-------|--------|-------|------|----------:|----------:|
| Bonsai-1.7B | 1.72B | Q1_0 (1-bit) | 231 MB | **3,120.8** ±33 | **136.8** ±0.2 |
| Bonsai-4B | 4.02B | Q1_0 (1-bit) | 540 MB | **1,401.3** ±7 | **85.0** ±0.3 |
| Bonsai-8B | 8.19B | Q1_0 (1-bit) | 1.07 GB | **831.4** ±2 | **63.8** ±0.1 |
| Qwen3-Coder-Next | 79.67B MoE | IQ1_S (1.56 bpw) | 17.6 GB | **712.4** ±7 | **64.9** ±0.0 |

1-bit inference via [PrismML llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp). [Bonsai](https://huggingface.co/prism-ml) = natively trained 1-bit. 8B model in 1 GB. 80B MoE in 17 GB at 65 tok/s.

**lemond/FastFlowLM — RyzenAI NPU (aie2p · 50 TOPS)**

| model | size | tok/s | stddev | TTFT |
|-------|------|------:|-------:|-----:|
| Qwen3-0.6B-FLM | 0.7 GB | **94.4** | ±0.2 | 0.46s |
| Llama-3.2-1B-FLM | 1.3 GB | **61.7** | ±0.2 | 0.38s |
| Gemma3-1B-FLM | 1.2 GB | **38.9** | ±0.0 | 0.53s |
| Llama-3.2-3B-FLM | 2.7 GB | **24.9** | ±0.0 | 0.77s |
| Qwen3-8B-FLM | 5.6 GB | **10.8** | ±0.0 | 1.28s |

zero GPU memory used. NPU runs independently — always-on agents while GPU handles big models.

> raw csv: [results/RESULTS-20260415.csv](results/RESULTS-20260415.csv)

---

## quick start

### see it in action

```bash
asciinema play bleeding-edge-install.cast
# or: curl -sL https://raw.githubusercontent.com/stampby/bleeding-edge/main/install.sh | bash
```


### 30-second setup

```bash
mkdir -p ~/mlx-engine && cd ~/mlx-engine

# download for your gpu
# gfx1151 = strix halo | gfx1150 = strix point
# gfx110X = rdna3       | gfx120X = rdna4
gh release download b1004-tech-preview \
  -R lemonade-sdk/lemon-mlx-engine \
  -p '*gfx1151*'

unzip mlx-engine-*-gfx1151-x64.zip -d .
chmod +x chat server diagnose

# verify gpu
LD_LIBRARY_PATH=. ./diagnose mlx-community/Qwen3-1.7B-4bit

# chat
LD_LIBRARY_PATH=. ./chat mlx-community/Qwen3-4B-4bit

# api server (openai-compatible)
LD_LIBRARY_PATH=. ./server --port 8090
```

models auto-download from huggingface. no gguf. no conversion. no waiting.

> full guide: [docs/mlx-setup-guide.md](docs/mlx-setup-guide.md) · replicate our benchmarks: [docs/replicate.md](docs/replicate.md)

---

## why mlx

| | mlx engine | vllm rocm | vulkan llamacpp |
|---|---|---|---|
| **language** | c++ | python + c++ | c++ |
| **cold start** | seconds | minutes (triton jit) | seconds |
| **model format** | huggingface native | huggingface native | gguf only |
| **day-one models** | yes | yes | wait for gguf |
| **dependencies** | none (static binary) | python, torch, triton | vulkan drivers |
| **multi-user** | no (single user) | yes (pagedattention) | limited |

> architecture deep dive: [wiki/Architecture](docs/wiki/Architecture.md)

---

## the stack

```
┌──────────────────────────────────────────────┐
│  user terminal · ftxui tui (chat + stats)     │
├──────────────────────────────────────────────┤
│  agent-cpp runtime                            │
│  ┌────────┬────────┬─────────┬──────┬───────┐ │
│  │ muse   │ forge  │cartograph│warden│planner│ │
│  │ scribe │sentinel│quarterm. │herald│magist.│ │
│  │ ...and 7 more, one job each (lego bricks)│ │
│  └────────┴────────┴─────────┴──────┴───────┘ │
├──────────────────────────────────────────────┤
│  librocm_cpp.so — the 1bit monster            │
│  bitnet_decode  82 tok/s  bit-match vs ref    │
│  30.04 TFlops FP16×ternary @ ¼ B memory       │
├──────────────────────────────────────────────┤
│  therock 7.13 (from source, gfx1151)         │
│  native tensile · hipblaslt · wave32 wmma    │
├──────────────────────────────────────────────┤
│  amd strix halo gfx1151 · 128gb unified      │
└──────────────────────────────────────────────┘

if it can be done in c++, we do it in c++.
```

---

## hardware tested

```
amd ryzen ai max+ pro 395
radeon 8060s (gfx1151)
128gb unified memory
cachyos (arch linux), kernel 7.0.0-1-mainline
```

---

## docs

| document | description |
|----------|-------------|
| [mlx setup guide](docs/mlx-setup-guide.md) | full setup from scratch — every command, every dependency |
| [replicate benchmarks](docs/replicate.md) | reproduce our numbers with the included script |
| [wiki/home](docs/wiki/Home.md) | wiki navigation |
| [wiki/benchmarks](docs/wiki/Benchmarks.md) | all three backends compared |
| [wiki/architecture](docs/wiki/Architecture.md) | why mlx wins, stack diagram |
| [security](SECURITY.md) | vulnerability reporting, hardening |
| [contributing](CONTRIBUTING.md) | how to submit benchmarks and report bugs |

---

## related

| | |
|---|---|
| **[rocm-cpp](https://github.com/stampby/rocm-cpp)** | librocm_cpp — the 1-bit monster (82 tok/s BitNet-2B-4T, bit-match vs PyTorch ref) |
| **[agent-cpp](https://github.com/stampby/agent-cpp)** | specialist framework — 17 agents, one job each, FTXUI-ready |
| **[halo-ai core](https://github.com/stampby/halo-ai-core)** | stable release — 13 services, install script, full stack |
| **[halo-1bit](https://github.com/stampby/halo-1bit)** | model pipeline — bitnet-2b-4t export + .h1b absmean quant |
| **[lemonade sdk](https://github.com/lemonade-sdk/lemonade)** | model router and backend manager |
| **[discord](https://discord.gg/dSyV646eBs)** | community — 8 ai agents, 24/7 |
| **[r/MidlifeCrisisAI](https://reddit.com/r/MidlifeCrisisAI)** | benchmarks, stories, write-ups |

---

<div align="center">

*"little bones, little bones, everywhere i go" — gord downie*

*designed and built by the architect*

</div>
