"""Compose the original Tony Rawks ska cue as a looped stereo WAV.

Run with the WAV output filename. Encode the runtime asset with
ffmpeg -i tony_rawks_ska.wav -c:a libvorbis -q:a 5 tony_rawks_ska.ogg
"""
import math
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BEAT = 60 / 168
BARS = 8
rng = np.random.default_rng(1829)
mix = np.zeros((round(RATE * BEAT * (BARS * 4)), 2))


def add(beat, sound, gain, pan=0.0):
    start = round(beat * BEAT * RATE)
    indices = (start + np.arange(sound.size)) % len(mix)
    mix[indices, 0] += sound * gain * math.sqrt(1.0 - pan)
    mix[indices, 1] += sound * gain * math.sqrt(1.0 + pan)


def time(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def pluck(note, duration, decay, partials, stretch=1.0):
    t = time(duration)
    phase = 2 * np.pi * frequency(note) * t
    sound = sum(weight * np.sin(phase * harmonic * stretch)
                for harmonic, weight in enumerate(partials, 1))
    return sound * np.minimum(1.0, t / 0.004) * np.exp(-t * decay) * np.minimum(1.0, (duration - t) / 0.02)


def brass(note, duration):
    t = time(duration)
    phase = 2 * np.pi * frequency(note) * t + 0.23 * np.sin(34 * t)
    horn = (np.sin(phase) + 0.45 * np.sin(2 * phase)
            + 0.36 * np.sin(3 * phase) + 0.21 * np.sin(5 * phase))
    return horn * np.minimum(1.0, t / 0.025) * np.minimum(1.0, (duration - t) / 0.055)


def drums(when, part, gain):
    duration = {"kick": 0.18, "snare": 0.16, "hat": 0.065, "open": 0.21}[part]
    t = time(duration)
    if part == "kick":
        phase = 2 * np.pi * (48 * t + 2.7 * (1 - np.exp(-48 * t)))
        sound = np.sin(phase) * np.exp(-23 * t)
    else:
        noise = rng.standard_normal(t.size)
        bright = np.diff(noise, prepend=noise[0])
        if part == "snare":
            sound = (0.31 * bright + 0.32 * np.sin(2 * np.pi * 178 * t)) * np.exp(-24 * t)
        else:
            sound = bright * 0.24 * np.exp((-18 if part == "open" else -66) * t)
    add(when, sound * np.minimum(1.0, t / 0.002), gain, 0.25 if part in {"hat", "open"} else 0)


# A minor, F, C and G with an eight-bar call and answer on the horns.
chords = [(57, 60, 64), (57, 60, 65), (55, 60, 64), (55, 59, 62)]
bass = [(45, 45, 52, 48), (41, 48, 53, 55), (48, 48, 55, 52), (43, 50, 55, 44)]
calls = [
    [(0, 76, 0.34), (1.5, 72, 0.28), (2.5, 74, 0.14), (3, 76, 0.23)],
    [(1, 77, 0.21), (2, 76, 0.19), (3.5, 72, 0.15)],
    [(0, 79, 0.32), (1.5, 76, 0.22), (2.5, 72, 0.27)],
    [(0.5, 74, 0.18), (2, 71, 0.26), (3, 72, 0.18), (3.5, 74, 0.15)],
    [(0, 76, 0.31), (1.5, 72, 0.24), (2.5, 74, 0.15), (3, 79, 0.24)],
    [(1, 77, 0.24), (2, 76, 0.20), (3.5, 72, 0.14)],
    [(0, 79, 0.33), (1, 76, 0.24), (2.5, 72, 0.13), (3, 76, 0.20)],
    [(0.5, 74, 0.19), (1.5, 71, 0.17), (2.5, 74, 0.19), (3, 76, 0.24)],
]

for bar in range(BARS):
    head = 4 * bar
    for count in range(4):
        beat = head + count
        guitar_notes = chords[bar % 4]
        for string, note in enumerate(guitar_notes):
            add(beat + 0.50 + string * 0.011, pluck(note + 12, 0.11, 28, (1, .42, .25, .13, .16)), 0.082, -0.32)
            add(beat + 0.51 + string * 0.009, pluck(note, 0.13, 23, (1, .20, .14), 1.001), 0.045, 0.47)
        note = bass[bar % 4][count]
        add(beat, pluck(note, 0.33, 6, (1, .30, .16, .07)), 0.34)
        if count in (0, 2):
            drums(beat, "kick", 0.50)
        else:
            drums(beat, "snare", 0.52)
        drums(beat, "hat", 0.13)
        drums(beat + 0.50, "open" if count == 3 else "hat", 0.19)
    drums(head + 2.75, "kick", 0.33)
    for when, note, duration in calls[bar]:
        add(head + when, brass(note, duration), 0.13, 0.17)
        add(head + when + 0.012, brass(note - (5 if bar % 2 else 3), duration), 0.070, -0.13)

mix = np.tanh(mix * 1.25)
pcm = (mix * (0.86 / np.max(np.abs(mix))) * 32767).astype("<i2")
with wave.open(str(Path(sys.argv[1])), "wb") as track:
    track.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
    track.writeframes(pcm.tobytes())
