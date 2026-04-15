🌐 [English](README.md) | [Français](README.fr.md) | [**Español**](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — Inferencia LLM en AMD Strix Halo

Motor de inferencia LLM en C++ puro para AMD Strix Halo (gfx1151) con 128 GB de memoria unificada. 83% más rápido que Vulkan llamacpp.

## Rendimiento

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

**151.2 tok/s** en Qwen3-0.6B — el punto de referencia definitivo en silicio AMD.

## Por qué bleeding-edge

- **C++ puro** — sin dependencias de Python, sin esperas de conversión GGUF
- **Binario precompilado** — configuración en 30 segundos
- **83% más rápido** que Vulkan llamacpp en la misma máquina
- **AMD Strix Halo gfx1151** — 128 GB de memoria unificada
- **ROCm nativo** — acceso directo al hardware, sin capas de abstracción

## Inicio rápido

```bash
# Descargar el binario precompilado
# Ejecutar inferencia en 30 segundos
```

Consulte el [README principal](README.md) para instrucciones completas de instalación.

## Arquitectura

Este motor utiliza ROCm directamente sobre el silicio AMD Strix Halo, evitando capas de abstracción como Vulkan para alcanzar el máximo rendimiento. El diseño en C++ puro elimina la sobrecarga del intérprete Python y los pasos de conversión de modelos.

## Hardware objetivo

| Componente | Especificación |
|------------|---------------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| Memoria | 128 GB unificada |
| Backend | ROCm |

## Enlaces

- **Repositorio principal** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [Únete a la comunidad](https://discord.gg/dSyV646eBs)

## Licencia

Consulte el repositorio principal para los detalles de la licencia.

---

*sellado por el arquitecto*
