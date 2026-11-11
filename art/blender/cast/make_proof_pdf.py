"""Cast proof sheets: one page per character, for mark-up.

python make_proof_pdf.py <proof shots dir> <cast_parts.py dir> <out.pdf>
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

SHOTS, PARTS_DIR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, PARTS_DIR)
import cast_parts

W, H = 2400, 1350
PAPER = (246, 243, 236)
INK = (28, 26, 24)
SOFT = (110, 104, 96)


def font(size, bold=False):
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def shot(name, box, size):
    path = os.path.join(SHOTS, name + ".png")
    if not os.path.exists(path):
        blank = Image.new("RGB", size, (200, 196, 190))
        ImageDraw.Draw(blank).text((20, 20), "not captured", fill=SOFT, font=font(28))
        return blank
    return Image.open(path).convert("RGB").crop(box).resize(size, Image.LANCZOS)


pages = []
cover = Image.new("RGB", (W, H), PAPER)
d = ImageDraw.Draw(cover)
d.text((80, 70), "Cast proof sheets, round 5", fill=INK, font=font(84, True))
lines = [
    "One page per character. Each page shows the face, then the three outfit sets (home, street, occasion) from the front, and the street set from behind.",
    "",
    "Please mark up each page with specific improvements under four headings: CLOTHING, FACE, HAIR, BODY.",
    "Point at the place on the picture, say what is wrong, and say what it should look like instead. Rank the three worst faults on each page.",
    "",
    "What these are: game characters for a story set in 1929 in a New York apartment building. Stylised but period plausible.",
    "Every character should be attractive, well dressed and easy to tell apart at a distance.",
    "",
    "House rules the mark-up should respect:",
    "  - Simple necklines, round or V. No tall starched collars.",
    "  - Colour sits between bold and realistic, with some wear and tear. Each person has a colour of their own.",
    "  - No lettering, numbers or logos on any cloth.",
    "  - Clothes are skinned meshes with no cloth simulation. Skirts follow the legs.",
    "  - Hair is strand hair. Bodies come from one shared base and differ by age, build and proportion.",
    "  - Outfit parts mix across sets, so each part must also work on its own.",
    "",
    "Known faults already on the list: capes are boxy, some garment edges are rough, knee patches read as paper tags,",
    "men's short hair shows a pale patch at the crown, and these are still pictures, so nothing here judges motion.",
]
y = 220
for line in lines:
    d.text((80, y), line, fill=INK if line and not line.startswith("  ") else SOFT, font=font(34))
    y += 50
pages.append(cover)

SETS = ["home", "street", "occasion"]
for cid, sets in cast_parts.STYLES.items():
    page = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(page)
    d.text((60, 36), cid.replace("_", " ").title(), fill=INK, font=font(72, True))
    d.text((W - 620, 64), "mark up: CLOTHING  FACE  HAIR  BODY", fill=SOFT, font=font(28))
    page.paste(shot("proof_%s_face" % cid, (280, 0, 1000, 720), (640, 640)), (60, 150))
    d.text((60, 800), "face and hair (no hat)", fill=SOFT, font=font(28))
    x = 740
    for label, name in (("home (a)", "proof_%s_a_front" % cid), ("street (b)", "proof_%s_b_front" % cid), ("street, back", "proof_%s_b_back" % cid), ("occasion (c)", "proof_%s_c_front" % cid)):
        page.paste(shot(name, (400, 20, 880, 720), (398, 580)), (x, 150))
        d.text((x, 740), label, fill=SOFT, font=font(28))
        x += 412
    y = 860
    for index, (top, bottom, over, head, feet) in enumerate(sets):
        text = "%s:  %s, %s, %s, %s, %s" % (SETS[index], top, bottom, over, "no hat" if head == "-" else head, feet)
        d.text((60, y), text.replace("_", " "), fill=INK, font=font(32))
        y += 46
    d.line((60, y + 20, W - 60, y + 20), fill=SOFT, width=2)
    d.text((60, y + 34), "Notes:", fill=SOFT, font=font(30))
    pages.append(page)

pages[0].save(OUT, save_all=True, append_images=pages[1:], resolution=150)
print("PDF", OUT, len(pages), "pages", os.path.getsize(OUT))
