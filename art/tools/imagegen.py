"""Local image generation: SDXL on this machine's GPU, nothing leaves it.

The environment lives outside the repository, in C:/devkit/imagegen (Python venv
and model cache). Any agent can run this with any Python.

    python art/tools/imagegen.py --prompt "a tin of sardines" --out <dir> --seeds 4
    python art/tools/imagegen.py --batch jobs.json --out <dir>

A batch is a JSON array of {"id", "prompt", "negative"?, "seeds"?, "width"?,
"height"?, "steps"?}. Each image is written as <id>_s<seed>.png beside a
<id>_s<seed>.json holding the prompt, seed and model, so a result can be repeated.
Existing outputs are skipped, so a stopped batch resumes.

Generation is a GPU task on the Godot lane (RUL-009): each slice of images takes
the lane through tools/lane.ps1 and lets go, so it queues first come, first served
with Godot runs, never shares video memory with one, and a long image batch goes
to the back of the queue after every slice.

Generated images are drafts. A person or agent looks at every one before it is
used. RUL-008 still holds: no letters, numbers, words or logos in a generated
image, and lettering is live text. RUL-007 still holds: no reference photograph
goes in.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
LANE = ROOT / "tools/lane.ps1"
HOME = pathlib.Path(os.environ.get("ORISON_IMAGEGEN_HOME", "C:/devkit/imagegen"))
VENV_PYTHON = HOME / "venv/Scripts/python.exe"
MODEL = "stabilityai/stable-diffusion-xl-base-1.0"
SLICE_IMAGES = 24
SLICE_TIMEOUT_SECONDS = 900
LANE_WAIT_MINUTES = 240
DEFAULT_NEGATIVE = ("text, letters, words, numbers, writing, caption, signature, watermark, logo, label, "
                    "photograph, 3d render, colour, blurry")


def load_pipeline():
    import torch
    from diffusers import StableDiffusionXLPipeline
    pipe = StableDiffusionXLPipeline.from_pretrained(MODEL, torch_dtype=torch.float16, variant="fp16",
                                                     use_safetensors=True, local_files_only=True)
    pipe.to("cuda")
    pipe.vae.enable_tiling()
    pipe.set_progress_bar_config(disable=True)
    return pipe


def run_slice(todo: list[dict], out: pathlib.Path) -> int:
    """Inside the lane and the venv: make these images."""
    os.environ.update(HF_HOME=str(HOME / "hf"), HF_HUB_OFFLINE="1", PYTHONIOENCODING="utf8")
    import torch
    pipe = load_pipeline()
    for n, job in enumerate(todo, 1):
        negative = job.get("negative", DEFAULT_NEGATIVE)
        seed, steps = int(job["seed"]), int(job.get("steps", 30))
        width, height = int(job.get("width", 1024)), int(job.get("height", 768))
        started = time.monotonic()
        image = pipe(job["prompt"], negative_prompt=negative, width=width, height=height,
                     num_inference_steps=steps, guidance_scale=float(job.get("guidance", 7.0)),
                     generator=torch.Generator("cuda").manual_seed(seed)).images[0]
        stem = out / f"{job['id']}_s{seed}"
        image.save(stem.with_suffix(".png"))
        stem.with_suffix(".json").write_text(json.dumps(
            {"model": MODEL, "prompt": job["prompt"], "negative": negative, "seed": seed, "steps": steps,
             "width": width, "height": height}, indent=1) + "\n", encoding="utf8")
        print(f"[{n}/{len(todo)}] {stem.name} {time.monotonic() - started:.1f}s", flush=True)
    return 0


def run_through_lane(jobs: list[dict], out: pathlib.Path, seeds: int, log_dir: pathlib.Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    todo = [dict(job, seed=seed) for job in jobs for seed in range(int(job.get("seeds", seeds)))
            if not (out / f"{job['id']}_s{seed}.png").exists()]
    print(f"{len(todo)} images to make, {len(jobs)} jobs", flush=True)
    for start in range(0, len(todo), SLICE_IMAGES):
        part = todo[start:start + SLICE_IMAGES]
        with tempfile.TemporaryDirectory() as scratch:
            slice_file = pathlib.Path(scratch) / "slice.json"
            slice_file.write_text(json.dumps(part), encoding="utf8")
            runs = pathlib.Path(scratch) / "runs.json"
            runs.write_text(json.dumps([{
                "gpu": [str(VENV_PYTHON), str(pathlib.Path(__file__).resolve()),
                        "--lane-slice", str(slice_file), "--out", str(out)],
                "scene": f"imagegen: {len(part)} images",
                "log": str(log_dir / f"imagegen_{start:05d}.log"),
                "timeout": SLICE_TIMEOUT_SECONDS,
            }]), encoding="utf8")
            code = subprocess.call(["pwsh", "-NoProfile", "-File", str(LANE), "batch", "-BatchFile", str(runs),
                                    "-WaitMinutes", str(LANE_WAIT_MINUTES)])
        if code != 0:
            print(f"stopped at image {start}: lane exit {code}; run again to resume", flush=True)
            return code
        print(f"{min(start + SLICE_IMAGES, len(todo))}/{len(todo)} done", flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--prompt")
    parser.add_argument("--id", default="image")
    parser.add_argument("--batch", type=pathlib.Path)
    parser.add_argument("--out", type=pathlib.Path, required=True)
    parser.add_argument("--seeds", type=int, default=1)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--lane-slice", type=pathlib.Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.lane_slice:
        return run_slice(json.loads(args.lane_slice.read_text(encoding="utf8")), args.out)
    if bool(args.prompt) == bool(args.batch):
        parser.error("give exactly one of --prompt or --batch")
    if not VENV_PYTHON.exists():
        sys.exit(f"no environment at {HOME}; see tools/PIPELINE_TOOLS.md")
    if args.batch:
        jobs = json.loads(args.batch.read_text(encoding="utf8"))
    else:
        jobs = [{"id": args.id, "prompt": args.prompt, "width": args.width, "height": args.height}]
    return run_through_lane(jobs, args.out, args.seeds, args.out / "logs")


if __name__ == "__main__":
    sys.exit(main())
