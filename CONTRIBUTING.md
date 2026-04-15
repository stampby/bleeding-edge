# Contributing

## How to Help

1. **Run the benchmarks** on your hardware and report results
2. **Test models** that failed in our runs (Llama-3.2, Gemma-3, 1-bit, 32B+)
3. **Report bugs** with full hardware/software details
4. **Submit benchmark data** via issues or PRs

## Reporting Results

Open an issue with:
- GPU model and architecture (gfx1151, gfx1150, gfx110X, gfx120X)
- Memory configuration
- Kernel version
- OS/distro
- Benchmark output (use the script in `docs/replicate.md`)

## Code Standards

- Scripts: bash or Python 3.12+
- No Docker. Podman if containers are needed.
- Build from source. No Flatpak.
- All benchmarks: 5 runs, mean ± stddev

## Communication

- GitHub Issues for bugs and benchmarks
- [Discord](https://discord.gg/dSyV646eBs) for discussion
- [r/MidlifeCrisisAI](https://reddit.com/r/MidlifeCrisisAI) for write-ups

---

*Stamped by the architect.*
