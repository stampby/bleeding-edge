<!-- "Cubically Contained" — The Headstones -->
<!-- "Little bones, little bones, everywhere I go" — Gord Downie -->
<!-- If you found this, you're one of us. -->

<div align="center">

🌐 **English** | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

### the next generation of local ai inference on amd strix halo

**mlx engine rocm · 151 tok/s · 83% faster than vulkan · pure c++ · no python · no gguf wait**

*stamped by the architect*

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ROCm](https://img.shields.io/badge/ROCm_7.12.0-ED1C24?style=flat&logo=amd&logoColor=white)](https://github.com/ROCm/TheRock)
[![MLX](https://img.shields.io/badge/MLX_Engine-b1004-00d4ff?style=flat)](https://github.com/lemonade-sdk/lemon-mlx-engine)
[![Lemonade](https://img.shields.io/badge/Lemonade_10.2.0-00d4ff?style=flat&logo=amd&logoColor=white)](https://github.com/lemonade-sdk/lemonade)
[![Discord](https://img.shields.io/badge/Discord-halo--ai-5865F2?style=flat&logo=discord&logoColor=white)](https://discord.gg/dSyV646eBs)
[![Reddit](https://img.shields.io/badge/Reddit-r/MidlifeCrisisAI-FF4500?style=flat&logo=reddit&logoColor=white)](https://www.reddit.com/r/MidlifeCrisisAI/)
[![Wiki](https://img.shields.io/badge/Wiki-3_pages-00d4ff?style=flat&logo=github&logoColor=white)](docs/wiki/Home.md)
[![Self Hosted](https://img.shields.io/badge/Self_Hosted-100%25_Local-purple?style=flat)](https://github.com/stampby/bleeding-edge)
[![halo-ai core](https://img.shields.io/badge/halo--ai_core-stable-green?style=flat)](https://github.com/stampby/halo-ai-core)

</div>

---

> *"Cubically Contained" — The Headstones*

The experimental branch of [halo-ai CORE](https://github.com/stampby/halo-ai-core). This is where the next generation gets tested before it ships.

---

## the progression

Three backends. Same hardware. Same day. Same desk.

```
Backend Progression — Strix Halo gfx1151, 128GB unified

  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌

  +83% improvement from Vulkan to MLX.
```

---

## benchmarks

### mlx engine rocm — 5 runs, mean ± stddev

| model | tok/s | ±stddev | notes |
|-------|-------|---------|-------|
| Qwen3-0.6B-4bit | **151.2** | ±0.1 | routing / triage |
| Qwen3-1.7B-4bit | **66.4** | ±0.0 | fast general |
| Qwen3-4B-4bit | **46.9** | ±0.0 | sweet spot |
| Phi-4-mini-instruct-4bit | **38.3** | ±0.0 | microsoft phi |
| Qwen3-Coder-Next-4bit | **26.7** | ±0.0 | latest coding model |
| Qwen3-8B-4bit | **21.7** | ±0.0 | heavy reasoning |

### head-to-head

| model | mlx | vllm | vulkan | mlx advantage |
|-------|-----|------|--------|---------------|
| Qwen3-0.6B | **151.2** | 116.7 | 82.5 | **+83% vs vulkan** |
| Qwen3-4B | **46.9** | 25.4 | — | **+85% vs vllm** |
| Qwen3-8B | **21.7** | 12.3 | — | **+76% vs vllm** |
| Phi-4-mini | **38.3** | 25.1 | — | **+53% vs vllm** |

> full benchmark data: [wiki/Benchmarks](docs/wiki/Benchmarks.md) · [raw json](benchmarks/)

### three backends, one machine — standardized burn (2026-04-15)

256 token generation, 3 rounds, stddev reported. `bench.sh` in this repo. all three backends running simultaneously.

**Prism llama.cpp — Vulkan 1-bit**

| model | quant | size | tok/s | stddev |
|-------|-------|------|------:|-------:|
| Qwen3-Coder-Next | TQ1_0 (1-bit) | 3.2 GB | **65.6** | ±0.8 |

1-bit inference via [PrismML llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp). ternary weights at 1.69 bpw.

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
┌──────────────────────────────────────────┐
│  applications (discord agents, chat, api) │
├──────────────────────────────────────────┤
│  lemonade sdk 10.2 — model router         │
├────────────┬────────────┬────────────────┤
│ mlx engine │ vllm rocm  │ llamacpp vulkan│
│ (bleeding) │ (pr #1537) │ (stable)       │
├────────────┴────────────┴────────────────┤
│  rocm 7.12 (portable) / 7.2.1 (system)   │
├──────────────────────────────────────────┤
│  amd strix halo gfx1151 · 128gb unified  │
│  npu: xdna2 via lemonade flm             │
└──────────────────────────────────────────┘
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
| **[halo-ai core](https://github.com/stampby/halo-ai-core)** | stable release — 13 services, install script, full stack |
| **[lemon-mlx-engine](https://github.com/lemonade-sdk/lemon-mlx-engine)** | upstream mlx engine |
| **[lemonade sdk](https://github.com/lemonade-sdk/lemonade)** | model router and backend manager |
| **[discord](https://discord.gg/dSyV646eBs)** | community — 8 ai agents, 24/7 |
| **[r/MidlifeCrisisAI](https://reddit.com/r/MidlifeCrisisAI)** | benchmarks, stories, write-ups |

---

<div align="center">

*"little bones, little bones, everywhere i go" — gord downie*

*designed and built by the architect*

</div>
