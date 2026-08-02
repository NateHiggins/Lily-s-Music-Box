"""Convert raw voice takes into game-loaded ogg vorbis, matched by filename.

Sources (any of .wav/.flac/.mp3/.ogg/.m4a) live gdignored in
game/assets/audio/voice/source/; the processed .ogg lands beside them in
game/assets/audio/voice/ and is committed. A take is skipped when its
output is already newer than its source. Every encode is verified by
self-decoding, per the hard lesson of the Theora encoder that could not
read its own output.

    python art/tools/import_voice_takes.py
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "game", "assets", "audio", "voice", "source")
OUT = os.path.join(ROOT, "game", "assets", "audio", "voice")
EXTS = (".wav", ".flac", ".mp3", ".ogg", ".m4a")
# Same pin as build_tv_clips.py. The 8.1.2 Theora bug is video-side, but a
# verified toolchain beats a probably-fine one.
FFMPEG = os.path.expandvars(r"%LOCALAPPDATA%\claude\ffmpeg71\ffmpeg.exe")
if not os.path.exists(FFMPEG):
    FFMPEG = shutil.which("ffmpeg")


def main() -> None:
    takes = sorted(p for p in glob.glob(os.path.join(SRC, "*"))
                   if p.lower().endswith(EXTS))
    if not takes:
        print("no takes in %s" % SRC)
        return
    done = skipped = 0
    for src in takes:
        take_id = os.path.splitext(os.path.basename(src))[0]
        dst = os.path.join(OUT, take_id + ".ogg")
        if os.path.exists(dst) and \
                os.path.getmtime(dst) >= os.path.getmtime(src):
            skipped += 1
            continue
        subprocess.run(
            [FFMPEG, "-y", "-v", "error", "-i", src, "-vn", "-ac", "1",
             "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5",
             "-af", "loudnorm=I=-19:TP=-1.5", dst],
            check=True)
        verify = subprocess.run(
            [FFMPEG, "-v", "error", "-i", dst, "-f", "null", "-"],
            capture_output=True, text=True)
        if verify.returncode != 0 or verify.stderr.strip():
            sys.exit("SELF-DECODE FAILED for %s:\n%s" % (dst, verify.stderr))
        print("imported %s" % os.path.basename(dst))
        done += 1
    print("%d imported, %d up to date" % (done, skipped))


if __name__ == "__main__":
    main()
