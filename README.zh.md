🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [**中文**](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo上的LLM推理

面向AMD Strix Halo（gfx1151）的纯C++ LLM推理引擎，配备128GB统一内存。比Vulkan llamacpp快83%。

## 性能

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         130.6 tok/s   ██████████████████████████░░░░░
  MLX ROCm          149.3 tok/s   █████████████████████████████▌
```

Qwen3-0.6B上达到**149.3 tok/s** — AMD硅片上的权威基准测试。

## benchmarks — standardized burn (2026-04-15)

4个后端。16个模型。256 token generation。3 rounds。stddev < 1 tok/s。`bench.sh`

### mlx engine rocm — hipBLASLt (gfx1151)

| model | size | tok/s | ±stddev |
|-------|------|------:|--------:|
| Qwen3-0.6B-4bit | 0.4 GB | **149.3** | ±0.3 |
| Qwen3-1.7B-4bit | 1.1 GB | **65.2** | ±0.2 |
| Qwen3-4B-4bit | 2.6 GB | **44.5** | ±0.1 |
| Phi-4-mini-4bit | 2.5 GB | **37.0** | ±0.2 |
| Qwen3-8B-4bit | 5.0 GB | **20.8** | ±0.1 |

### vllm rocm (gfx1151)

| model | size | tok/s | ±stddev |
|-------|------|------:|--------:|
| Qwen3-0.6B | 1.2 GB | **130.6** | ±0.6 |
| Qwen3-1.7B | 3.4 GB | **47.1** | ±0.2 |
| Qwen3-4B-AWQ | 2.5 GB | **41.5** | ±0.1 |
| Phi-4-mini | 7.6 GB | **24.9** | ±0.0 |
| Qwen3-8B-AWQ | 4.9 GB | **22.3** | ±0.1 |

### head-to-head

| model | mlx rocm | vllm rocm | vulkan | npu |
|-------|------:|------:|------:|------:|
| Qwen3-0.6B | **149.3** | 130.6 | 82.5 | 94.4 |
| Qwen3-1.7B | **65.2** | 47.1 | — | — |
| Qwen3-4B | **44.5** | 41.5 (AWQ) | — | — |
| Qwen3-8B | **20.8** | 22.3 (AWQ) | — | 10.8 |

### prism llama.cpp — vulkan 1-bit

| model | quant | size | tok/s | stddev |
|-------|-------|------|------:|-------:|
| Qwen3-Coder-Next | TQ1_0 (1-bit) | 3.2 GB | **65.6** | ±0.8 |

### lemond/FastFlowLM — RyzenAI NPU (50 TOPS)

| model | size | tok/s | stddev | TTFT |
|-------|------|------:|-------:|-----:|
| Qwen3-0.6B-FLM | 0.7 GB | **94.4** | ±0.2 | 0.46s |
| Llama-3.2-1B-FLM | 1.3 GB | **61.7** | ±0.2 | 0.38s |
| Gemma3-1B-FLM | 1.2 GB | **38.9** | ±0.0 | 0.53s |
| Llama-3.2-3B-FLM | 2.7 GB | **24.9** | ±0.0 | 0.77s |
| Qwen3-8B-FLM | 5.6 GB | **10.8** | ±0.0 | 1.28s |

## 为什么选择bleeding-edge

- **纯C++** — 无Python依赖，无GGUF转换等待
- **预编译二进制文件** — 30秒完成安装
- **快83%** — 在同一台机器上对比Vulkan llamacpp
- **AMD Strix Halo gfx1151** — 128GB统一内存
- **原生ROCm** — 直接硬件访问，无抽象层

## 快速开始

```bash
# 下载预编译二进制文件
# 30秒内开始推理
```

完整安装说明请参阅[主README](README.md)。

## 架构

该引擎直接在AMD Strix Halo硅片上使用ROCm，绕过Vulkan等抽象层以实现最大吞吐量。纯C++设计消除了Python解释器开销和模型转换步骤。

## 目标硬件

| 组件 | 规格 |
|------|------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| 内存 | 128GB统一 |
| 后端 | ROCm |

## 链接

- **主仓库** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [加入社区](https://discord.gg/dSyV646eBs)

## 许可证

许可证详情请参阅主仓库。

---

*由架构师盖章*
