🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [**한국어**](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo에서의 LLM 추론

AMD Strix Halo(gfx1151)용 순수 C++ LLM 추론 엔진. 128GB 통합 메모리. Vulkan llamacpp보다 83% 빠름.

## 성능

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         130.6 tok/s   ██████████████████████████░░░░░
  MLX ROCm          149.3 tok/s   █████████████████████████████▌
```

Qwen3-0.6B에서 **149.3 tok/s** — AMD 실리콘의 결정적 벤치마크.

## benchmarks — standardized burn (2026-04-15)

4개 백엔드. 16개 모델. 256 token generation. 3 rounds. stddev < 1 tok/s. `bench.sh`

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

## 왜 bleeding-edge인가

- **순수 C++** — Python 의존성 없음, GGUF 변환 대기 없음
- **사전 빌드된 바이너리** — 30초 설정
- **83% 더 빠름** — 동일 머신에서 Vulkan llamacpp 대비
- **AMD Strix Halo gfx1151** — 128GB 통합 메모리
- **네이티브 ROCm** — 하드웨어 직접 접근, 추상화 레이어 없음

## 빠른 시작

```bash
# 사전 빌드된 바이너리 다운로드
# 30초 만에 추론 시작
```

전체 설치 안내는 [메인 README](README.md)를 참조하세요.

## 아키텍처

이 엔진은 AMD Strix Halo 실리콘에서 ROCm을 직접 활용하여 Vulkan과 같은 추상화 레이어를 우회하고 최대 처리량을 달성합니다. 순수 C++ 설계로 Python 인터프리터 오버헤드와 모델 변환 단계를 제거했습니다.

## 대상 하드웨어

| 구성 요소 | 사양 |
|----------|------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| 메모리 | 128GB 통합 |
| 백엔드 | ROCm |

## 링크

- **메인 저장소** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [커뮤니티 참여](https://discord.gg/dSyV646eBs)

## 라이선스

라이선스 세부 사항은 메인 저장소를 참조하세요.

---

*아키텍트의 도장*
