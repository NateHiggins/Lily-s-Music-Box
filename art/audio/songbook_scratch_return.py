# Songbook Day-1 tool: scratch vocal -> complete take -> true-varispeed return.
#
# Implements the verified recipe in ORISON_SONGBOOK_GEMINI_LYRIA_HOUSE_FIVE.md
# ("THE RETURN — true-varispeed templates"): mix ONCE into one complete take,
# then asetrate*ratio + aresample. Tempo and pitch rise together; never pitch
# the voice separately, never formant-correct, never atempo. Loudness match is
# plain gain only, measured with ebur128.
#
# Usage (Day 1, once the owner's scratch vocal exists):
#   python songbook_scratch_return.py --base Moonlight_on_the_Dance_Floor.48k.wav \
#       --vocal scratch_vocal.wav [--offset 0.0] [--vocal-gain 0] [--ratio 1.335]
#
# Self-test (no vocal needed; reproduces the base-only preview chain):
#   python songbook_scratch_return.py --base Moonlight_on_the_Dance_Floor.48k.wav --selftest
#
# Optional, NOT CANON pending the G7 ruling (Music Bible section 5.2 currently
# refuses post-speedup additions): --rig applies a house-rig chain approximating
# the 2026-08-14 HAUNTED_FLOOR prototypes (kick bed + sidechain pump + drive/
# soft-clip + slow pitch wobble + dark echoes). The prototype's exact parameters
# were not committed; this chain aims at the documented targets (sub-60 Hz
# lifted toward -14.5 dB rel, ~-9.8 LUFS) and is audition material only.
#
# Outputs land beside the base file and stay UNCOMMITTED (audio never commits;
# manifests and docs do).

import argparse
import os
import re
import subprocess
import sys

PINNED_FF = os.path.expandvars(r"%LOCALAPPDATA%\claude\ffmpeg71\ffmpeg.exe")
HERE = os.path.dirname(os.path.abspath(__file__))
KICK = {1.335: os.path.join(HERE, "kick1335.wav"),
        1.414: os.path.join(HERE, "kick1414.wav")}


def ffmpeg_bin():
    return PINNED_FF if os.path.isfile(PINNED_FF) else "ffmpeg"


def run(args, **kw):
    print("  $", " ".join(str(a) for a in args))
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", **kw)


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries",
         "format=duration:stream=sample_rate,channels", "-of", "csv", path],
        check=True, capture_output=True, text=True).stdout
    sr = int(re.search(r"stream,(\d+)", out).group(1))
    dur = float(re.search(r"format,([\d.]+)", out).group(1))
    return sr, dur


def lufs(path):
    """Integrated loudness via ebur128 (the House Five matching method)."""
    r = subprocess.run([ffmpeg_bin(), "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    m = re.findall(r"I:\s*(-?[\d.]+)\s*LUFS", r.stderr)
    if not m:
        sys.exit(f"could not read LUFS from {path}")
    return float(m[-1])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="native-speed 48k backing wav")
    ap.add_argument("--vocal", help="scratch vocal wav (any rate; resampled to 48k)")
    ap.add_argument("--offset", type=float, default=0.0,
                    help="delay vocal start by N seconds")
    ap.add_argument("--vocal-gain", type=float, default=0.0,
                    help="vocal level in dB relative to base (mix balance only)")
    ap.add_argument("--ratio", type=float, default=1.335, choices=[1.335, 1.414])
    ap.add_argument("--rig", action="store_true",
                    help="ALSO cut a house-rig version (NOT CANON pending G7)")
    ap.add_argument("--kick-gain", type=float, default=-6.0,
                    help="rig kick bed level in dB (rig only)")
    ap.add_argument("--selftest", action="store_true",
                    help="base-only run; verifies the chain against the recipe")
    a = ap.parse_args()

    if not a.vocal and not a.selftest:
        sys.exit("need --vocal (or --selftest for a base-only chain check)")

    ff = ffmpeg_bin()
    base = os.path.abspath(a.base)
    stem = re.sub(r"\.48k$", "", os.path.splitext(base)[0])
    tag = f"x{a.ratio:.3f}".replace("0.", ".").replace(".", "", 1)  # x1335 / x1414
    sr, base_dur = probe(base)
    if sr != 48000:
        sys.exit(f"base must be 48 kHz (got {sr}); extract per the recipe first")
    print(f"base: {base_dur:.3f}s @ {sr} Hz")

    # 1. one complete take (or the base alone for the self-test)
    if a.vocal:
        vsr, vdur = probe(a.vocal)
        print(f"vocal: {vdur:.3f}s @ {vsr} Hz (offset {a.offset}s, {a.vocal_gain:+.1f} dB)")
        if vdur + a.offset < base_dur - 5:
            print(f"  WARNING: vocal covers only {vdur + a.offset:.0f}s of a "
                  f"{base_dur:.0f}s base — the checklist wants a full-length take")
        take = f"{stem}.complete_take.wav"
        delay = int(a.offset * 1000)
        run([ff, "-y", "-i", base, "-i", a.vocal, "-filter_complex",
             f"[1:a]aresample=48000,volume={a.vocal_gain}dB,"
             f"adelay={delay}|{delay}[v];"
             f"[0:a][v]amix=inputs=2:duration=first:normalize=0[m]",
             "-map", "[m]", "-c:a", "pcm_s16le", take])
    else:
        take = base
        print("selftest: using the base alone as the take")

    # 2. the return — true varispeed, the verified template verbatim
    ret = f"{stem}.take_return_{tag}.wav" if a.vocal else f"{stem}.selftest_return_{tag}.wav"
    run([ff, "-y", "-i", take, "-af",
         f"asetrate=48000*{a.ratio},aresample=48000", "-c:a", "pcm_s16le", ret])
    _, rdur = probe(ret)
    expect = base_dur / a.ratio
    ok = abs(rdur - expect) < 0.05
    print(f"return: {rdur:.3f}s (expected {expect:.3f}s) {'OK' if ok else 'MISMATCH'}")
    if not ok:
        sys.exit("return duration does not match base/ratio — chain is wrong, stopping")

    # 3. gain-match the return to the native take (plain gain only)
    native_i, ret_i = lufs(take), lufs(ret)
    gain = round(native_i - ret_i, 1)
    matched = ret.replace(".wav", "_matched.wav")
    run([ff, "-y", "-i", ret, "-af", f"volume={gain}dB", "-c:a", "pcm_s16le", matched])
    print(f"loudness: native {native_i} LUFS, return {ret_i} LUFS -> {gain:+.1f} dB gain")

    # 4. listening copy
    mp3 = matched.replace("_matched.wav", "_PREVIEW.mp3")
    run([ff, "-y", "-i", matched, "-c:a", "libmp3lame", "-b:a", "256k", mp3])

    # 5. optional house rig — audition material only until G7 is ruled
    if a.rig:
        kick = KICK[a.ratio]
        if not os.path.isfile(kick):
            sys.exit(f"missing kick bed {kick}")
        rig = f"{stem}.HAUNTED_FLOOR_take_{tag}.wav"
        run([ff, "-y", "-i", matched, "-i", kick, "-filter_complex",
             # pump the return against the kick, add the kick, drive into soft
             # clip, slow pitch wobble, dark displaced echoes
             f"[1:a]volume={a.kick_gain}dB[k];"
             f"[0:a][k]sidechaincompress=threshold=0.06:ratio=5:attack=8:release=120:makeup=4[d];"
             f"[k]lowpass=f=140[kl];"
             f"[d][kl]amix=inputs=2:duration=first:normalize=0[m];"
             f"[m]volume=10dB,asoftclip=type=atan,"
             f"vibrato=f=0.35:d=0.06,"
             f"aecho=0.7:0.5:210|440:0.22|0.13,"
             f"lowpass=f=9000[out]",
             "-map", "[out]", "-c:a", "pcm_s16le", rig])
        rig_mp3 = rig.replace(".wav", ".mp3")
        run([ff, "-y", "-i", rig, "-c:a", "libmp3lame", "-b:a", "256k", rig_mp3])
        print(f"rig: {lufs(rig)} LUFS (prototype target ~-9.8) — NOT CANON pending G7")

    print("\ndone. audio outputs stay uncommitted; log results in the MANIFEST.")


if __name__ == "__main__":
    main()
