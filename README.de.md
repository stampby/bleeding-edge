🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [**Deutsch**](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — LLM-Inferenz auf AMD Strix Halo

Reiner C++ LLM-Inferenzmotor für AMD Strix Halo (gfx1151) mit 128 GB vereinheitlichtem Speicher. 83% schneller als Vulkan llamacpp.

## Leistung

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

**151.2 tok/s** auf Qwen3-0.6B — der definitive Benchmark auf AMD-Silizium.

## Warum bleeding-edge

- **Reines C++** — keine Python-Abhängigkeiten, keine GGUF-Konvertierungswartezeit
- **Vorkompiliertes Binary** — Einrichtung in 30 Sekunden
- **83% schneller** als Vulkan llamacpp auf derselben Maschine
- **AMD Strix Halo gfx1151** — 128 GB vereinheitlichter Speicher
- **Natives ROCm** — direkter Hardwarezugriff, keine Abstraktionsschicht

## Schnellstart

```bash
# Vorkompiliertes Binary herunterladen
# Inferenz in 30 Sekunden starten
```

Siehe die [Haupt-README](README.md) für vollständige Installationsanweisungen.

## Architektur

Dieser Motor nutzt ROCm direkt auf dem AMD Strix Halo-Silizium und umgeht Abstraktionsschichten wie Vulkan für maximalen Durchsatz. Das reine C++-Design eliminiert den Python-Interpreter-Overhead und Modellkonvertierungsschritte.

## Zielhardware

| Komponente | Spezifikation |
|------------|--------------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| Speicher | 128 GB vereinheitlicht |
| Backend | ROCm |

## Links

- **Haupt-Repository** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [Der Community beitreten](https://discord.gg/dSyV646eBs)

## Lizenz

Siehe das Haupt-Repository für Lizenzdetails.

---

*gestempelt vom Architekten*
