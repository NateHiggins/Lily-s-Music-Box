"""Bake Vantry's two readings from the witnessed timing of Cal's word."""
import argparse
import hashlib
import subprocess
from pathlib import Path

import numpy as np
from scipy import ndimage, signal
from scipy.io import wavfile

RATE = 24000
SOURCE = "7745bac4973b03e0b025f71c1818f8c7967dd8d07c6d3aa33c88944ac9ebb112"


def decode_word(source):
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE:
        raise ValueError("Cal's take changed. Check the word boundaries before baking.")
    raw = subprocess.check_output([
        "ffmpeg", "-nostdin", "-v", "error", "-i", str(source), "-ss", "7.52",
        "-t", "0.40", "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-",
    ])
    return np.frombuffer(raw, "<f4").astype(float)


def pitch_track(word):
    window = round(.036 * RATE)
    padded = np.pad(word, window // 2)
    times, pitches, strengths = [], [], []
    for start in range(0, len(word), round(.005 * RATE)):
        frame = padded[start:start + window]
        frame = (frame - frame.mean()) * np.hanning(window)
        ac = signal.correlate(frame, frame, method="fft")[window - 1:]
        low, high = RATE // 285, RATE // 72
        lag = low + np.argmax(ac[low:high])
        times.append(start / RATE)
        pitches.append(RATE / lag)
        strengths.append(ac[lag] / max(ac[0], 1e-10))
    voiced = np.array(strengths) > .44
    if voiced.sum() < 4:
        raise ValueError("Too little voiced material to trace the speaker's inflection.")
    t = np.arange(len(word)) / RATE
    pitch = np.interp(t, np.array(times)[voiced], np.array(pitches)[voiced])
    confidence = np.interp(t, times, np.clip((np.array(strengths) - .23) / .44, 0, 1))
    return pitch / np.median(np.array(pitches)[voiced]), confidence


def cabinet(word, borrowed):
    contour, confidence = pitch_track(word)
    duration = len(word) / RATE
    t = np.arange(round(RATE * (.47 if borrowed else .67))) / RATE
    # Keep the resident's relative inflection for the first impression. Later
    # Vantry leans on the first syllable and lets his last nasal settle.
    source_t = np.interp(t / t[-1], [0, .24, .55, 1],
                         [0, .24, .55, 1] if borrowed else [0, .28, .49, 1]) * duration
    source_clock = np.arange(len(word)) / RATE
    def stretch(values):
        return np.interp(source_t, source_clock, values)
    pitch = 129 * stretch(np.clip(contour, .80, 1.28)) if borrowed else np.interp(
        t / t[-1], [0, .24, .46, .74, 1], [123, 128, 135, 118, 115])
    phase = np.cumsum(pitch) / RATE
    reed = sum(np.sin(2 * np.pi * h * phase - .21 * h) / h ** .85 for h in range(1, 58))
    noise = np.random.default_rng(53).normal(size=len(t))
    out = np.zeros_like(t)
    edges = np.geomspace(105, 6500, 25)
    for lo, hi in zip(edges, edges[1:]):
        band = signal.butter(2, [lo, hi], btype="bandpass", fs=RATE, output="sos")
        envelope = np.sqrt(ndimage.gaussian_filter1d(signal.sosfilt(band, word) ** 2, .004 * RATE))
        buzz = signal.sosfilt(band, reed)
        breath = signal.sosfilt(band, noise)
        buzz /= max(.0005, np.sqrt(np.mean(buzz ** 2)))
        breath /= max(.0005, np.sqrt(np.mean(breath ** 2)))
        mix = stretch(confidence) * np.clip((4500 - lo) / 2400, .03, 1)
        out += stretch(envelope) * (mix * buzz + (1 - mix) * breath)
    out = signal.sosfilt(signal.butter(2, [160, 4400], btype="bandpass", fs=RATE, output="sos"), out)
    for n, direction in [(int(.026 * RATE), 1), (int(.045 * RATE), -1)]:
        out[::direction][:n] *= .5 - .5 * np.cos(np.linspace(0, np.pi, n))
    return out / np.max(np.abs(out)) * .39


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--out", type=Path, required=True)
    args = cli.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    speech = Path(__file__).resolve().parents[2] / "game/assets/audio/companion/speech"
    word = decode_word(speech / "cal_dwyer__cd_open.ogg")
    for name in ["listen_cal", "listen"]:
        result = cabinet(word, borrowed=name == "listen_cal")
        wav = args.out / (name + ".wav")
        wavfile.write(wav, RATE, np.rint(result * 32767).astype("<i2"))
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "5", str(args.out / (name + ".ogg"))], check=True)


if __name__ == "__main__":
    main()
