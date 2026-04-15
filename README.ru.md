🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [**Русский**](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — LLM-инференс на AMD Strix Halo

Движок LLM-инференса на чистом C++ для AMD Strix Halo (gfx1151) со 128 ГБ унифицированной памяти. На 83% быстрее Vulkan llamacpp.

## Производительность

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         130.6 tok/s   ██████████████████████████░░░░░
  MLX ROCm          149.3 tok/s   █████████████████████████████▌
```

**149.3 tok/s** на Qwen3-0.6B — эталонный бенчмарк на кремнии AMD.

## benchmarks — standardized burn (2026-04-15)

4 бэкенда. 16 моделей. 256 token generation. 3 rounds. stddev < 1 tok/s. `bench.sh`

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

## Почему bleeding-edge

- **Чистый C++** — без зависимостей Python, без ожидания конвертации GGUF
- **Готовый бинарный файл** — настройка за 30 секунд
- **На 83% быстрее** Vulkan llamacpp на той же машине
- **AMD Strix Halo gfx1151** — 128 ГБ унифицированной памяти
- **Нативный ROCm** — прямой доступ к оборудованию, без слоёв абстракции

## Быстрый старт

```bash
# Скачать готовый бинарный файл
# Запустить инференс за 30 секунд
```

Полные инструкции по установке см. в [основном README](README.md).

## Архитектура

Этот движок использует ROCm напрямую на кремнии AMD Strix Halo, минуя слои абстракции вроде Vulkan для достижения максимальной пропускной способности. Дизайн на чистом C++ устраняет накладные расходы интерпретатора Python и этапы конвертации моделей.

## Целевое оборудование

| Компонент | Характеристика |
|-----------|---------------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| Память | 128 ГБ унифицированная |
| Бэкенд | ROCm |

## Ссылки

- **Основной репозиторий** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [Присоединиться к сообществу](https://discord.gg/dSyV646eBs)

## Лицензия

Подробности лицензии см. в основном репозитории.

---

*поставлено печатью архитектора*
