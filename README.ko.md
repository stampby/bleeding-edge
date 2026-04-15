🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [**한국어**](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo에서의 LLM 추론

AMD Strix Halo(gfx1151)용 순수 C++ LLM 추론 엔진. 128GB 통합 메모리. Vulkan llamacpp보다 83% 빠름.

## 성능

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

Qwen3-0.6B에서 **151.2 tok/s** — AMD 실리콘의 결정적 벤치마크.

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
