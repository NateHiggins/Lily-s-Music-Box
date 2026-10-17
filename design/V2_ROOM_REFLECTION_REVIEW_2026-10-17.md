# Room reflection and normal-frame review

Evidence class: **INERT**. Diagnostics and an unmounted prototype; no production
enable, runtime-contract promotion or human appearance acceptance.

REPORT - V2-ROOM-REFLECTION-REVIEW - 2026-10-17

Branch / tested HEAD / origin/main / merge-base: main / **d891c4ae** /
**e0b0dd29** / **e0b0dd29**, before this review checkpoint commit.
Worktree clean at end: no; inherited receipt/capture edits remain outside
named staging. Protected 17/17: yes against the merge-base, also unchanged
in the worktree against tested HEAD. Selector: v2; explicit v1 rollback retained.
Ledger before -> after: not recounted; requirements_changed: []. No schema-2
runtime contract or acceptance marker is created. Full V2 remains incomplete.

## Findings and boundary

The final loaded-frame diagnostic covers 98 StandardMaterial3D surfaces and
879,999 draw vertices across the installed annunciator, 2B radiator and boiler.
Counts include reused vertices. Their normal maps are enabled, and normals /
tangents are finite, unit length, orthogonal and have valid handedness within
test tolerances. Maximum absolute normal/tangent dot products are 0.000215,
0.000236 and 0.000306. This does not qualify every V2 surface or its appearance.

Forward+ already has a seasonal native Sky. Local captures address reflection
context, not a missing sky. The diner backbar already has a cell-owned probe.
The final comparison uses one composed world, settles the actual lighting
owners and then pauses them for baseline / screen space / local interior /
local retaining sky / restored-baseline captures. The watch board is physically
in **F01_WATCH**, which has no mapped room circuit; its review uses the actual
carried lamp. The radiator and boiler use their existing room circuits.
Circuit restoration is a lighting test fixture, not switch-input proof.

Local captures visibly improve the lit radiator's fittings and the boiler's
reflected illumination. Screen space reflection changes little in these views.
The close carried lamp dominates the annunciator, where captures do not fix
remaining surface/readability defects. Retaining sky makes a smaller difference
than adding the local capture in the lit rooms. Daylight remains unqualified.
Final local-capture RGB deltas are 0.00378 / 0.03261 / 0.05143, versus repeat
baseline deltas of 0.000305 / 0.000306 / 0.000413. Deltas are not acceptance.

The unmounted script derives room bounds from the transformed layout, proposes
three cached probes, clear capture origins, circuit invalidation and periodic
refresh. It temporarily isolates the carried light on render layer 19 and
restores its original layer on retirement. A synthetic calibration confirms
unchanged direct camera lighting and exclusion from captured illumination.
No production composition, new lights, textures or material overrides are
enabled. Cache turnover, reconstruction, runtime cost, weather and wider-room
appearance still need qualification. The [Godot probe API reference](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html)
explains the relevant masks, box projection and transform-triggered updates;
those properties alone do not qualify this implementation.

## Runs and retained failures

All Godot runs used the lane broker, windowed capture and named logs. Raw
wrapper receipts and stderr are archived as gzip. Their kind is **suite_run**,
not **runtime_contract**.

- **reflection_capture_targeted** passes six photometric checks: direct-image
  delta zero; projected target red-minus-green change 0.10818.
- **room_reflection_finish_review** passes 49 scoped checks, normal completion
  in 137 seconds. It checks material/direct-light invariance, correct storeys,
  loaded tangent frames and carried-light layer restoration.
- Both still report seven leaked Texture RIDs on renderer shutdown. Process
  success does not make stderr clean.
- The earlier full-frame threshold diluted the target with unchanged background.
  Its failed receipt remains separate from the corrected target measurement.
- The first world setup froze light budgets before moving the controller
  between storeys. Its dark captures are retained as a flawed setup.
- The following lit run fails two watch-circuit assertions. That circuit does
  not exist. The other rooms and all normal-frame checks pass; the run remains
  a failure overall.
- Replacing World3D during cleanup adds a null-scenario renderer error without
  removing the seven-texture warning. That attempt is rejected. The current
  synthetic bench is restored byte-for-byte to the earlier targeted source.

[Godot issue 122498](https://github.com/godotengine/godot/issues/122498) reports
a matching reflection-atlas leak on this exact 4.7.1 a13da4feb engine, involving
the colour buffer and six face views. Matching version/count supports an
engine-level explanation; it does not exclude additional application leaks.
No engine replacement, patch or stderr suppression was performed.

Gates: reader baseline has zero new unread fields; all 1,253 referenced surface
images pass static import policy; four spatial-contract source preflights pass;
protected-file comparison passes 17/17. Broad gate board, candidate verifier,
completeness/spatial/systemic/period batteries and full surface qualification
were not rerun for this unmounted diagnostic checkpoint. Static import checks
do not prove loaded mip chains or whole-world appearance.

## Evidence and remaining work

Packet: **art/reviews/v2_radiator_cutover_20261017/room_reflections**. The final
unedited views are in **captures/room_reflection_finish_review**. Initial,
failed-lit and final source snapshots carry LF hashes checked against their
test receipts. Raw logs retain original bytes inside gzip. Earlier receipts
were not repinned. The run summary explicitly records nonempty stderr/errors.

Changes outside expected boundary: none. Production composition, mechanical,
NPC, inventory, save and case authorities and material recipes are unchanged.
The calibration scene's primitive geometry is a synthetic renderer fixture,
not shipped V2 art.

Open findings: atlas warning; cache turnover/runtime cost; daylight/weather
and additional rooms; coarse wall relief; annunciator glare and timber finish;
the boiler's blank gauge scale; the played radiator repair/custody/resident
route; native lift dispatch and broader V2 surface/geometry/interaction and
retirement work. Decision needed from owner: none; human acceptance is separate.

BLOCKED production enable: lifecycle, performance and wider lighting qualification
remain open. This is a review checkpoint, not a blocked full-V2 goal or merge
candidate.
