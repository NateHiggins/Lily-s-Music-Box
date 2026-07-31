"""Build the Orison's television broadcast.

    Lily Fern and Erica Cherry's Variety Hour Marathon

The fiction is a building whose aerial picks up more than one station at
once, so this is not a playlist — it is several channels fighting over the
same signal, with the station's own idents and advertising surfacing between
them. Each source clip is a channel; between them the picture tears, rolls,
ghosts or drops out, with the next channel already bleeding through before
the cut lands.

The running order is SHUFFLED per build (`--seed` to reproduce one), so the
marathon is a different night's viewing each time the reel is regenerated.

Output is Ogg Theora, the only video format Godot 4 plays. Audio is stripped
deliberately: this project synthesises every sound at runtime and has no
audio files on disk, and a real audio bed would both break that and fight
the acoustic simulation the game is built on. If the sets should be audible,
the murmur belongs in the procedural mix.

    python art/tools/build_broadcast.py <source_dir> <out.ogv> [seed]
"""
import os
import random
import subprocess
import sys
import glob

# A television in the corner of a room. 384x288 is generous for how large it
# ever gets on screen, and the reel has to stay small enough to ship.
## 384x288 at Theora q3 broke up into blocks with magenta chroma tearing —
## pillarboxed portrait leaves only ~158 px of actual picture, so the codec
## was being asked to carry the whole programme in a very small raster.
## Bigger frame, higher quality; it is still a television across a room.
## PORTRAIT, because the footage is. Every clip is roughly 9:16, so a
## landscape raster could only ever crop it or pad it — both were tried and
## both read as a broken display. 320x576 is 0.556 against the sources'
## 0.550, so the fit is very nearly native and the televisions are built to
## match it rather than the other way round.
W, H, FPS = 320, 576, 24
## Sources arrive at four different sizes — 704x1280, 576x1048, 480x872 and
## one landscape 1048x576 — so the crop cannot be hardcoded. Scale to cover
## 4:3 and take the centre: correct for any aspect, and on the portrait
## clips it discards the top and bottom bands where the generator's
## watermark usually sits.
## Fill the glass and lose the top and bottom. Pillarboxing kept every clip
## whole but left a portrait picture stranded in a wide black raster, which
## on a small in-world screen reads as a broken display rather than as
## letterboxing. A television fills its tube; the framing loss is the price
## and it is the right one.
FIT = ("scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d"
       % (W, H, W, H))
## Audio layout every segment must share, or the concat demuxer refuses.
ARATE, ACH = 44100, 2
LOOK = "eq=saturation=0.72:contrast=1.10:brightness=-0.03,noise=alls=7:allf=t+u"
## Programmes run in full. Chopping every clip to a few seconds made a
## channel-hopping montage rather than an evening's television, and the
## interference only lands as interference if what it interrupts was
## settled first.
GLITCH_EVERY = 4          # roughly one cut in four loses the signal
GLITCH = 0.5
FONT = "C\\:/Windows/Fonts/arialbd.ttf"

SHOW = "LILY FERN & ERICA CHERRY'S"

## Between-programme idents. Short, and shouted, the way they were.
BUMPERS = [
    ("WE'LL BE", "RIGHT BACK"),
    ("STAY TUNED", ""),
    ("DO NOT ADJUST", "YOUR SET"),
    ("ORISON", "CHANNEL 4"),
    ("ONE MOMENT", "PLEASE"),
    ("WE ARE", "EXPERIENCING", "DIFFICULTY"),
]

## The advertising is the building talking. Every one of these is a line the
## game already owns — the portal rules the residents' cases resolve to, and
## the support line the player works — sold back to them as a slogan between
## programmes. A resolved case's aphorism turning up as an advert is the
## cheapest genuinely unsettling thing in the reel.
ADVERTS = [
    ("PLEASE REMAIN", "ON THE LINE"),
    ("NIGHTLINE REMOTE SUPPORT", "OPERATORS ARE WAITING"),
    ("SILENCE DOES NOT", "REQUIRE ANNOTATION"),
    ("SOME THINGS ARE", "NOT REPAIRABLE"),
    ("GOOD ENOUGH", "CAN HOLD"),
    ("NOT EVERY ALARM", "IS YOURS"),
    ("CONTRADICTION", "IS SURVIVABLE"),
    ("PRESENCE IS NOT", "PRESERVATION"),
    ("A VISIBLE REPAIR", "IS STILL A REPAIR"),
    ("DEPARTURE", "IS A DECISION"),
    ("THE ORISON APARTMENTS", "A GOOD ADDRESS SINCE 1927"),
]


def run(args):
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0:
        print("FFMPEG FAILED:", " ".join(args[:6]), "...")
        print(proc.stderr[-1200:])
        sys.exit(1)


def esc(text):
    return text.replace("'", "’").replace(":", "\\:")


def card(lines, out, seconds, bg, ink, size, sub=""):
    """A caption card, degraded to match the rest of the transmission.

    Each line is fitted to the frame independently. drawtext will happily
    render past both edges — the show's own title came back as
    "Y FERN & ERICA CHERR" — so the size is capped by the line's length
    rather than trusted from the caller.
    """
    draws = []
    body = [l for l in lines if l]
    # Arial Bold runs about 0.58 em per character; keep to 92% of the frame.
    sizes = [max(11, min(size, int(W * 0.92 / (0.58 * max(1, len(l))))))
             for l in body]
    gap = 12
    total_h = sum(sizes) + gap * (len(body) - 1)
    offset = 0
    for i, line in enumerate(body):
        y = "(h-%d)/2+%d" % (total_h, offset)
        offset += sizes[i] + gap
        draws.append(
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=%d:"
            "x=(w-text_w)/2:y=%s" % (FONT, esc(line), ink, sizes[i], y))
    if sub:
        draws.append(
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=15:"
            "x=(w-text_w)/2:y=h-42" % (FONT, esc(sub), ink))
    chain = ",".join(draws)
    # Silent, but with a real audio stream: concat will not join segments
    # whose stream layouts differ, and the cards are the only parts that
    # have nothing to say.
    run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
         "-i", "color=c=%s:s=%dx%d:d=%.2f:r=%d" % (bg, W, H, seconds, FPS),
         "-f", "lavfi", "-i",
         "anullsrc=r=%d:cl=stereo:d=%.2f" % (ARATE, seconds),
         "-vf", "%s,noise=alls=11:allf=t+u,vignette=PI/4.2,format=yuv420p"
         % chain,
         "-shortest", "-c:v", "libx264", "-crf", "18",
         "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])


def channel(src, out, seconds):
    """A programme, whole, with its own sound."""
    run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % seconds, "-i", src,
         "-vf", "%s,%s,format=yuv420p" % (FIT, LOOK),
         "-r", str(FPS), "-c:v", "libx264", "-crf", "19",
         "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])


def interference(kind, outgoing, incoming, out):
    """The signal failing, always with a real picture underneath it —
    interference that carries no image reads as a file ending, not as a
    transmission being lost."""
    common = FIT
    if kind == "static":
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", incoming, "-vf",
             "%s,eq=saturation=0.10:contrast=1.5:brightness=0.05,"
             "noise=alls=95:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20",
             "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])
    elif kind == "roll":
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", incoming, "-vf",
             "%s,scroll=vertical=0.34,eq=saturation=0.35:contrast=1.25,"
             "noise=alls=45:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20",
             "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])
    elif kind == "ghost":
        run(["ffmpeg", "-v", "error", "-y",
             "-t", "%.2f" % GLITCH, "-i", outgoing,
             "-t", "%.2f" % GLITCH, "-i", incoming,
             "-map", "0:a?", "-filter_complex",
             "[0:v]%s,eq=saturation=0.45:contrast=1.15[a];"
             "[1:v]%s,eq=saturation=0.45:brightness=0.04,"
             "crop=%d:%d:11:5,pad=%d:%d:0:0[b];"
             "[a][b]blend=all_mode=average:all_opacity=0.55,"
             "eq=saturation=0.30:contrast=1.25,"
             "noise=alls=42:allf=t+u,format=yuv420p"
             % (common, common, W - 11, H - 5, W, H),
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20",
             "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])
    else:
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", outgoing, "-vf",
             "%s,eq=brightness=-0.62:saturation=0.05:contrast=1.8,"
             "noise=alls=70:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20",
             "-c:a", "aac", "-ar", str(ARATE), "-ac", str(ACH), out])


def main():
    src_dir, out_path = sys.argv[1], sys.argv[2]
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else random.randrange(99999)
    rng = random.Random(seed)
    work = os.path.join(os.path.dirname(out_path), "_broadcast_work")
    os.makedirs(work, exist_ok=True)

    sources = sorted(glob.glob(os.path.join(src_dir, "*.mp4")))
    if not sources:
        sys.exit("no sources in %s" % src_dir)
    rng.shuffle(sources)
    print("%d channels, seed %d" % (len(sources), seed))

    # The reel is planned before any of it is encoded, so the sidecar
    # manifest and the video cannot drift apart: the game reads the manifest
    # to know what the picture is doing at any moment, and audio that thinks
    # the signal is fine while the screen is tearing is worse than no audio.
    manifest_only = "--manifest-only" in sys.argv
    parts = []
    plan = []
    clock = [0.0]
    n = [0]

    def add(path, kind, seconds):
        parts.append(path)
        plan.append({"t": round(clock[0], 3), "d": round(seconds, 3),
                     "kind": kind})
        clock[0] += seconds

    def tmp(tag):
        n[0] += 1
        return os.path.join(work, "%03d_%s.mp4" % (n[0], tag))

    # Opening title, then the marathon.
    title = tmp("title")
    if not manifest_only:
        card([SHOW, "VARIETY HOUR", "MARATHON"], title, 3.2,
             "0x0b1a2a", "0xf2e4c0", 34, sub="ORISON CHANNEL 4")
    add(title, "title", 3.2)

    kinds = ["static", "ghost", "roll", "dropout"]
    bumpers = BUMPERS[:]
    adverts = ADVERTS[:]
    rng.shuffle(bumpers)
    rng.shuffle(adverts)

    for i, src in enumerate(sources):
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", src], capture_output=True, text=True)
        # The whole programme. It is a variety hour, not a channel-hop.
        span = float(probe.stdout.strip()) - 0.1
        seg = tmp("ch")
        if not manifest_only:
            channel(src, seg, span)
        add(seg, "channel", span)
        nxt = sources[(i + 1) % len(sources)]
        # Only occasionally does the signal actually go. Interference at
        # every cut stops being interference and becomes the format.
        glitch = tmp("gl")
        if rng.randrange(GLITCH_EVERY) == 0:
            kind = rng.choice(kinds)
            if not manifest_only:
                interference(kind, src, nxt, glitch)
            add(glitch, "glitch", GLITCH)
        # Roughly every third break goes to an ident or the advertising.
        roll = rng.random()
        if roll < 0.22 and bumpers:
            b = tmp("bump")
            if not manifest_only:
                card(list(bumpers.pop()), b, 1.6, "0x101418", "0xe8d9a8", 28)
            else:
                bumpers.pop()
            add(b, "bumper", 1.6)
        elif roll < 0.44 and adverts:
            a = tmp("ad")
            if not manifest_only:
                card(list(adverts.pop()), a, 2.4, "0x1a1208", "0xf0d99a", 24,
                     sub="A PUBLIC SERVICE ANNOUNCEMENT")
            else:
                adverts.pop()
            add(a, "advert", 2.4)

    # Re-time the plan from what was actually encoded. ffmpeg rounds every
    # segment to whole frames, and across 109 of them that drifted the
    # planned running order eight seconds clear of the real reel — by the
    # end the audio would have been going to static a dozen cuts early.
    if not manifest_only:
        clock[0] = 0.0
        for entry, path in zip(plan, parts):
            probe = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries",
                 "format=duration", "-of", "csv=p=0", path],
                capture_output=True, text=True)
            real = float(probe.stdout.strip())
            entry["t"] = round(clock[0], 3)
            entry["d"] = round(real, 3)
            clock[0] += real

    # The sidecar the game syncs its audio to.
    import json
    side = os.path.splitext(out_path)[0] + ".json"
    with open(side, "w") as handle:
        json.dump({"seed": seed, "length": round(clock[0], 3),
                   "segments": plan}, handle, indent=1)
    print("MANIFEST %s  %d segments  %.1f s"
          % (side, len(plan), clock[0]))
    if manifest_only or "--no-final" in sys.argv:
        return

    listing = os.path.join(work, "reel.txt")
    with open(listing, "w") as handle:
        for part in parts:
            handle.write("file '%s'\n" % part.replace("\\", "/"))

    print("encoding Theora from %d segments..." % len(parts))
    # Audio is kept now. The programmes are meant to sound like programmes;
    # the procedural voice this project synthesises is reserved for when a
    # poltergeist takes the sets, where sounding wrong is the whole point.
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0",
         # q5 at 512x384. q3 blocked up badly; q7 was 49 MB for one reel.
         # -pix_fmt yuv420p is not optional: the per-segment filters set it
         # but concat does not carry it, and Godot's Theora decoder renders
         # anything else as blocky colour noise over a legible picture —
         # which looks like a corrupt file rather than a format mismatch.
         "-i", listing, "-c:v", "libtheora", "-q:v", "5",
         "-pix_fmt", "yuv420p",
         "-c:a", "libvorbis", "-q:a", "1", "-ar", str(ARATE),
         "-r", str(FPS), out_path])
    size = os.path.getsize(out_path) / 1048576.0
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", out_path], capture_output=True, text=True)
    print("BROADCAST %s\n  %.1f s  %.1f MB  %dx%d  seed %d"
          % (out_path, float(dur.stdout.strip()), size, W, H, seed))


if __name__ == "__main__":
    main()
