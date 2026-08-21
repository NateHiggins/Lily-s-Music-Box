"""Join the six already-rendered production incarnation proofs."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "renders" / "dream_incarnation_v9"
CASES = [
    ("MINA", ROOT / "art/renders/dream_incarnation_mina_v3"),
    ("PETER", ROOT / "art/renders/dream_incarnation_peter_v4"),
    ("JUNO", ROOT / "art/renders/dream_incarnation_juno_v5"),
    ("MAE", ROOT / "art/renders/dream_incarnation_mae_v6"),
    ("CAL", ROOT / "art/renders/dream_incarnation_cal_v7"),
    ("OMAR", ROOT / "art/renders/dream_incarnation_omar_v8"),
]
FONT = ImageFont.load_default()


def one(folder: Path, pattern: str) -> Path:
    matches = sorted(folder.glob(pattern))
    if len(matches) != 1:
        raise RuntimeError(f"expected one {pattern} in {folder}, got {matches}")
    return matches[0]


def sheet(name: str, columns: list[tuple[str, str]], size=(320, 180)) -> None:
    margin, label_h = 12, 22
    width = margin + len(columns) * (size[0] + margin)
    height = margin + len(CASES) * (size[1] + label_h + margin)
    canvas = Image.new("RGB", (width, height), (9, 7, 12))
    draw = ImageDraw.Draw(canvas)
    for row, (case_name, folder) in enumerate(CASES):
        y = margin + row * (size[1] + label_h + margin)
        draw.text((margin, y), case_name, fill=(232, 191, 98), font=FONT)
        for col, (heading, pattern) in enumerate(columns):
            x = margin + col * (size[0] + margin)
            if row == 0:
                draw.text((x + 56, 2), heading, fill=(220, 213, 198), font=FONT)
            image = Image.open(one(folder, pattern)).convert("RGB")
            image.thumbnail(size, Image.Resampling.LANCZOS)
            tile = Image.new("RGB", size, (0, 0, 0))
            tile.paste(image, ((size[0] - image.width) // 2,
                               (size[1] - image.height) // 2))
            canvas.paste(tile, (x, y + label_h))
    canvas.save(OUT / name, optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet("01_six_case_states.png", [
        ("DARK", "01_*_dark.png"),
        ("OBLIQUE", "02_*_oblique.png"),
        ("MOLTEN / SIGNATURE", "03_*_molten_*.png"),
    ])
    sheet("02_six_case_blends.png", [
        ("0%", "04_blend_00.png"), ("25%", "04_blend_01.png"),
        ("50%", "04_blend_02.png"), ("75%", "04_blend_03.png"),
        ("100%", "04_blend_04.png"),
    ], (256, 144))
    sheet("03_six_case_fauna.png", [
        ("BUTTONS", "07_fauna_00_*.png"),
        ("TESSELLATES", "07_fauna_01_*.png"),
        ("ANEMONES", "07_fauna_02_*.png"),
        ("RIBBONETTES", "07_fauna_03_*.png"),
        ("LOUPE", "07_fauna_04_*.png"),
    ], (256, 144))
    sheet("04_six_case_aa_controls.png", [
        ("CONTROL A", "00_control_a.png"),
        ("EQUAL-INTERVAL REPEAT", "00_control_a_repeat.png"),
    ])
    print(f"wrote joined proof to {OUT}")


if __name__ == "__main__":
    main()
