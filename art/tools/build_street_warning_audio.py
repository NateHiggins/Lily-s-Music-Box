"""Period street warnings for V2 traffic, cut from CC0 Freesound recordings.

design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md section 5. Sources are listed in
game/assets/audio/freesound/ATTRIBUTION.md and kept, as downloaded, in the
engine-ignored game/assets/audio/freesound/source/. This recipe cuts each
event, fades its ends, normalizes its peak and writes 16-bit mono 44.1 kHz
WAVs to game/assets/audio/freesound/processed/traffic/. Never hand-edit those
WAVs; rerun:

    python art/tools/build_street_warning_audio.py [--ffmpeg PATH]

- klaxon       a real old car's Klaxon, one full "ah-oo-gah" (Model A, Model T, cabs, trucks)
- bulb_horn    a vintage squeeze-bulb horn, two honks (motorcycle)
- foot_gong    a tram's struck bell, one clang and its ring (bus)
- brake_shriek an old car pulling up, drum brakes squealing (every motor)
- whip_crack   one whip crack (teamsters)
"""
from pathlib import Path
import argparse
import os
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/audio/freesound/source"
OUT = ROOT / "game/assets/audio/freesound/processed/traffic"
RATE = 44100

# key: (source file, start s, end s, fade in s, fade out s, peak dBFS)
CUTS = {
    "klaxon": ("480002__craigsmith__r18-31-old-car-ahooga-horn.mp3", 0.45, 2.35, 0.02, 0.20, -1.0),
    "bulb_horn": ("468441__breviceps__honk-vintage-bicycle-horn.mp3", 0.0, 1.10, 0.005, 0.08, -1.0),
    "foot_gong": ("448366__amazingrolo__tram-bell.mp3", 1.40, 3.90, 0.004, 0.60, -1.0),
    "brake_shriek": ("481675__craigsmith__r03-34-large-old-car-starts-and-stops-with-brake-squeaks-and-gears.mp3",
                     33.80, 36.00, 0.10, 0.40, -1.0),
    "whip_crack": ("118068__g-lamont__whip-cracks.mp3", 3.50, 4.30, 0.002, 0.30, -1.0),
}


def decode(ffmpeg, path):
    raw = subprocess.run([ffmpeg, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "s16le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0


def cut(signal, start, end, fade_in, fade_out, peak_db):
    piece = signal[int(start * RATE):int(end * RATE)].copy()
    piece -= piece.mean()
    a, b = max(1, int(fade_in * RATE)), max(1, int(fade_out * RATE))
    piece[:a] *= np.linspace(0, 1, a)
    piece[-b:] *= np.linspace(1, 0, b)
    return piece / np.max(np.abs(piece)) * 10 ** (peak_db / 20)


def write(name, signal):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(np.round(signal * 32767).astype("<i2").tobytes())
    print(name, f"{len(signal) / RATE:.2f} s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ffmpeg", default=str(Path(os.environ.get("LOCALAPPDATA", "")) / "claude/ffmpeg71/ffmpeg.exe"))
    args = parser.parse_args()
    for name, (source, *spec) in CUTS.items():
        path = SOURCE / source
        if not path.exists():
            raise SystemExit(f"missing source {path}; see ATTRIBUTION.md for its Freesound page")
        write(name, cut(decode(args.ffmpeg, path), *spec))
