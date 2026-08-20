# DREAM SURFACE TARGET V2 — DARK-LIVE HAZARD ANATOMY

Production capture, 2026-08-20. Governing composition reference:
`art/reference/dream_surface/stage4_room_colonisation.png`.

The harness instances the real `DreamMazeRoot`, selects a deterministic live
`D01_F04_LONG_HALL`, and uses the real player service lamp. It adds no helper
environment, light, furniture, hazard, collision or presentation geometry.
The player and topology are frozen only after staging; the shader clock keeps
running.

## Frames

- `01_furnished_breach_lamp_on.png` — the settled production beam finds the
  wine-purple body and wakes antique-gold veins/eyes.
- `02_furnished_breach_motion.png` — the same camera and lamp 150 frames later;
  silhouette differences are shader motion, not a rebuilt mesh.
- `03_furnished_breach_dark_live.png` — the same frame with the production lamp
  switched off. Architecture falls to the dream's ruled pitch black while the
  limb retains a much lower wine-purple local presence. It remains animated
  and its contact paths remain armed.

## What the stills cannot prove

`DreamSurfaceTargetTest.tscn` proves in 21/21 checks that the production body
is one populated surface, reconstructs deterministically, carries first
geometric eyes, and adds no collision or second hazard population. Every
substantial centerline is registered on its existing source `DreamHazard`; the
test selects a point well outside the legacy circular root and proves the
owner's contact query reaches it. It also proves remembered nonblank rooms
carry meshes extracted from real Orison prop scripts while no `FunctionalProp`,
collision, light or audio owner crosses into the dream.

## Performance

Two fresh 2560×1440 `PERF_DREAM=1` runs stayed between 1.60 and 2.01 ms at all
four lamp/station rows, with zero rows over 16.6 ms. The production census is
110 `GeometryInstance3D` nodes, 53 shader materials and five instances of the
shared lineage/growth shader. Worst observed submission count was 160 calls.
The Orison furnishing raises submissions substantially over the pre-pass
54-call record, but the measured frame retains roughly 14.6 ms of the budget;
future breach work must continue to report fresh totals rather than spend that
headroom silently.

## Honest boundary

This is N10's first geometric hazard/furnishing slice, not a claim that the
reference composition is finished. Surface relief (C), torn breach and
interior-mapped impossible depth (D), exposure-ramped breach anatomy, full eye
tracking/lids, and governed reflected-gold world light remain open. The target
reference is denser and more architecturally integrated than this pass; that
remaining distance is recorded rather than hidden by a beauty-only helper rig.
