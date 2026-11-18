# Lily/Stacy pilot lessons

Read this for this source family or its demonstrated failure modes. These
artifacts are local qualification evidence, not portable dependencies or a
universal hair budget. Resolve newer freezes before replaying a producer.

## Source and approval provenance

- Frozen pilot: `C:/ov/reports/npc_rig/hair_cards_pilot/r25/FREEZE.json`.
  It pins the builder, Lily style, shader, editable source, export and maps.
  Its original status says not Lily-approved. Fable's later bridge message
  `94afeb6826034934aa20cb9f03cc7cf8` reports Lily approved r25 and asked for
  the entire cast in refined batches. That later artistic decision does not
  turn the pilot's static evidence into runtime qualification.
- Native intake directory:
  `C:/ov/reports/npc_rig/lily_stacy_codex/polish_01/hair/fable_cards_lily_01/`.
  Read `reexport_tangents_exact.py`, `GEOMETRY_EQUIVALENCE_EXACT_R25.json`
  and `INTAKE_AUDIT_r25.json` for the exact source/export repair and scope.
- Stacy counterpart:
  `C:/ov/reports/npc_rig/lily_stacy_codex/polish_01/hair/fable_cards_stacy_01/`.
  `add_streak_shared_r25.py` and `build_dye_atlas.py` retain her dye workflow.

## What failed and what was actually established

- Stock card export failed strict tangent derivatives. Per-corner tangent
  guides alone left native custom-normal quantization changes (initial maximum
  normal delta about 0.011, rejected). Adding normal guides produced the exact
  variant: positions and both UV channels had zero delta; maximum normal delta
  was about 6.37e-5, with unchanged triangle counts and strict checker PASS.
  These are observed results for those files, not a new global tolerance.
- The intake audit reports native export checks for Lily and Stacy, including
  strict derivative PASS. Its scope explicitly excludes engine/gameplay/art
  acceptance. Identify hashes carefully: an audit, a tangent-only derivative and
  the final MASK/binding derivative may be different artifacts.
- Recoloring an already packed Blender image silently left old bytes in the
  export. The successful repair authored an sRGB PNG, loaded it as a NEW image,
  relinked both cap and cards, then decoded the exported RGBA and compared it
  exactly. A changed image name or preview color was insufficient.
- Dye selection through a mirrored UV ellipse or a hidden card targeted the
  wrong visible forelock. Alpha-aware rays located the exposed strip before
  assigning the dye atlas cell. Keep gutters and inspect the actual silhouette.
- Source-scene selection leaked body geometry into a hair-only GLB; explicit
  hair selection and an exported inventory caught it. Card material must export
  MASK rather than BLEND. Verify the delivered encoded material and maps.

Native source/export checks and captured native controls establish only their
declared scope. At this pilot handoff, Godot/game/Harukiya composition and
Head-driven motion remained unqualified. Consult later source-bound receipts
before changing that status; do not infer it from owner approval or a sheet.
