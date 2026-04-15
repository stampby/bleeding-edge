🌐 [English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [日本語](README.ja.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [Русский](README.ru.md) | [**हिन्दी**](README.hi.md) | [العربية](README.ar.md)

# bleeding-edge

## MLX Engine ROCm — AMD Strix Halo पर LLM इंफरेंस

AMD Strix Halo (gfx1151) के लिए शुद्ध C++ LLM इंफरेंस इंजन। 128GB एकीकृत मेमोरी। Vulkan llamacpp से 83% तेज।

## प्रदर्शन

```
  Vulkan llamacpp    82.5 tok/s   ████████████████░░░░░░░░░░░░░░░
  vLLM ROCm         116.7 tok/s   ███████████████████████░░░░░░░░
  MLX ROCm          151.2 tok/s   ██████████████████████████████▌
```

Qwen3-0.6B पर **151.2 tok/s** — AMD सिलिकॉन पर निर्णायक बेंचमार्क।

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
