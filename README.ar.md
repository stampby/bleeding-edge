🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [**العربية**](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — استدلال LLM على AMD Strix Halo

محرك استدلال LLM مكتوب بالكامل بلغة C++ لمعالج AMD Strix Halo (gfx1151) مع 128 جيجابايت من الذاكرة الموحدة. أسرع بنسبة 83% من Vulkan llamacpp.

## الأداء

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

**151.2 tok/s** على Qwen3-0.6B — المعيار المرجعي الحاسم على سيليكون AMD.

## لماذا bleeding-edge

- **C++ خالص** — بدون اعتماديات Python، بدون انتظار تحويل GGUF
- **ملف ثنائي جاهز** — إعداد في 30 ثانية
- **أسرع بنسبة 83%** من Vulkan llamacpp على نفس الجهاز
- **AMD Strix Halo gfx1151** — 128 جيجابايت ذاكرة موحدة
- **ROCm أصلي** — وصول مباشر للعتاد، بدون طبقات تجريد

## البداية السريعة

```bash
# تحميل الملف الثنائي الجاهز
# بدء الاستدلال في 30 ثانية
```

راجع [الملف التمهيدي الرئيسي](README.md) للحصول على تعليمات التثبيت الكاملة.

## البنية

يستخدم هذا المحرك ROCm مباشرة على سيليكون AMD Strix Halo، متجاوزاً طبقات التجريد مثل Vulkan لتحقيق أقصى إنتاجية. يزيل تصميم C++ الخالص عبء مترجم Python وخطوات تحويل النماذج.

## العتاد المستهدف

| المكون | المواصفات |
|--------|----------|
| APU | AMD Strix Halo |
| GPU | gfx1151 |
| الذاكرة | 128 جيجابايت موحدة |
| الواجهة الخلفية | ROCm |

## الروابط

- **المستودع الرئيسي** : [stampby/bleeding-edge](https://github.com/stampby/bleeding-edge)
- **Halo AI Core** : [stampby/halo-ai-core](https://github.com/stampby/halo-ai-core)
- **Discord** : [انضم إلى المجتمع](https://discord.gg/dSyV646eBs)

## الترخيص

راجع المستودع الرئيسي لتفاصيل الترخيص.

---

*مختوم من قبل المعماري*
