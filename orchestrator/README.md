# halo-orchestrator

GPU/NPU auto-placement for lemond. Monitors hardware state and decides which backend each model runs on.

## the idea

lemond already routes between backends (MLX, vLLM, llamacpp, FLM/NPU). But model placement is manual — you tell it where to load. The orchestrator makes that decision automatically based on:

- GPU VRAM usage (sysfs, zero overhead)
- GPU utilization %
- NPU availability
- Model size and architecture (dense vs MoE)
- Task type (LLM, STT, TTS)

## placement rules

```
Audio (whisper/kokoro)     → NPU always
MoE models                 → Vulkan llamacpp (MLX slow on MoE)
Dense ≤4B                  → NPU if available
Dense >4B                  → MLX ROCm (primary)
GPU VRAM >80%              → vLLM (better memory management)
GPU VRAM >95%              → spill to NPU/Vulkan
```

## usage

```bash
# system status — GPU, NPU, loaded models
./halo-orchestrator.sh status

# ask where a model should go (dry-run)
./halo-orchestrator.sh advise Qwen3-8B
./halo-orchestrator.sh advise Mixtral-8x22B
./halo-orchestrator.sh advise whisper-large-v3-turbo

# JSON metrics (for dashboards)
./halo-orchestrator.sh metrics

# daemon mode — continuous monitoring
./halo-orchestrator.sh daemon --poll 15
```

## architecture

```
                    ┌─────────────────┐
                    │  orchestrator   │
                    │  (this script)  │
                    └────────┬────────┘
                             │ placement decision
                    ┌────────▼────────┐
                    │    lemond       │
                    │   :13305        │
                    └──┬──┬──┬──┬────┘
                       │  │  │  │
              ┌────────┘  │  │  └────────┐
              ▼           ▼  ▼           ▼
         ┌────────┐  ┌──────┐ ┌──────┐ ┌─────┐
         │  MLX   │  │ vLLM │ │llama │ │ FLM │
         │ ROCm   │  │ ROCm │ │ .cpp │ │ NPU │
         │hipBLASLt│ │      │ │Vulkan│ │XDNA2│
         └────────┘  └──────┘ └──────┘ └─────┘
           dense      dense    MoE      small
           >4B        AWQ/GPTQ GGUF     ≤4B
           primary    fallback          audio
```

## status

**prototype** — placement logic works, lemond API integration pending.

- [x] GPU metrics via sysfs (zero overhead, no rocm-smi)
- [x] NPU detection and firmware check
- [x] Model classification (size, arch, task)
- [x] Placement decision engine
- [x] Status dashboard
- [x] JSON metrics output
- [x] Daemon mode with state file
- [ ] Wire `place` command to lemond load API
- [ ] Rebalancing (move models between backends under load)
- [ ] History/stats tracking
- [ ] Integration with halo-ai-core dashboard

## data sources

| Metric | Source | Overhead |
|--------|--------|----------|
| VRAM used/total | `/sys/.../mem_info_vram_*` | ~0 (sysfs read) |
| GPU busy % | `/sys/.../gpu_busy_percent` | ~0 |
| GTT used/total | `/sys/.../mem_info_gtt_*` | ~0 |
| GPU temp | hwmon sysfs | ~0 |
| NPU available | `/dev/accel0` | ~0 |
| NPU firmware | sysfs `fw_version` | ~0 |
| Loaded models | lemond `/v1/models` | 1 HTTP call |
