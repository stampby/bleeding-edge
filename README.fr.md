🌐 [English](README.md) | [**Français**](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — Inférence LLM sur AMD Strix Halo

Moteur d'inférence LLM en C++ pur pour AMD Strix Halo (gfx1151) avec 128 Go de mémoire unifiée. 83% plus rapide que Vulkan llamacpp.

## Performances

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

**151.2 tok/s** sur Qwen3-0.6B — le benchmark de référence sur silicium AMD.

## Pourquoi bleeding-edge

- **C++ pur** — aucune dépendance Python, aucun temps d'attente de conversion GGUF
- **Binaire pré-compilé** — installation en 30 secondes
- **83% plus rapide** que Vulkan llamacpp sur la même machine
- **AMD Strix Halo gfx1151** — 128 Go de mémoire unifiée
- **ROCm natif** — accès direct au matériel, pas de couche d'abstraction

## Démarrage rapide

```bash
# Télécharger le binaire pré-compilé
# Lancer l'inférence en 30 secondes
```

Consultez le [README principal](README.md) pour les instructions complètes d'installation.

## Architecture

Ce moteur exploite directement ROCm sur le silicium AMD Strix Halo, contournant les couches d'abstraction comme Vulkan pour atteindre un débit maximal. La conception en C++ pur élimine la surcharge de l'interpréteur Python et les étapes de conversion de modèle.

## Matériel cible

| Composant | Spécification |
|-----------|--------------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| Mémoire | 128 Go unifiée |
| Backend | ROCm |

## Liens

- **Dépôt principal** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Noyau IA Halo** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [Rejoignez la communauté](https://discord.gg/dSyV646eBs)

## Licence

Consultez le dépôt principal pour les détails de licence.

---

*estampillé par l'architecte*
