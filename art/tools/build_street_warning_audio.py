"""Period street warnings for V2 traffic, synthesized (no recordings, no downloads).

design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md section 5. Deterministic: fixed seeds,
16-bit mono 22.05 kHz WAV, rerun to regenerate. Never hand-edit the WAVs.

    python art/tools/build_street_warning_audio.py

- klaxon       motor-driven diaphragm horn, "ah-oo-gah" (Model A, cabs, trucks)
- bulb_horn    squeeze-bulb reed horn, two honks (Model T, motorcycle)
- foot_gong    floor-pedal gong, two strikes (bus, delivery wagons)
- brake_shriek drum brakes and tyres scrubbing on wet setts
- whip_crack   whip, then iron shoes skidding and harness rattle (horse-drawn)
"""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/audio/synth/traffic"
RATE = 22050


def biquad(x, kind, freq, q):
    """RBJ cookbook biquad, direct form I. kind: 'bp', 'lp' or 'hp'."""
    w = 2 * math.pi * freq / RATE
    alpha = math.sin(w) / (2 * q)
    c = math.cos(w)
    if kind == "bp":
        b = [alpha, 0.0, -alpha]
    elif kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + alpha, -2 * c, 1 - alpha]
    b = [v / a[0] for v in b]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b[0] * v + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def osc(freq_curve, shape="saw"):
    phase = np.cumsum(freq_curve) / RATE
    frac = phase - np.floor(phase)
    if shape == "saw":
        return 2 * frac - 1
    if shape == "pulse":
        return np.where(frac < 0.18, 1.0, -0.22)
    return np.where(frac < 0.5, 1.0, -1.0)


def klaxon():
    n = int(1.15 * RATE)
    t = np.arange(n) / RATE
    f = np.interp(t, [0, .22, .30, .72, .80, 1.15], [95, 300, 330, 318, 250, 150])
    f *= 1 + 0.012 * np.sin(2 * math.pi * 23 * t)
    raw = 0.6 * osc(f, "saw") + 0.5 * osc(f, "pulse")
    raw = np.tanh(2.2 * raw)
    horn = biquad(raw, "bp", 820, 2.6) + 0.7 * biquad(raw, "bp", 1850, 3.5) + 0.25 * biquad(raw, "lp", 600, .7)
    return horn * env(n, .03, .18) * np.interp(t, [0, .25, .8, 1.15], [.55, 1, 1, .6])


def bulb_horn():
    n = int(0.72 * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(4)
    gate = ((t < .23) | ((t > .31) & (t < .56))).astype(float)
    gate = biquad(gate, "lp", 60, .7)
    f = np.where(t < .27, np.interp(t, [0, .23], [395, 352]), np.interp(t, [.31, .56], [400, 348]))
    reed = osc(f, "square") * 0.7 + 0.12 * rng.standard_normal(n)
    tone = biquad(reed, "bp", 1150, 2.2) + 0.5 * biquad(reed, "bp", 560, 1.6)
    return tone * gate * env(n, .005, .05)


def foot_gong():
    n = int(1.7 * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for start in (0.0, 0.26):
        s = np.clip(t - start, 0, None)
        on = (t >= start).astype(float)
        for ratio, amp, decay in [(1.0, 1.0, 1.4), (2.76, .55, 2.6), (5.40, .3, 4.5), (8.93, .16, 7.0)]:
            out += on * amp * np.sin(2 * math.pi * 640 * ratio * s) * np.exp(-decay * s)
        out += on * 0.4 * np.exp(-90 * s) * np.sin(2 * math.pi * 3100 * s)
    return out * env(n, .002, .3)


def brake_shriek():
    n = int(1.0 * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(7)
    f = 2350 + 140 * np.sin(2 * math.pi * 5.5 * t) + 220 * t
    squeal = np.sin(2 * math.pi * np.cumsum(f) / RATE) * (0.55 + 0.45 * np.sin(2 * math.pi * 11 * t) ** 2)
    scrub = biquad(rng.standard_normal(n), "bp", 900, .8) * 0.9
    body = biquad(rng.standard_normal(n), "lp", 180, .7) * 1.4
    shape = np.interp(t, [0, .04, .7, 1.0], [0, 1, .8, 0])
    return (0.5 * squeal + scrub + body) * shape


def whip_crack():
    n = int(1.1 * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(11)
    out = np.zeros(n)
    # The crack: a supersonic tip, so a very short broadband slap.
    k = int(0.006 * RATE)
    out[:k] += biquad(rng.standard_normal(k), "hp", 1800, .7) * np.linspace(1, 0, k) * 2.2
    # Iron shoes skidding on wet setts, irregular.
    for start, pitch in [(.18, 520), (.27, 430), (.41, 610), (.49, 380), (.62, 470)]:
        s = np.clip(t - start, 0, None)
        on = (t >= start).astype(float)
        out += on * np.exp(-38 * s) * biquad(rng.standard_normal(n), "bp", pitch, 3.0) * 1.6
    scrape = biquad(rng.standard_normal(n), "bp", 1400, 1.2) * np.interp(t, [0, .18, .3, .7, 1.1], [0, 0, .5, .35, 0])
    jingle = np.zeros(n)
    for start, freq in [(.2, 4100), (.33, 5200), (.45, 4700), (.58, 3900)]:
        s = np.clip(t - start, 0, None)
        jingle += (t >= start) * np.sin(2 * math.pi * freq * s) * np.exp(-30 * s) * .25
    return out + scrape + jingle


def write(name, signal):
    peak = float(np.max(np.abs(signal)))
    data = np.round(signal / peak * 0.89 * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print(name, len(data) / RATE, "s")


if __name__ == "__main__":
    for name, build in [("klaxon", klaxon), ("bulb_horn", bulb_horn), ("foot_gong", foot_gong),
                        ("brake_shriek", brake_shriek), ("whip_crack", whip_crack)]:
        write(name, build())
