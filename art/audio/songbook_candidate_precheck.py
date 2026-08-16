# Songbook candidate processing: one command from a Gemini .mp4 to the
# objective pre-checks, derived files and a MANIFEST scaffold.
#
# This is the "agent processes any new candidate within the day" step of
# design/ORISON_SONGBOOK_BRIDGE_PLAN.md (Days 2-3), matching the checks
# recorded in the existing manifests: duration vs spec, meter/tempo by onset
# autocorrelation, ending behavior, sub-50 Hz level, loudness, a mid-piece
# dropout scan, and the x1.335 gain-matched return preview + listening copy.
#
#   python songbook_candidate_precheck.py New_Candidate.mp4 \
#       [--spec-duration 161] [--spec-bpm 96] [--spec-meter 3]
#
# Ears outrank all of it: these are pre-checks, not a verdict. Audio outputs
# stay uncommitted; the manifest scaffold commits once filled in.

import argparse
import os
import re
import subprocess
import sys
import wave

import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PINNED_FF = os.path.expandvars(r"%LOCALAPPDATA%\claude\ffmpeg71\ffmpeg.exe")
FF = PINNED_FF if os.path.isfile(PINNED_FF) else "ffmpeg"

FPS = 100          # onset-envelope frame rate
WIN = 2048         # analysis window at 48 kHz


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def load_mono(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2 and w.getframerate() == 48000
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
        data = data.reshape(-1, w.getnchannels()).mean(axis=1)
    return data.astype(np.float32) / 32768.0


def onset_envelope(x):
    hop = 48000 // FPS
    n = (len(x) - WIN) // hop
    frames = np.lib.stride_tricks.as_strided(
        x, shape=(n, WIN), strides=(x.strides[0] * hop, x.strides[0]))
    mags = np.abs(np.fft.rfft(frames * np.hanning(WIN), axis=1))
    logm = np.log1p(1000 * mags)
    flux = np.maximum(0, np.diff(logm, axis=0)).sum(axis=1)
    return flux - flux.mean(), mags


def autocorr(env, max_lag_s=4.0):
    n = int(max_lag_s * FPS)
    ac = np.correlate(env, env, "full")[len(env) - 1:len(env) - 1 + n]
    return ac / ac[0]


def meter_report(env, spec_bpm, spec_meter):
    ac = autocorr(env)
    quarter = 60.0 / spec_bpm                       # spec quarter period, s
    lag = lambda s: ac[int(round(s * FPS))]
    bar3, bar2, bar4 = lag(3 * quarter), lag(2 * quarter), lag(4 * quarter)
    # dominant periodicity between 0.25 s and 3 s, for the report
    lo, hi = int(0.25 * FPS), int(3.0 * FPS)
    peak = lo + int(np.argmax(ac[lo:hi]))
    dom_s = peak / FPS
    spec_bar = spec_meter * quarter
    on_spec = (lag(quarter) > 0.15 and bar3 > max(bar2, bar4)
               if spec_meter == 3 else
               lag(quarter) > 0.15 and max(bar2, bar4) > bar3)
    return {
        "dominant_s": dom_s,
        "quarter_r": lag(quarter), "bar2_r": bar2, "bar3_r": bar3,
        "bar4_r": bar4, "spec_bar_s": spec_bar, "on_spec": on_spec,
    }


def band_report(mags):
    freqs = np.fft.rfftfreq(WIN, 1 / 48000)
    power = (mags ** 2).mean(axis=0)
    sub = power[freqs < 50].sum()
    full = power.sum()
    return 10 * np.log10(full / max(sub, 1e-12))


def ending_report(x):
    hop = 4800  # 100 ms
    rms = np.sqrt(np.maximum(
        (x[: len(x) // hop * hop].reshape(-1, hop) ** 2).mean(axis=1), 1e-12))
    db = 20 * np.log10(rms)
    floor = np.percentile(db, 95) - 55
    above = np.nonzero(db > floor)[0]
    end_s = (above[-1] + 1) / 10 if len(above) else 0
    tail_s = len(db) / 10 - end_s
    last6 = db[max(0, int(end_s * 10) - 60):int(end_s * 10)]
    return end_s, tail_s, last6[:10].mean(), last6[-10:].mean()


def dropout_scan(x, end_s):
    hop = 12000  # 250 ms
    rms = np.sqrt(np.maximum(
        (x[: len(x) // hop * hop].reshape(-1, hop) ** 2).mean(axis=1), 1e-12))
    db = 20 * np.log10(rms)
    med = np.median(db)
    quiet = db < med - 25
    out, i = [], 0
    while i < len(quiet):
        if quiet[i]:
            j = i
            while j < len(quiet) and quiet[j]:
                j += 1
            s, e = i * 0.25, j * 0.25
            if e - s >= 0.8 and s > 3 and e < end_s - 3:
                out.append((s, e))
            i = j
        else:
            i += 1
    return out


def loudness(path):
    r = subprocess.run([FF, "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace").stderr
    i = float(re.findall(r"I:\s*(-?[\d.]+)\s*LUFS", r)[-1])
    lra = float(re.findall(r"LRA:\s*([\d.]+)\s*LU", r)[-1])
    return i, lra


MANIFEST = """# ORISON SONGBOOK AUDITION MANIFEST — {stem}

*Per the House Five book (`design/ORISON_SONGBOOK_GEMINI_LYRIA_
HOUSE_FIVE.md`). Fields marked `OWNER:` need the owner's entry from
the Gemini UI or their audition; everything else verified locally
by `songbook_candidate_precheck.py`, {date}.*

```
track id:                  OWNER: which prompt ran?
promptbook revision:       OWNER: revision current at generation
prompt used:               OWNER: verbatim / note any edits
score attached:            OWNER: confirm (list pages, or "none")
historical recordings:     NONE USED — OWNER confirm: ____
gemini/lyria product:      OWNER: app tier / model shown by UI
model displayed:           OWNER:
generation date:           OWNER: (file mtime {mtime})
output filename:           {src}
length cap encountered:    OWNER:
synthid / ai disclosure:   presumed embedded — OWNER: note the UI
                           disclosure text
legal status:              OWNER: per Music Bible §13
consultation status:       OWNER:
owner audition result:     OWNER: attach the House Five rejection
                           checklist (10 items, full performance)
rejection reason:          OWNER: —
selected candidate:        OWNER: —
production decision:       OWNER: —
```

## Local objective pre-checks (not a substitute for ears)

{checks}

## Derived files (this folder; NOT for game/assets)

- `{stem}.48k.wav` — extracted audio, recipe conversion.
- `..._base_return_x1335_PREVIEW.wav` — base alone through true
  varispeed ×1.335.
- `..._PREVIEW_matched.wav` — gain-matched {gain} dB to the native
  master (gain only).
- `{stem}.NIGHTCORE_PREVIEW_x1335.mp3` — 256 kbps listening copy.

**Preview caveat:** this is the BACKING alone at ×1.335. Checklist
items 9–10 are judged only on base + scratch vocal as one complete
take (`songbook_scratch_return.py`).
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", help="Gemini .mp4 (or an already-extracted 48k wav)")
    ap.add_argument("--spec-duration", type=float, default=161.0)
    ap.add_argument("--spec-bpm", type=float, default=96.0)
    ap.add_argument("--spec-meter", type=int, default=3, choices=[2, 3, 4])
    ap.add_argument("--no-preview", action="store_true")
    a = ap.parse_args()

    src = os.path.abspath(a.src)
    stem = re.sub(r"\.48k$", "", os.path.splitext(src)[0])
    wav = src if src.endswith(".48k.wav") else f"{stem}.48k.wav"
    if src != wav:
        run([FF, "-y", "-v", "error", "-i", src, "-vn",
             "-ar", "48000", "-c:a", "pcm_s16le", wav])

    x = load_mono(wav)
    dur = len(x) / 48000
    env, mags = onset_envelope(x)
    m = meter_report(env, a.spec_bpm, a.spec_meter)
    sub_db = band_report(mags)
    end_s, tail_s, l6a, l6b = ending_report(x)
    drops = dropout_scan(x, end_s)
    lufs, lra = loudness(wav)

    dev = abs(dur - a.spec_duration) / a.spec_duration * 100
    lines = [
        f"| Check | Result |", f"|---|---|",
        f"| Duration vs spec (~{a.spec_duration:.0f}s) | {dur:.1f}s — "
        f"{dev:.1f}% off spec |",
        f"| Meter/tempo (spec {a.spec_meter}/4 at {a.spec_bpm:.0f}) | "
        f"{'ON SPEC' if m['on_spec'] else 'OFF SPEC'} — dominant periodicity "
        f"{m['dominant_s']:.3f}s; autocorr at spec quarter {m['quarter_r']:.2f}, "
        f"2-beat {m['bar2_r']:.2f} / 3-beat {m['bar3_r']:.2f} / "
        f"4-beat {m['bar4_r']:.2f} (spec bar {m['spec_bar_s']:.3f}s) |",
        f"| Ending (no fade-out) | music ends ~{end_s:.1f}s, {tail_s:.1f}s tail; "
        f"last 6s run {l6a:.1f} → {l6b:.1f} dBFS — judge close vs fade by ear |",
        f"| Sub-bass (none allowed) | sub-50 Hz {sub_db:.1f} dB under full-band "
        f"(Moonlight reference: 13.7 under; CAUTION below ~10) |",
        f"| Loudness | {lufs:.1f} LUFS integrated, LRA {lra:.1f} LU |",
        f"| Dropout scan | " + (", ".join(f"{s:.1f}–{e:.1f}s" for s, e in drops)
                                if drops else "none found") + " |",
    ]
    checks = "\n".join(lines)
    print(checks.replace(" |", "").replace("| ", ""))

    gain = ""
    if not a.no_preview:
        ret = f"{stem}.base_return_x1335_PREVIEW.wav"
        run([FF, "-y", "-v", "error", "-i", wav, "-af",
             "asetrate=48000*1.335,aresample=48000", "-c:a", "pcm_s16le", ret])
        ri, _ = loudness(ret)
        gain = f"{lufs - ri:+.1f}"
        matched = ret.replace(".wav", "_matched.wav")
        run([FF, "-y", "-v", "error", "-i", ret, "-af",
             f"volume={gain}dB", "-c:a", "pcm_s16le", matched])
        run([FF, "-y", "-v", "error", "-i", matched, "-c:a", "libmp3lame",
             "-b:a", "256k", f"{stem}.NIGHTCORE_PREVIEW_x1335.mp3"])
        print(f"preview: return {ri:.1f} LUFS, matched {gain} dB")

    mani = f"{stem}.MANIFEST.md"
    if os.path.exists(mani):
        print(f"manifest exists, NOT overwritten: {mani} — paste updated checks in")
    else:
        import datetime
        mt = datetime.datetime.fromtimestamp(os.path.getmtime(src))
        with open(mani, "w", encoding="utf-8") as f:
            f.write(MANIFEST.format(
                stem=os.path.basename(stem), src=os.path.basename(src),
                date=datetime.date.today().isoformat(),
                mtime=mt.strftime("%Y-%m-%d %H:%M"), checks=checks,
                gain=gain or "n/a"))
        print(f"manifest scaffold written: {mani}")


if __name__ == "__main__":
    main()
