🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [**中文**](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo上的LLM推理

面向AMD Strix Halo（gfx1151）的纯C++ LLM推理引擎，配备128GB统一内存。比Vulkan llamacpp快83%。

## 性能

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

Qwen3-0.6B上达到**151.2 tok/s** — AMD硅片上的权威基准测试。

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
