# Native hose release: contact response and exposed instability

Evidence class: **INERT**. Uninstalled prototype, including failed diagnostics.
No ledger promotion or completed physical-release claim.

The candidate now derives local response half-spaces from its actual hollow
skin and attempts gravity-driven release with the original segment lengths
and fixed outlet. The final diagnostic **fails**: its energy guard rejects
unstable proposals. This prototype is not installed in the eight cabinets.
The full V2 goal, broader qualification and human appearance remain open.

## Contact work

The contact owner still uses actual imported inner and outer ring vertices,
32 annular cells per adjacent pair, the same one-micrometre collision margin
and original world-body exclusions. Contact collection returns explicit
valid/truncated flags rather than accepting incomplete manifolds.

Response normals and surface points use Godot's
[get_rest_info API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html#class-physicsdirectspacestate3d-method-get-rest-info).
Actual outer-section support converts each local surface into a centreline
constraint. A 100-micrometre response stand-off moves the cloth away from the
obstacle; it does not relax collision or length checks. A real 500-micrometre
endpoint intrusion, explicit truncation, obstacle removal and transformed
world binding are exercised. The standalone contact phase passed before
gravity was added; those checks also pass in the final combined run.

Final-pose contact initially selected the underside of a thin floor after a
fast proposal crossed it. Response now refines the first hit on the existing
conservative linear-vertex sweep with 14 prefix-hull bisections. This is still
not exact rigid-rotation CCD. It remains computationally expensive.

## Release prototype and original failures

The packet is **art/reviews/v2_fire_hose_release_20261019**. Original logs,
wrapper receipts, renders, captured intermediate sources and final post-run
source copies are retained unchanged. No old receipt has been repinned.
After capture, one trailing empty line was removed from the world-contact
test source; its exact run variant remains in the original-source packet.

The prototype integrates bounded 1/120-second gravity steps, projects each
length sphere against collected support planes, propagates necessary support
toward the outlet, then checks the whole native sweep before applying a pose.
It owns no maintenance, NPC, inventory or household facts.

- **planes1** failed on a typed test-variable parse error. **planes2/3**
  exposed an unintended platform edge in a flat-surface fixture. **planes4**
  passed after correcting that fixture.
- **gravity1–4** exposed infeasible contact constraints. The fourth trace
  identified conflicting floor-top and floor-underside normals.
- **gravity5–7** exposed persistent corrections. Similar response normals
  were incorrectly merged without accounting for their different offsets.
  The solver now retains distinct normals.
- **gravity8** passed the geometric diagnostic in 25.03 s with empty stderr.
  Twelve free steps lowered mean ring height approximately 35 mm. Twenty-four
  supported steps retained lengths and a clear shell, but took approximately
  eight seconds to simulate 0.2 seconds. This is not real-time performance.
- Direct render review then rejected the physical appearance: loops whipped
  upward, creases became implausible and the separate bench fitting did not
  follow the hose. Geometric clearance alone was insufficient evidence.
- **gravity9** added material-length-weighted mechanical energy. Energy rose
  from about 60.44 to 9,613.24 in the stationary-floor test. The stronger test
  correctly failed, superseding the earlier geometric-only pass.
- **gravity10/11**, the final source, reject an entire proposal before applying
  it when static-world energy would increase beyond the existing positional
  precision allowance. It stops free fall and floor response rather than
  permitting the unstable poses. Supported final energy remains below the
  initial value, but the full-release checks correctly remain failed.
  The final **gravity11** run explicitly confirms that rejected free and
  supported steps preserve the cloth points, native skin and velocities
  atomically. Its two release-completion checks remain failed.

The final run has no stderr output. UV/PBR/loaded mips, actual grab/motion/
release, JSON restoration, native bone deformation, hollow contact and
transformed binding checks still pass in that run. Its combined verdict is
**FAIL**, not acceptance. Wrapper receipts and these diagnostics are not
schema-2 runtime-contract proof.

## Required next work

Replace the unstable one-sided projection with a stable mass-aware constraint
solve, add bend/twist response and moving self-contact, and verify sustained
release with energy and actual rendered poses. Optimize the shell response
without substituting a solid centreline capsule or sacrificing the bore.
Then couple the fitting/nozzle, add held-end constraints, rack support and
physical release/refolding, household reconstruction and installed-world
qualification. No toggle may stand in for physically folding the hose.

The last full verifier at **5d7fe292** still reports 114 broader regressions;
it was not renewed for this prototype. Seven earlier composed texture RID
shutdown warnings remain open. No merge or human-appearance acceptance is
requested by this checkpoint.
