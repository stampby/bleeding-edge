🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [**日本語**](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix HaloでのLLM推論

AMD Strix Halo（gfx1151）向けの純粋なC++ LLM推論エンジン。128GBの統合メモリ搭載。Vulkan llamacppより83%高速。

## パフォーマンス

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

Qwen3-0.6Bで**151.2 tok/s** — AMDシリコンにおける決定的なベンチマーク。

## なぜbleeding-edgeなのか

- **純粋なC++** — Python依存なし、GGUF変換の待ち時間なし
- **ビルド済みバイナリ** — 30秒でセットアップ完了
- **83%高速** — 同じマシンでVulkan llamacppと比較
- **AMD Strix Halo gfx1151** — 128GB統合メモリ
- **ネイティブROCm** — ハードウェアへの直接アクセス、抽象化レイヤーなし

## クイックスタート

```bash
# ビルド済みバイナリをダウンロード
# 30秒で推論を開始
```

完全なインストール手順は[メインREADME](README.md)を参照してください。

## アーキテクチャ

このエンジンはAMD Strix Haloシリコン上でROCmを直接活用し、Vulkanなどの抽象化レイヤーをバイパスして最大スループットを実現します。純粋なC++設計により、Pythonインタープリターのオーバーヘッドとモデル変換ステップを排除しています。

## 対象ハードウェア

| コンポーネント | 仕様 |
|--------------|------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| メモリ | 128GB統合 |
| バックエンド | ROCm |

## リンク

- **メインリポジトリ** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [コミュニティに参加](https://discord.gg/dSyV646eBs)

## ライセンス

ライセンスの詳細はメインリポジトリを参照してください。

---

*アーキテクトによる刻印*
