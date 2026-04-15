🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [**हिन्दी**](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo पर LLM इंफरेंस

AMD Strix Halo (gfx1151) के लिए शुद्ध C++ LLM इंफरेंस इंजन। 128GB एकीकृत मेमोरी। Vulkan llamacpp से 83% तेज।

## प्रदर्शन

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         130.6 tok/s   ██████████████████████████░░░░░
  MLX ROCm          149.3 tok/s   █████████████████████████████▌
```

Qwen3-0.6B पर **149.3 tok/s** — AMD सिलिकॉन पर निर्णायक बेंचमार्क।

## benchmarks — standardized burn (2026-04-15)

4 बैकएंड। 16 मॉडल। 256 token generation। 3 rounds। stddev < 1 tok/s। `bench.sh`

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

## bleeding-edge क्यों

- **शुद्ध C++** — कोई Python निर्भरता नहीं, कोई GGUF कन्वर्शन प्रतीक्षा नहीं
- **पूर्व-निर्मित बाइनरी** — 30 सेकंड में सेटअप
- **83% तेज** — उसी मशीन पर Vulkan llamacpp की तुलना में
- **AMD Strix Halo gfx1151** — 128GB एकीकृत मेमोरी
- **नेटिव ROCm** — हार्डवेयर तक सीधी पहुँच, कोई एब्स्ट्रैक्शन लेयर नहीं

## त्वरित शुरुआत

```bash
# पूर्व-निर्मित बाइनरी डाउनलोड करें
# 30 सेकंड में इंफरेंस शुरू करें
```

पूर्ण इंस्टॉलेशन निर्देशों के लिए [मुख्य README](README.md) देखें।

## आर्किटेक्चर

यह इंजन AMD Strix Halo सिलिकॉन पर सीधे ROCm का उपयोग करता है, अधिकतम थ्रूपुट के लिए Vulkan जैसी एब्स्ट्रैक्शन लेयर को बायपास करता है। शुद्ध C++ डिज़ाइन Python इंटरप्रेटर ओवरहेड और मॉडल कन्वर्शन चरणों को समाप्त करता है।

## लक्ष्य हार्डवेयर

| घटक | विनिर्देश |
|------|----------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| मेमोरी | 128GB एकीकृत |
| बैकएंड | ROCm |

## लिंक

- **मुख्य रिपॉजिटरी** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [समुदाय से जुड़ें](https://discord.gg/dSyV646eBs)

## लाइसेंस

लाइसेंस विवरण के लिए मुख्य रिपॉजिटरी देखें।

---

*आर्किटेक्ट द्वारा मुहर लगाई गई*
