🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [**Português**](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — Inferência LLM no AMD Strix Halo

Motor de inferência LLM em C++ puro para AMD Strix Halo (gfx1151) com 128 GB de memória unificada. 83% mais rápido que Vulkan llamacpp.

## Desempenho

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

**151.2 tok/s** no Qwen3-0.6B — o benchmark definitivo em silício AMD.

## Por que bleeding-edge

- **C++ puro** — sem dependências Python, sem espera de conversão GGUF
- **Binário pré-compilado** — configuração em 30 segundos
- **83% mais rápido** que Vulkan llamacpp na mesma máquina
- **AMD Strix Halo gfx1151** — 128 GB de memória unificada
- **ROCm nativo** — acesso direto ao hardware, sem camada de abstração

## Início rápido

```bash
# Baixar o binário pré-compilado
# Executar inferência em 30 segundos
```

Consulte o [README principal](README.md) para instruções completas de instalação.

## Arquitetura

Este motor utiliza ROCm diretamente no silício AMD Strix Halo, contornando camadas de abstração como Vulkan para atingir o máximo throughput. O design em C++ puro elimina a sobrecarga do interpretador Python e as etapas de conversão de modelos.

## Hardware alvo

| Componente | Especificação |
|------------|--------------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| Memória | 128 GB unificada |
| Backend | ROCm |

## Links

- **Repositório principal** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [Junte-se à comunidade](https://discord.gg/dSyV646eBs)

## Licença

Consulte o repositório principal para detalhes da licença.

---

*carimbado pelo arquiteto*
