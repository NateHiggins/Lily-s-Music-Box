"""Capture First Light on the shared hidden lane and verify the SDR viewing copy."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
STEMS = ("Weather", "Machinery", "Dialogue")
SCENE = "res://film/first_light.tscn"


def probe(path):
    output = subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)])
    return json.loads(output)["streams"]


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def measure_audio(path):
    stream = next(row for row in probe(path) if row["codec_type"] == "audio")
    if stream["channels"] != 2:
        raise ValueError(f"Expected stereo in {path}")
    pcm = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:a:0",
                                   "-f", "f32le", "-acodec", "pcm_f32le", "-"])
    audio = np.frombuffer(pcm, "<f4").reshape(-1, 2)
    if not np.isfinite(audio).all() or not audio.size:
        raise ValueError(f"Invalid PCM in {path}")
    peak = float(np.abs(audio).max())
    if peak < 0.00001:
        raise ValueError(f"Silent expected cue in {path}")
    active = np.flatnonzero(np.abs(audio).max(axis=1) > peak * .01)
    return {"sample_rate": int(stream["sample_rate"]), "samples_per_channel": len(audio),
            "peak_dbfs": round(20 * math.log10(peak), 2), "first_active_sample": int(active[0])}


def finish(case, fps, frames, width, height):
    log = case / "capture.log"
    receipt = json.loads((case / "capture.log.receipt.json").read_bytes())
    text = log.read_text(encoding="utf-8-sig", errors="replace")
    if (receipt["scene"] != SCENE or not receipt["windowed"] or not receipt["execution"]["completed"]
            or receipt["execution"]["exit_code"] or receipt["execution"]["timed_out"]
            or any(receipt["log"][k] for k in ("fail_count", "script_error_count", "stale_cache_suspect"))
            or f"FIRST LIGHT: PASS frames={frames} " not in text or "Vulkan" not in text):
        raise ValueError(f"Capture did not complete cleanly. Inspect {log}.")
    sequence = sorted((case / "frames").glob("*.png"))
    if len(sequence) != frames:
        raise ValueError(f"Expected {frames} images, found {len(sequence)}")
    match = re.fullmatch(r"(.*?)([0-9]+)\.png", sequence[0].name)
    if not match:
        raise ValueError(f"Unexpected MovieWriter image name: {sequence[0].name}")
    prefix, number = match.groups()
    start = int(number)
    names = [f"{prefix}{i:0{len(number)}d}.png" for i in range(start, start + frames)]
    if [p.name for p in sequence] != names:
        raise ValueError("MovieWriter sequence has a gap")
    (wav,) = (case / "frames").glob("*.wav")
    tracks = {"master": measure_audio(wav)}
    for bus in STEMS:
        tracks[bus] = measure_audio(case / "stems" / (bus + ".wav"))
    for name, track in tracks.items():
        if track["samples_per_channel"] * fps != frames * track["sample_rate"]:
            raise ValueError(f"Picture and sound lengths disagree on {name}: {track}")
    review = case / "First-Light.mp4"
    interim = case / "First-Light.encoding.mp4"
    if review.exists() or interim.exists():
        raise FileExistsError("A viewing copy or interrupted encode already exists")
    pattern = str(sequence[0].parent / (prefix + f"%0{len(number)}d.png"))
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-n", "-framerate", str(fps), "-start_number",
                    str(start), "-i", pattern, "-i", str(wav), "-map", "0:v", "-map", "1:a",
                    "-vf", ("format=gbrp,zscale=matrixin=gbr:transferin=iec61966-2-1:primariesin=709:"
                            "rangein=full:matrix=709:transfer=709:primaries=709:range=limited,format=yuv420p"), "-c:v", "libx264", "-crf", "16",
                    "-preset", "fast", "-pix_fmt", "yuv420p", "-colorspace", "bt709", "-color_primaries", "bt709",
                    "-color_trc", "bt709", "-af", f"volume={min(12.0, -2.0 - tracks['master']['peak_dbfs']):.3f}dB", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart",
                    str(interim)], check=True)
    video = next(row for row in probe(interim) if row["codec_type"] == "video")
    if (int(video["nb_frames"]), video["width"], video["height"], video["avg_frame_rate"]) != (
            frames, width, height, f"{fps}/1"):
        raise ValueError(f"Encoded picture disagrees with the take: {video}")
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(interim), "-f", "null", "-"], check=True)
    interim.rename(review)
    report = {"scene": SCENE, "frames": frames, "fps": fps, "size": [width, height], "audio": tracks,
              "first_png_sha256": sha(sequence[0]), "last_png_sha256": sha(sequence[-1]),
              "movie_sha256": sha(review), "run_receipt_sha256": sha(case / "capture.log.receipt.json")}
    (case / "delivery.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{review} | {frames} frames at {fps} fps, three synchronized stems and stereo master")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", type=Path, help="New report directory, preferably on the reports drive")
    parser.add_argument("--size", default="1280x720", choices=["640x360", "1280x720", "1920x1080", "3840x2160"])
    parser.add_argument("--fps", type=int, choices=[24, 60], default=24)
    parser.add_argument("--frames", type=int, help="Compress the 45-second blocking into a shorter technical proof")
    parser.add_argument("--finish", action="store_true", help="Verify and encode an existing native take")
    args = parser.parse_args()
    frames = args.frames if args.frames is not None else 45 * args.fps
    if not 12 <= frames <= 45 * args.fps:
        parser.error("Frames must be between 12 and 45 seconds at the chosen FPS")
    case = args.case.resolve()
    if case.is_relative_to(ROOT):
        parser.error("Keep capture outputs in a report directory outside the checkout")
    width, height = map(int, args.size.split("x"))
    if not args.finish:
        for tool in ("pwsh", "ffmpeg", "ffprobe"):
            if not shutil.which(tool):
                parser.error(f"{tool} must be on PATH")
        case.parent.mkdir(parents=True, exist_ok=True)
        if shutil.disk_usage(case.parent).free < width * height * frames * 4 + 100_000_000:
            parser.error("Insufficient free space for the lossless sequence and viewing copy")
        case.mkdir()
        for folder in ("profile", "stems", "frames"):
            (case / folder).mkdir()
        environment = {"APPDATA": str(case / "profile"), "ORISON_VISIBLE_GODOT": None,
                       "ORISON_FILM_STEMS": str(case / "stems"), "ORISON_FILM_FPS": str(args.fps),
                       "ORISON_FILM_FRAMES": str(frames), "ORISON_FILM_SIZE": args.size}
        if os.environ.get("ORISON_GODOT_EXE"):
            environment["ORISON_GODOT_EXE"] = os.environ["ORISON_GODOT_EXE"]
        batch = [{"scene": SCENE, "project": str(ROOT / "game"), "windowed": True, "runner": "long",
                  "timeout": 1500, "log": str(case / "capture.log"), "environment": environment,
                  "extra_args": ["--resolution", args.size, "--fixed-fps", str(args.fps),
                                 "--write-movie", str(case / "frames/take.png")]}]
        spec = case / "batch.json"
        spec.write_text(json.dumps(batch, indent=2) + "\n", encoding="utf-8")
        with (case / "queue.log").open("w", encoding="utf-8") as queue:
            subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "tools/lane.ps1"), "batch",
                            "-BatchFile", str(spec), "-WaitMinutes", "45"],
                           stdout=queue, stderr=subprocess.STDOUT, check=True)
    finish(case, args.fps, frames, width, height)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
