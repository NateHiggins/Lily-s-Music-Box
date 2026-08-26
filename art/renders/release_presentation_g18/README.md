# G18 release-presentation proof

Production `MinaWakingResidueShot` captured windowed at commit `372132f` with
`ORISON_DEVELOPER_OVERLAYS` empty. Godot ran only through
`tools/run_godot_serial.ps1`, one instance, with a 60-second ceiling.

Frames:

- `00_resolved_control_a.png` — resolved 2A kitchen control.
- `01_resolved_before_wake.png` — same state before the wake residue.
- `02_waking_residue.png` — the one intended factual `REFRIGERATOR` residue.

Visual ruling: the control and before-wake frames contain no resident/status
nameplate, generic case-object title, caption-calibrator title, light-selection
ring, or `LIGHT SELECTED` marker. The only world-space text in frame 02 is the
authored waking residue. Mina's active-case `SOFA`, `DESK`, `WINDOW`, and
`MINA` captions remain production gameplay elsewhere and were not deprecated
as debug UI.

Whole-frame RGB RMSE:

- control A → before wake: `1.537593154` (temporal renderer floor; not zero)
- before wake → residue: `5.211171310` (`3.39×` the measured floor)

The A/A pair is not used to claim pixel identity. It prices the renderer noise
present in this production scene; the release-presentation claim is visual and
structural, backed separately by `ReleasePresentationTest` 5/5.

The engine exited successfully after all three frames. Its existing renderer
teardown emitted the known repeated `indexing did not unpair geometries from
light` messages; no script or parse failure occurred.
