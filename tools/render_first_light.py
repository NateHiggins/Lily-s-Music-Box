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


def game_signature():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT)

    digest = hashlib.sha256(git("rev-parse", "HEAD:game").strip())
    changed = git("diff", "--name-only", "-z", "HEAD", "--", "game")
    untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", "game")
    for name in sorted(set((changed + untracked).split(b"\0")) - {b""}):
        path = ROOT / os.fsdecode(name)
        digest.update(b"\0" + name + b"\0" + (sha(path).encode() if path.is_file() else b"deleted"))
    return digest.hexdigest()


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


def avi_budget(width, height, frames, fps, reference=None):
    # The pinned MJPEG writer uses 32-bit RIFF chunk sizes and index offsets.
    # Each frame has two chunks and two index entries; allow 32-bit stereo PCM.
    peak_jpeg = width * height * 4
    if reference:
        delivery = json.loads((reference.parent.parent / "delivery.json").read_bytes())
        if (delivery.get("scene") != SCENE or delivery.get("native_format") != "avi"
                or delivery.get("native_game_sha256") != game_signature()
                or delivery.get("native_avi_sha256") != sha(reference)):
            raise ValueError("Use the verified native AVI from the same First Light game sources")
        streams = probe(reference)
        video = next((s for s in streams if s["codec_type"] == "video"), {})
        if (video.get("codec_name"), video.get("width"), video.get("height")) != ("mjpeg", width, height):
            raise ValueError("AVI reference must be a native MJPEG take at the requested resolution")
        output = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_packets", "-show_entries", "packet=size", "-of", "csv=p=0", str(reference)], text=True)
        sizes = [int(line) for line in output.splitlines()]
        if len(sizes) < 12:
            raise ValueError("Use at least 12 representative AVI frames covering the shot")
        peak_jpeg = math.ceil(max(sizes) * 1.5)
    estimated = 4096 + frames * (peak_jpeg + 49 + math.ceil(48000 * 8 / fps))
    if estimated >= (1 << 32):
        reason = ("Supply --avi-reference from a short take spanning this shot at the same resolution."
                  if not reference else "The reference-based estimate is too large. Use PNG or a shorter take.")
        raise ValueError(f"AVI estimate {estimated:,} bytes exceeds the native RIFF32 limit. {reason}")
    return estimated


def native_take(case, fmt, fps, frames, width, height):
    folder = case / "frames"
    evidence = {"native_format": fmt}
    if fmt == "avi":
        master = folder / "take.avi"
        signature = (case / "native_game.sha256").read_text().strip()
        if signature != game_signature():
            raise ValueError("Game sources changed since this native AVI capture was submitted")
        streams = probe(master)
        video = [s for s in streams if s["codec_type"] == "video"]
        audio = [s for s in streams if s["codec_type"] == "audio"]
        if (len(video) != 1 or len(audio) != 1 or video[0]["codec_name"] != "mjpeg"
                or audio[0]["codec_name"] not in ("pcm_s16le", "pcm_s32le")
                or video[0]["avg_frame_rate"] != f"{fps}/1"
                or (video[0]["width"], video[0]["height"]) != (width, height)
                or master.stat().st_size >= 1 << 32):
            raise ValueError(f"Unexpected native MJPEG/PCM AVI: {streams}")
        inputs = ["-i", str(master)]
        audio_map = "0:a:0"
        evidence.update(native_avi_sha256=sha(master), native_game_sha256=signature)
    else:
        sequence = sorted(folder.glob("*.png"))
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
        (master,) = folder.glob("*.wav")
        pattern = str(folder / (prefix + f"%0{len(number)}d.png"))
        inputs = ["-framerate", str(fps), "-start_number", str(start), "-i", pattern, "-i", str(master)]
        audio_map = "1:a:0"
        evidence.update(first_png_sha256=sha(sequence[0]), last_png_sha256=sha(sequence[-1]))
    # Hash the decoded native image planes. This catches an AVI with a stale
    # header count and damaged or truncated MJPEG frames before delivery.
    checked = subprocess.check_output(["ffmpeg", "-nostdin", "-v", "error", "-xerror", *inputs,
        "-map", "0:v:0", "-fps_mode", "passthrough", "-f", "framehash", "-hash", "sha256", "-"], text=True)
    rows = [line.split(",") for line in checked.splitlines() if line and not line.startswith("#")]
    if (len(rows) != frames or any(int(r[2]) != i or int(r[4]) <= 0 for i, r in enumerate(rows))
            or not re.search(rf"(?m)^#dimensions 0:\s*{width}x{height}\s*$", checked)):
        raise ValueError(f"Decoded native frames disagree with the requested {frames} at {width}x{height}")
    evidence.update(native_decoded_frames=len(rows), first_decoded_sha256=rows[0][-1].strip(),
                    last_decoded_sha256=rows[-1][-1].strip())
    return inputs, audio_map, master, evidence


def finish(case, fps, frames, width, height, fmt="png"):
    log = case / "capture.log"
    receipt = json.loads((case / "capture.log.receipt.json").read_bytes())
    text = log.read_text(encoding="utf-8-sig", errors="replace")
    if (receipt["scene"] != SCENE or not receipt["windowed"] or not receipt["execution"]["completed"]
            or receipt["execution"]["exit_code"] or receipt["execution"]["timed_out"]
            or any(receipt["log"][k] for k in ("fail_count", "script_error_count", "stale_cache_suspect"))
            or f"FIRST LIGHT: PASS frames={frames} " not in text or "Vulkan" not in text):
        raise ValueError(f"Capture did not complete cleanly. Inspect {log}.")
    inputs, audio_map, master, evidence = native_take(case, fmt, fps, frames, width, height)
    tracks = {"master": measure_audio(master)}
    for bus in STEMS:
        tracks[bus] = measure_audio(case / "stems" / (bus + ".wav"))
    for name, track in tracks.items():
        if (track["sample_rate"] != tracks["master"]["sample_rate"] or
                track["samples_per_channel"] * fps != frames * track["sample_rate"]):
            raise ValueError(f"Picture and sound lengths disagree on {name}: {track}")
    review = case / "First-Light.mp4"
    interim = case / "First-Light.encoding.mp4"
    if review.exists() or interim.exists():
        raise FileExistsError("A viewing copy or interrupted encode already exists")
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-xerror", "-n", *inputs,
                    "-map", "0:v:0", "-map", audio_map,
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
              **evidence,
              "movie_sha256": sha(review), "run_receipt_sha256": sha(case / "capture.log.receipt.json")}
    (case / "delivery.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{review} | {frames} frames at {fps} fps, three synchronized stems and stereo master")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", type=Path, help="New report directory, preferably on the reports drive")
    parser.add_argument("--size", default="1280x720", choices=["640x360", "1280x720", "1920x1080", "3840x2160"])
    parser.add_argument("--fps", type=int, choices=[24, 60], default=24)
    parser.add_argument("--frames", type=int, help="Compress the 45-second blocking into a shorter technical proof")
    parser.add_argument("--format", choices=["avi", "png"], help="Native archive. Full-length 4K defaults to MJPEG/PCM AVI; other takes use lossless PNG/WAV.")
    parser.add_argument("--avi-reference", type=Path, help="Representative short native AVI at this resolution for the 32-bit size estimate")
    parser.add_argument("--finish", action="store_true", help="Verify and encode an existing native take")
    args = parser.parse_args()
    frames = args.frames if args.frames is not None else 45 * args.fps
    if not 12 <= frames <= 45 * args.fps:
        parser.error("Frames must be between 12 and 45 seconds at the chosen FPS")
    case = args.case.resolve()
    if case.is_relative_to(ROOT):
        parser.error("Keep capture outputs in a report directory outside the checkout")
    width, height = map(int, args.size.split("x"))
    fmt = args.format or ("avi" if width == 3840 and frames == 45 * args.fps else "png")
    if args.finish and not args.format:
        fmt = "avi" if (case / "frames/take.avi").is_file() else "png"
    if not args.finish:
        for tool in ("pwsh", "ffmpeg", "ffprobe"):
            if not shutil.which(tool):
                parser.error(f"{tool} must be on PATH")
        case.parent.mkdir(parents=True, exist_ok=True)
        if fmt == "avi":
            estimate = avi_budget(width, height, frames, args.fps, args.avi_reference)
            required = estimate * 2 + math.ceil(frames / args.fps * 48000 * 8 * len(STEMS)) + 100_000_000
            print(f"Estimated native AVI upper budget {estimate:,} bytes; encoded frame sizes vary.", flush=True)
        else:
            required = width * height * frames * 4 + 100_000_000
        if shutil.disk_usage(case.parent).free < required:
            parser.error("Insufficient free space for the archive, stems and viewing copy")
        case.mkdir()
        for folder in ("profile", "stems", "frames"):
            (case / folder).mkdir()
        if fmt == "avi":
            (case / "native_game.sha256").write_text(game_signature() + "\n", encoding="ascii")
        environment = {"APPDATA": str(case / "profile"), "ORISON_VISIBLE_GODOT": None,
                       "ORISON_FILM_STEMS": str(case / "stems"), "ORISON_FILM_FPS": str(args.fps),
                       "ORISON_FILM_FRAMES": str(frames), "ORISON_FILM_SIZE": args.size}
        if os.environ.get("ORISON_GODOT_EXE"):
            environment["ORISON_GODOT_EXE"] = os.environ["ORISON_GODOT_EXE"]
        batch = [{"scene": SCENE, "project": str(ROOT / "game"), "windowed": True, "runner": "long",
                  "timeout": 1500, "log": str(case / "capture.log"), "environment": environment,
                  "extra_args": ["--resolution", args.size, "--fixed-fps", str(args.fps),
                                 "--write-movie", str(case / "frames" / ("take." + fmt))]}]
        spec = case / "batch.json"
        spec.write_text(json.dumps(batch, indent=2) + "\n", encoding="utf-8")
        with (case / "queue.log").open("w", encoding="utf-8") as queue:
            subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "tools/lane.ps1"), "batch",
                            "-BatchFile", str(spec), "-WaitMinutes", "45"],
                           stdout=queue, stderr=subprocess.STDOUT, check=True)
    finish(case, args.fps, frames, width, height, fmt)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
