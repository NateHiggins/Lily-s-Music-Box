# Native hose bending resolution

Evidence class: **INERT**. Candidate diagnostic; no ledger promotion.

The previous full-length candidate retained straight intervals up to 540 mm.
Those intervals could not form convincing new bends during deployment.
The selected native Blender mesh subdivides long intervals to at most 5 mm,
preserving the original curved samples, ports and 15.24 m material length.
It has 3,472 ring bones and 444,416 triangles. This is still an uninstalled
candidate, referenced by the focused bench rather than the eight cabinets.

## Native comparison

The packet is **art/reviews/v2_fire_hose_bending_20261019**. The first 10 mm
variant had 2,049 rings. Its five-interval tight bend was visibly faceted.
The selected 5 mm variant gives that bend ten intervals and a smoother
outline. Separate tight and loose native coupons retain the actual cloth
section, UVs, wall thickness and closed annular cut ends. These are local
material studies, not collision-qualified deployment poses. Both selected
coupon renders were inspected directly.

The selected native resting review retains 65 positive rack bearings,
65 displaced negative controls and eight backplate contacts. Maximum bearing
gap is approximately 50.4 micrometres. The native report finds no static
self-crossings. This does not establish moving self-contact or rack release.
Stored chart precision and normals/tangent guides are shared at export;
the original tangent and UV requirements remain enforced.

## Imported diagnostic

Original **stage25_dense1.log.receipt.json** reports a completed 17.01 s
windowed run with no script errors. Its stderr is empty. The test reports:

- All 3,472 imported ring bones and the full material length bind correctly;
  maximum imported interval is 0.005000055 m.
- Authored metre UVs, normal-map tangent derivatives, custom linen PBR and
  all three loaded mip chains pass under the reduced carried voxel light.
- A visible/hidden render comparison at the fully extended high-index end
  confirms actual GPU deformation above bone index 2048. The visible frame
  and close resting-cloth frame were inspected directly.
- Actual cursor selection, click grab, mouse motion and click release retain
  fixed upper port, individual lengths, total length and JSON restoration.
- Round and flattened bores remain open, native cloth walls and wide edges
  block probes, between-pose obstruction is detected, and a rejected movement
  leaves the whole saved strand unchanged. Six fresh height/orientation
  bindings pass. Chunked and per-segment swept queries agree on the blocker.
- Geometry-frame caching survives in-place point edits and returned-array
  edits. Nonfinite contact inputs are rejected before broad-phase queries.

The contact optimization groups 32 segments before narrow-phase queries and
evaluates actual native vertices only in occupied regions. It caches geometry
frames, never world collision answers. Sweeps still cover linear vertex
trajectories conservatively, not exact rotation arcs or penetration recovery.
Post-run source copies are labelled as such; original receipts are unchanged.
These diagnostics and wrapper receipts are not runtime-contract acceptance.

## Remaining work

Gravity, contact response, moving self-contact, supported rack release,
physical refolding, coupled nozzle movement, household disk reconstruction
and installation remain unfinished. The denser mesh increases asset size
and skinning cost; the isolated run is not a composed-world performance test.
The last full verifier at **5d7fe292** still reports 114 broader regressions;
it has not been renewed for this candidate. Seven earlier composed-world
texture RID shutdown warnings also remain open. Full V2 completion and human
appearance acceptance remain **OPEN**.
