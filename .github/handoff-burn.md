# Handoff: MLX Engine Full Burn

## What happened
- GPU is page-faulting on hipBLASLt calls (UTCL2 permission fault, gfxhub)
- Server starts, model loads (651 MB), crashes on first inference
- Needs reboot to clear GPU state
- 5 page faults in dmesg, machine up 10+ hours

## What to do
1. **Reboot strixhalo** — GPU VM page tables are corrupted
2. After reboot, start the MLX server:
   ```bash
   export LD_LIBRARY_PATH=~/mlx-engine-bin:/opt/rocm/lib
   nohup ~/mlx-engine-bin/server --port 8091 --host 0.0.0.0 > /tmp/mlx-burn-server.log 2>&1 &
   ```
3. Run the burn script from `~/bleeding-edge/burn-remote.sh` (or rewrite to run locally since you're on strixhalo)
4. **13 models to test**, 5 runs each, 2 warmup, 256 tokens
5. Results go to `~/bleeding-edge/results/`

## Models
All cached at `~/.cache/huggingface/hub/`:
- Qwen3-0.6B/1.7B/4B/8B-4bit (should all pass)
- Phi-4-mini-instruct-4bit (should pass)
- Qwen3-Coder-Next-4bit (should pass — MoE, ~26.7 tok/s expected)
- Llama-3.2-1B/3B-Instruct-4bit (NEW — not benchmarked yet)
- gemma-3-4b-it-4bit (NEW)
- Qwen2.5-72B-Instruct-4bit (previously failed warmup)
- Qwen3.5-122B-A10B-4bit (previously failed warmup — MoE)
- Falcon-E-3B-1.58bit (previously failed warmup — bitnet)
- bitnet-b1.58-2B-4T (previously failed warmup — bitnet)

## Previous passing results (for comparison)
| Model | tok/s | from |
|-------|------:|------|
| Qwen3-0.6B-4bit | 151.2 | mlx-results.json |
| Qwen3-1.7B-4bit | 66.4 | mlx-results.json |
| Qwen3-4B-4bit | 46.9 | mlx-results.json |
| Qwen3-8B-4bit | 21.7 | mlx-results.json |
| Phi-4-mini-instruct-4bit | 38.3 | mlx-results.json |
| Qwen3-Coder-Next-4bit | 26.7 | mlx-results.json |

## What was done this session (ryzen)
- bleeding-edge benchmark inconsistencies fixed and pushed (commit 3f2ace7)
- lemonade-sdk/lemonade#1642 filed (MLX Engine ROCm backend proposal)
- PR #1537 commented (vLLM ROCm gfx1151 results)
- lemon-mlx-engine#2 replied to Geramy about compiler/CI build
- gh CLI authenticated on ryzen via headless Bun.WebView
- Bun 1.3.12 installed on ryzen

## After burn completes
- Update `~/bleeding-edge/benchmarks/mlx/mlx-results.json` with new results
- Update `~/bleeding-edge/results/RESULTS-20260415.csv`
- Commit and push to stampby/bleeding-edge
- Post results to lemon-mlx-engine repo (for khosravipasha)
