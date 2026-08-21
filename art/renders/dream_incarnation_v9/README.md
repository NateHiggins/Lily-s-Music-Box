# INC-V9 — six-case joined production proof

Closed 2026-08-21 on Godot 4.7.1 Compatibility / OpenGL 3.3 / RTX 4080.
This gate joins the six previously accepted production-root captures; it does
not recapture them in a proof-only world or claim any waking case loop exists.

## Result

Mina, Peter, Juno, Mae, Cal and Omar all resolve through one profile validator,
one active-case cache, one shader include, one material collector, one fauna
owner and the existing `DreamMazeRoot`. Each active case owns exactly 17 maps
and 100,663,284 lossless mipped bytes (96.000004 MiB). Paired same-seed roots
reproduce identical plan, pursuit parameters, collision-shape count and hazard
count. Presentation, maze and hazard data remain outside the saved dream
context, and there is no incarnation runtime owner.

The combined sheets are mechanical joins of the per-case production PNGs:

- `01_six_case_states.png`: dark, oblique and molten/signature states.
- `02_six_case_blends.png`: all five continuous irradiance blends.
- `03_six_case_fauna.png`: all five families in all six costumes.
- `04_six_case_aa_controls.png`: each equal-interval A/A pair.

All motion rates in the six profile records are below 1 Hz. Long-sightline
anti-tiling, tenderness, bounded reflected world, signature behavior and
visual exclusions remain documented in the six source proof READMEs. The
Tenant remains shadows-only outside the beauty pass; `DreamPursuitTest` passes
39/39 and retains the existing save/outcome boundary.

## Measured image bands

Full-frame mean RGB, 0–255. A/A is sequential live-animation difference, so it
is a measured noise floor rather than an expectation of identical pixels.

| case | A/A | dark | oblique | molten/signature |
|---|---:|---:|---:|---:|
| Mina | 0.647 | 0.276 | 5.716 | 30.260 |
| Peter | 0.733 | 0.276 | 9.113 | 38.336 |
| Juno | 0.434 | 0.272 | 8.033 | 17.708 |
| Mae | 0.498 | 0.471 | 8.321 | 17.975 |
| Cal | 0.198 | 0.271 | 4.734 | 9.565 |
| Omar | 0.847 | 0.540 | 4.771 | 26.745 |

Every case preserves the required state ordering. A/A is priced separately
because live shader/fauna animation can exceed the very dark state's absolute
luma without erasing the multi-stop oblique and molten separation.

## Six-case performance gate

Windowed 2560×1421 production benchmark, vsync disabled, same seed, worst-yaw
waking/deep stations, lamp off/on. Different attachments legitimately submit
different Atlas rooms; the incarnation branch itself adds no draw owner.

| case | calls range | frame-time range | result |
|---|---:|---:|---:|
| Mina | 48–172 | 2.32–2.57 ms | 0/4 over |
| Peter | 128–163 | 2.30–2.49 ms | 0/4 over |
| Juno | 55–119 | 2.17–2.48 ms | 0/4 over |
| Mae | 64–128 | 2.55–2.74 ms | 0/4 over |
| Cal | 68–147 | 2.32–2.55 ms | 0/4 over |
| Omar | 155–206 | 2.79–2.87 ms | 0/4 over |

Result: 24/24 stations under 16.6 ms; worst measured row 2.87 ms.

## Contracts

- Dream incarnation: 66/66.
- Active plate residency: 12/12.
- Shared profile grammar: 63/63.
- Irradiance/unreliable lamp: 16/16.
- Fauna/ecology: 21/21.
- Pursuit/shadows/save boundary: 39/39.
- Source ingest: 30 definitions, all six cases complete.

Regenerate the joined sheets with:

```powershell
python art/tools/build_dream_incarnation_v9_contact_sheets.py
```

Run any case performance row with `PERF_DREAM=1` and
`PERF_DREAM_INCARNATION=mina|peter|juno|mae|cal|omar` against
`res://tests/Perf.tscn`.
