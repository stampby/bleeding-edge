# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main (bleeding-edge) | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project:

1. **DO NOT** open a public issue
2. Email: security@halo-ai.studio
3. Or DM on Discord: [halo-ai](https://discord.gg/dSyV646eBs)

We take security seriously. All vulnerabilities are documented publicly after they're patched — no security through obscurity.

### Scope

This repository contains inference engine setup, benchmarks, and configuration. Security concerns include:

- **Model serving endpoints** — The MLX server and vLLM server bind to localhost by default. Do not expose to the internet without a reverse proxy and authentication.
- **Model downloads** — Models are downloaded from HuggingFace over HTTPS. Verify checksums when available.
- **ROCm/HIP** — GPU access requires `/dev/kfd` and `/dev/dri` device permissions. Only users in `render` and `video` groups should have access.
- **Pre-built binaries** — Downloaded from GitHub releases over HTTPS. Verify release signatures when available.

### Hardening

```bash
# Bind server to localhost only (default)
LD_LIBRARY_PATH=. ./server --host 127.0.0.1 --port 8090

# Use reverse proxy for remote access
# See halo-ai-core docs for Caddy/Nginx setup
```

## Previous Incidents

- **2026-04-04**: axios RAT dependency — all Discord bot tokens rotated. Documented in halo-ai-core.

---

*Designed and built by the architect.*
