# Shattered — Gilded Moth Productions

Tilt/drag glass-restoration game for phones. An image lies broken into jittered
glass triangles on a tray; tilt the phone (or drag with a finger) to slide each
shard home. Shards snap in with a gold flash; restore them all to unveil the
whole picture.

- **One file**: `index.html` — HTML/canvas, no dependencies.
- **Bring-your-own gallery**: user images via file picker, stored in IndexedDB
  on-device only. Ships with three abstract gilded-deco SVG placeholders — no
  adult content in the app itself.
- **Modes**: CRACKED (12 shards) / SHATTERED (24 shards).
- **Anti-frustration design**: generous snap radius, magnetic pull near home,
  ghost outlines of empty slots, drag as a full alternative to tilt.
- **Tilt input**: browser `deviceorientation` (iOS permission prompt handled),
  or the native WebView bridge — same contract as Velvet Maze:
  `window.__nativeTilt(beta, gamma)`.
- **Aesthetic**: gilded-noir house palette — plum `#120810`/`#2a1220`,
  gold `#d4af5e`, rose `#c4788a`, ivory `#efe3d0`.

## Run
Open `index.html` in any browser (drag works everywhere; tilt needs a phone),
or serve: `python -m http.server 8898 --directory .`

## Android APK path
Reuse the Velvet Maze WebView shell — the tilt bridge contract is identical.
Sign with a NEW keystore (separate app identity). Toolchain installed
(JDK 17, SDK 34 — see devkit README).

## Distribution note
Google Play prohibits sexually explicit apps — distribute via itch.io, web, or
direct APK. The app as shipped contains only abstract placeholder art.

## Verified (automated, 2026-07-18)
- Shatter tiles the image exactly (shared jittered vertices), 12/24 modes
- Tilt physics slides shards; wall bounce; magnet + snap locking
- Drag: grab, place near home, snap-lock (synthetic pointer events)
- Win veil + next-image rotation
- No self-locking at spawn (scatter re-rolls against analytic wall clamp)

## Not yet done / hand-test
- File-picker add/delete (native dialog — untestable in automation)
- Real tilt feel on an actual phone — tune GRAVITY/FRICTION to taste
- No sound
