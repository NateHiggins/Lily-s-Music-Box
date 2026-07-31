"""Build the viral seed mix and its deterministic runtime feature envelope."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def percentile_normalize(values: np.ndarray) -> np.ndarray:
    floor, ceiling = np.percentile(values, [8, 96])
    return np.clip((values - floor) / max(float(ceiling - floor), 1e-8), 0, 1)


def analyse(wav_path: Path) -> dict:
    with wave.open(str(wav_path), "rb") as source:
        sample_rate = source.getframerate()
        channels = source.getnchannels()
        raw = source.readframes(source.getnframes())
    audio = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    stereo = audio.reshape(-1, channels)
    mono = stereo.mean(axis=1)
    hop = int(sample_rate * 0.05)
    size = 4096
    window = np.hanning(size)
    freqs = np.fft.rfftfreq(size, 1.0 / sample_rate)
    bands = {
        "sub": (25, 90),
        "low": (90, 320),
        "mid": (320, 2200),
        "high": (2200, 8000),
        "air": (8000, 18000),
    }
    rows: list[dict[str, float]] = []
    spectra: list[np.ndarray] = []
    for start in range(0, max(1, len(mono) - size), hop):
        frame = mono[start:start + size]
        if len(frame) < size:
            frame = np.pad(frame, (0, size - len(frame)))
        spectrum = np.abs(np.fft.rfft(frame * window))
        power = spectrum * spectrum
        spectra.append(spectrum)
        row = {"time": start / sample_rate,
               "rms": float(np.sqrt(np.mean(frame * frame)))}
        for name, (lo, hi) in bands.items():
            selection = (freqs >= lo) & (freqs < hi)
            row[name] = float(np.sqrt(np.mean(power[selection])))
        left = stereo[start:min(start + size, len(stereo)), 0]
        right = stereo[start:min(start + size, len(stereo)), -1]
        lr = float(np.sqrt(np.mean(left * left)) - np.sqrt(np.mean(right * right)))
        row["pan"] = lr
        rows.append(row)

    for key in ["rms", *bands]:
        normalized = percentile_normalize(np.array([row[key] for row in rows]))
        for row, value in zip(rows, normalized):
            row[key] = round(float(value), 4)
    pan_scale = max(np.percentile(np.abs([row["pan"] for row in rows]), 95), 1e-8)
    flux = np.zeros(len(rows), dtype=np.float32)
    for index in range(1, len(rows)):
        positive = np.maximum(spectra[index] - spectra[index - 1], 0)
        flux[index] = float(np.sqrt(np.mean(positive * positive)))
    flux = percentile_normalize(flux)
    for index, row in enumerate(rows):
        row["time"] = round(row["time"], 3)
        row["pan"] = round(float(np.clip(row["pan"] / pan_scale, -1, 1)), 4)
        row["flux"] = round(float(flux[index]), 4)

    events = []
    last_event = -99
    for index in range(1, len(rows) - 1):
        row = rows[index]
        if row["flux"] < 0.72 or index - last_event < 3:
            continue
        dominant = max(bands, key=lambda name: row[name])
        events.append({
            "time": row["time"],
            "band": dominant,
            "strength": round(max(row["flux"], row[dominant]), 4),
            "pan": row["pan"],
        })
        last_event = index
    return {
        "version": 1,
        "frame_hz": 20,
        "duration": round(len(mono) / sample_rate, 3),
        "mix_intent": {
            "behind_the_drywall": "low structural body, centered and close",
            "the_adjacent_logic": "high spatial intrusion, widened and delayed",
        },
        "frames": rows,
        "events": events,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("behind_drywall", type=Path)
    parser.add_argument("adjacent_logic", type=Path)
    parser.add_argument("--audio-out", type=Path, required=True)
    parser.add_argument("--features-out", type=Path, required=True)
    args = parser.parse_args()
    args.audio_out.parent.mkdir(parents=True, exist_ok=True)
    args.features_out.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="orison_seed_") as temp:
        wav_path = Path(temp) / "viral_seed.wav"
        # The first source supplies physical weight. The second is widened,
        # high-passed, offset between channels, and kept just behind it.
        mix = (
            "[0:a]highpass=f=28,lowpass=f=4200,"
            "equalizer=f=145:t=q:w=0.8:g=3,volume=0.72[a];"
            "[1:a]highpass=f=170,lowpass=f=16500,"
            "stereotools=mlev=0.55:slev=1.4,"
            "adelay=0|37,volume=0.58[b];"
            "[a][b]amix=inputs=2:duration=shortest:normalize=0,"
            "acompressor=threshold=0.12:ratio=3:attack=8:release=170,"
            "alimiter=limit=0.88[out]"
        )
        run([
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(args.behind_drywall), "-i", str(args.adjacent_logic),
            "-filter_complex", mix, "-map", "[out]", "-vn",
            "-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le", str(wav_path),
        ])
        run([
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "6",
            str(args.audio_out),
        ])
        features = analyse(wav_path)
        args.features_out.write_text(
            json.dumps(features, indent=1), encoding="utf-8")
        print(
            f"Wrote {args.audio_out} and {args.features_out}: "
            f"{len(features['frames'])} frames, {len(features['events'])} events")


if __name__ == "__main__":
    main()
