"""Profile candidate soundtrack clips using ffmpeg + NumPy only."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np


RATE = 8000


def decode(path: Path) -> np.ndarray:
    proc = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path), "-vn", "-ac", "1",
            "-ar", str(RATE), "-f", "f32le", "-",
        ],
        check=True,
        capture_output=True,
    )
    return np.frombuffer(proc.stdout, dtype="<f4")


def profile(path: Path) -> dict:
    audio = decode(path)
    if not audio.size:
        return {"file": path.name, "error": "no audio"}
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio * audio)))
    frame = 1024
    hop = 256
    count = max(1, 1 + (len(audio) - frame) // hop)
    spectra = []
    energy = []
    window = np.hanning(frame).astype(np.float32)
    for i in range(count):
        chunk = audio[i * hop:i * hop + frame]
        if len(chunk) < frame:
            chunk = np.pad(chunk, (0, frame - len(chunk)))
        mag = np.abs(np.fft.rfft(chunk * window))
        spectra.append(mag)
        energy.append(float(np.sqrt(np.mean(chunk * chunk))))
    spec = np.asarray(spectra)
    freqs = np.fft.rfftfreq(frame, 1 / RATE)
    denom = np.maximum(spec.sum(axis=1), 1e-9)
    centroid = float(np.mean((spec * freqs).sum(axis=1) / denom))
    cumulative = np.cumsum(spec, axis=1)
    roll_idx = np.argmax(cumulative >= cumulative[:, -1:] * 0.85, axis=1)
    rolloff = float(np.mean(freqs[roll_idx]))
    norm = spec / np.maximum(np.linalg.norm(spec, axis=1, keepdims=True), 1e-9)
    flux = float(np.mean(np.maximum(0.0, np.diff(norm, axis=0)).sum(axis=1)))
    env = np.asarray(energy)
    env = np.maximum(0.0, env - np.convolve(env, np.ones(9) / 9, mode="same"))
    env -= env.mean()
    fps = RATE / hop
    lo = max(1, int(fps * 60 / 180))
    hi = min(len(env) - 1, int(fps * 60 / 55))
    if hi > lo and np.any(env):
        corr = np.correlate(env, env, mode="full")[len(env) - 1:]
        lag = lo + int(np.argmax(corr[lo:hi + 1]))
        tempo = float(60 * fps / lag)
    else:
        tempo = 0.0
    dynamic = float(np.percentile(energy, 95) - np.percentile(energy, 20))
    return {
        "file": path.name,
        "seconds": round(len(audio) / RATE, 2),
        "rms_db": round(20 * np.log10(max(rms, 1e-9)), 2),
        "peak_db": round(20 * np.log10(max(peak, 1e-9)), 2),
        "crest_db": round(20 * np.log10(max(peak / max(rms, 1e-9), 1e-9)), 2),
        "centroid_hz": round(centroid),
        "rolloff_hz": round(rolloff),
        "flux": round(flux, 4),
        "dynamic": round(dynamic, 4),
        "tempo_est": round(tempo, 1),
    }


def main() -> None:
    root = Path(sys.argv[1])
    result = [profile(path) for path in sorted(root.glob("*.mp4"))]
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
