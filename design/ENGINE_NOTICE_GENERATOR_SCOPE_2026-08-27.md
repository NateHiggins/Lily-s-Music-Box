# Engine notice-generator scope audit

**Status:** K0-ENGINE / extraction follow-up 4 fact-finding, 2026-08-27.
This answers questions H1–H3 in
`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` against the repository and
the existing generator. It is an inventory of behavior and gaps, **not legal
advice and not a redistribution ruling**.

## Executive answer

`tools/build_third_party_notices.ps1` is a deterministic **friends-game notice
assembler**, not a bill-of-materials scanner. It reads exactly two repository
files—the Courier Prime OFL and the Freesound attribution record—and prepends a
static Godot paragraph linking to <https://godotengine.org/license/>. The
friends-build packager invokes it and requires the resulting
`THIRD_PARTY_NOTICES.txt` in its six-file payload.

That is adequate evidence that the current game-package path carries the three
sections it was designed to carry. It is not evidence that a future toolkit,
repository archive, editor plugin or leased service has a complete notice set.
The generator never inspects its output payload, the PCK, the engine binary,
Python imports, PowerShell dependencies, Blender, Godot editor components,
addons, fonts outside one fixed directory, or vendored source.

## Method and reproducible result

Read-only/static checks:

- inspected `build_third_party_notices.ps1`, `package_friends_build.ps1`,
  `test_release_pipeline_contract.ps1` and both generator source files;
- enumerated tracked font binaries, licence/notice files, conventional
  `addons`, `vendor`, `third_party`, `node_modules` and `site-packages` paths;
- searched `game/` and `tools/` code for SPDX/licence/copyright headers,
  GDExtension/addon references, binary libraries and external imports;
- checked both export presets' include/exclude filters.

Dynamic check on 2026-08-27:

- generator: `THIRD-PARTY NOTICES PASS`;
- generated file: 9,551 bytes, SHA-256
  `2bb713bbf2b1d114b6b17775f825c35b27ca563a023a4591a12862c7f2cccd25`;
- headings present: `GODOT ENGINE`, `COURIER PRIME`, `FREESOUND SOURCES`;
- Courier Prime `OFL.txt` embedded verbatim: **yes**;
- Freesound `ATTRIBUTION.md` embedded verbatim: **yes**;
- release-pipeline contract: **PASS 46/46**.

The generated audit artifact was deleted after comparison and was not added to
the repository.

## H1 — Godot / MIT notices

### What the generator covers

It emits a static statement naming Godot Engine, MIT, the Godot contributors'
copyright line, and the official Godot licence/bundled-component URL. The
friends packager runs this generator after copying the exported EXE/PCK and
fails unless `THIRD_PARTY_NOTICES.txt` is one of exactly six staged files.

### What it does not establish

- It does not read the exported executable, query its Godot version or call
  `Engine.get_license_text()` / `Engine.get_copyright_info()`.
- It does not embed the Godot MIT text or Godot's component inventory; it links
  to the official page.
- It does not prove that the static copyright wording matches every future
  Godot version or custom engine build.
- It does not scan a toolkit payload. The repository currently tracks
  `Godot_v4.7.1-stable_win64_console.exe` at its root, outside both `game/` and
  `tools/`; that binary is not an input to the notice generator and is not part
  of the friends packager's six-file export.

**Disposition:** current friends-game path: **covered by the implemented static
notice/link contract**. Toolkit/repository/editor distribution: **UNKNOWN; new
payload census required**. This is a coverage statement, not an opinion about
legal sufficiency.

## H2 — bundled third-party code

### What was found

Within tracked `game/` and `tools/`:

- no `game/addons` or conventional vendor/third-party package directory;
- no tracked DLL, shared-library, JAR or wheel under those roots;
- no GDExtension or `res://addons` reference;
- no third-party copyright/SPDX/licence header in GDScript, Python or
  PowerShell code beyond the notice builder's own expected notice strings.

This supports the narrow statement: **no conventionally marked vendored
third-party code was detected under `game/` or `tools/`.** It does not prove
authorship file by file, and it does not include media/content provenance.

### Dependencies the generator ignores

Several tools import or require software that is not vendored in those roots:

- Pillow (`PIL`) and NumPy for image/measurement scripts;
- Blender's `bpy`/`mathutils` for Blender-run scripts;
- Python, PowerShell/.NET and Godot as execution environments.

Dependency is not the same as redistribution. The current repository census
does not show Pillow, NumPy, Blender, Python or PowerShell binaries bundled in
the friends payload. A future tool package could change that fact, and the
generator would not notice.

**Disposition:** current `game/`/`tools/` vendored-code census: **none detected,
with stated search limits**. Toolkit bill of materials: **UNKNOWN until its
actual payload and dependency-install method exist**.

## H3 — fonts and editor/tool licences

### Current font coverage

The only tracked font binaries are:

- `game/assets/fonts/courier_prime/CourierPrime-Regular.ttf`;
- `game/assets/fonts/courier_prime/CourierPrime-Bold.ttf`.

Both are loaded by `telegram_style.gd`, both are eligible for export under the
current all-resources presets, and both share the exact OFL source the generator
embeds verbatim. The generator also asserts the expected copyright line and
`SIL OPEN FONT LICENSE Version 1.1` before writing output.

### Discovery gap

Coverage is hardcoded to
`game/assets/fonts/courier_prime/OFL.txt`. The generator does not enumerate font
files, associate each font family with a notice, or fail when a second family
is added elsewhere. It also does not inventory fonts supplied by Godot, Pillow,
the operating system, documentation builders or a future editor/plugin UI.

No additional tracked `.ttf`, `.otf`, `.ttc`, `.woff` or `.woff2` file was
found at this checkpoint. Pillow's `ImageFont.load_default()` is used by the
measurement script, but no separate Pillow font file is vendored in this
repository census.

**Disposition:** current two-file Courier Prime game-font set: **covered**.
Future font/editor/tool payload: **UNKNOWN and not automatically discovered**.

## Generator boundary

The safe invariant is:

> The generator proves that its two fixed source records and static Godot
> paragraph reached one output file. It does not prove that those sources are
> the complete third-party inventory of an arbitrary payload.

Before using it for anything other than the current friends-game package, the
consumer must supply a concrete payload manifest and reconcile every shipped
binary, library, font and content family against a notice/provenance record.
Adding a scanner now would be premature: no toolkit payload exists, and the
extraction phase hard stop forbids productization work before the reference
consumer.
