# Gilded Pairs — Gilded Moth Productions

Reveal memory-match for phones. A pairs board sits over an image from a private
on-device gallery; each matched pair dissolves those cells, unveiling the image
region beneath. Clear the board to see the whole picture.

- **One file**: `index.html` — HTML/CSS/canvas-free DOM game, no dependencies.
- **Bring-your-own gallery**: user images via file picker, stored in IndexedDB
  on-device only. Ships with three abstract gilded-deco SVG placeholders (moth,
  fan, moon) labeled "demo" — no adult content in the app itself.
- **Modes**: 4×4 (8 pairs) and 6×6 (18 pairs).
- **Aesthetic**: gilded-noir — plum `#120810`/`#2a1220`, gold `#d4af5e`,
  rose `#c4788a`, ivory `#efe3d0` (house palette).

## Run
Open `index.html` in any browser, or serve the folder
(`python -m http.server 8899 --directory .`).

## Android APK path
Reuse the Velvet Maze WebView shell: swap `assets/index.html`, keep the native
image-picker bridge, sign with a NEW keystore (separate app identity).
Toolchain already installed (JDK 17, SDK 34 — see devkit README).

## Distribution note
Google Play prohibits sexually explicit apps — distribute via itch.io, web, or
direct APK. The app as shipped contains only abstract placeholder art.

## Not yet done
- File-picker add/delete flow untested in automation (needs a native dialog);
  test by hand on first run.
- No sound. `lily/assets/audio` tracks are LilysMusicBox's — source separate
  audio if wanted.
- No move-count par / scoring beyond the counter.
