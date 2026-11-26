"""Score Vantry's requested wordless encore from his original LPC recording."""
import argparse
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "game/assets/audio/companion"
# Onset, source offset, played duration, transposition, relative level.
# A swung pickup, a held answer, then the little delayed low note.
SCORE = [
    (0.04, 0.06, 0.17, 0, 0.76),
    (0.27, 0.09, 0.11, 3, 0.65),
    (0.42, 0.06, 0.31, 7, 0.91),
    (0.96, 0.07, 0.25, 2, 0.71),
    (1.37, 0.12, 0.21, 0, 0.55),
]


def render(destination: Path, score=SCORE):
    with wave.open(str(BANK / "acknowledgement.wav"), "rb") as original:
        assert (original.getnchannels(), original.getsampwidth()) == (1, 2)
        rate = original.getframerate()
        sample = np.frombuffer(original.readframes(original.getnframes()), "<i2").astype(float)
    output = np.zeros(round((max(t + duration for t, _, duration, _, _ in score) + 0.08) * rate))
    for onset, offset, duration, semitones, level in score:
        time = np.arange(round(rate * duration)) / rate
        positions = rate * (offset + time * 2 ** (semitones / 12))
        voice = np.interp(positions, np.arange(len(sample)), sample, right=0)
        attack = np.minimum(time / 0.013, 1)
        release = np.minimum((duration - time) / 0.048, 1)
        at = round(onset * rate)
        output[at:at + len(time)] += level * attack * release * voice
    assert 0 < np.max(np.abs(output)) < 32767
    with wave.open(str(destination), "wb") as written:
        written.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        written.writeframes(np.rint(output).astype("<i2").tobytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=BANK / "encore.wav")
    render(parser.parse_args().out)
