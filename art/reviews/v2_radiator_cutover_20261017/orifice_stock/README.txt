Evidence class: INERT. Local WIP review; not runtime-contract acceptance.
2026-10-17. Finite radiator air-valve inserts and workshop stock.

Scope
23 original inserts retain their radiator identities. Five separately identified
spares, one per authored grade, occupy a new native Blender workshop rack.
The hidden grade-variant draw loop is retired when this bank is bound. A grade
setter cannot exchange a physical part. Unscrew, release, pick up, carry, offer
to an empty cold cap, catch the thread and screw home use production input.
The stock owner saves identities/locations; radiator, shared heat, case and NPC
authorities remain separate. Missing/loose inserts participate in pressure loss.
This does not implement the final radiator repair-completion endpoint.

Native rack
The fixed rack has metre UV charts, two catalogue PBR partitions, a timber tray
with five blind pockets, a backboard, continuous welded support angles,
standoffs and slotted screws entering the mounting wall. Generated textures
contain no lettering; labels and part grades are Label3D.
service_stock_native.json: two primitives, 7,364 triangles, strict tangent
agreement minimum 0.9999974086. service_stock_fit.json: 19 native fit checks.
Native front and support views were individually reviewed. Existing registered
timber/iron maps are reused; no new bitmap texture or material key is added.
The imported rack needed narrow mesh-compression exemption after its small
pocket/bevel UVs collapsed. The precision allowlist now checks 26 assets.

Hand diagnostic
orifice_hand_poll.log.receipt.json.gz: completed exit zero, no failure lines.
CORRECTION: a later stderr review found one script error in the boolean-version
rejection case, also recorded in that receipt. Returning false via an operand
error was not clean validation. The service_finish stage corrects type ordering
and repeats the input bench; this historical run is not error-free proof.
orifice_hand_poll/packing_review.json: 406 loaded-surface
checks, 20 inherited pose cases, no failures. Additional input assertions
exercise actual insert exchange, click/mouse/release, walking while holding a
spare, retained grade-change event, strict JSON validation, duplicate-slot and
boolean-version rejection, changed-pose restore and pre-stock save migration.
The bench has one radiator and five spares. It does not prove a B1-to-2B route,
disk reconstruction, player discovery or human appearance acceptance.

Failures retained
Earlier orifice_*.log/receipt/stderr archives include a type-inference parse
failure, wrong GLB material-name assumptions, imported UV collapse, context
occlusion, a fixture changing a stable radiator ID, and an overly close macro
camera that lost the carried insert behind the eye. Corrected input must keep
the part visible; it is not replaced by direct mechanism setters.
Whole-part convex collision also falsely widened the insert stem. The actual
stem and hex head now have separate shapes, with the native hex orientation.
The failed native standoff probe struck an intentional screw shank; the
corrected bearing probe is offset from that shank. Both reports are retained.

orifice_world is the rejected first building placement. It failed two rack
wall-bearing checks: the proposed location had no backing wall and was hidden
behind existing furniture. Its added detail capture also left an independent
camera offset before the fuse fixture, producing 40 downstream failures.
The correction mounts the rack on the shop's real north wall, facing inward,
and restores the standing camera before the fuse interaction sequence.
orifice_world_fitted.log.receipt.json.gz: completed exit zero, 981 checks,
zero failures and no script errors. The existing physical fuse replacement,
rating refusal and load proving sequence passes in the same composed world.
Both rack standoffs meet the actual wall. All nine radiator/rack views and the
fuse completion frame were individually inspected. The rack is visible and
clear of the toolboard; this fixed camera review is not a walked access proof.
Startup was 90,980.9 ms; total run 134.16 seconds. The same seven-Texture-RID
shutdown warning persists, byte-identical to the previous stage's stderr.

Immediate visual queue from these captures
2B_union_detail: the union hardware is too pale and uniformly banded; under
the flashlight it reads more like varnished wood than machined metal. Inspect
its actual material binding, roughness and grain direction before regenerating
maps. Keep the casting's separate skin. Vent/brass close views show broad
faceting and smooth thread lands. Refine them together in a native fitting
batch. The new rack has a strong timber grain at this scale; review its map
amplitude and end-grain treatment with the adjacent bench. These are visual
defects, not closed by the loaded-PBR/tangent checks above.

Limits and next work
This packet provides scoped diagnostics, not schema-2 runtime_contract proof.
No comprehensive surface or zero-leak acceptance is claimed. The earlier
seven-Texture-RID shutdown warning remains under investigation. Physical pitch
and sliding shims, repair completion through retained service authorities,
partial-state migration edge cases, full disk restore, broad suites and human
acceptance remain open. Brass finish, cloth realism and visible cap-thread
geometry remain visual defects; a passing interaction bench does not close them.
The V2 player minigame entry stays disabled while its replacement is unfinished.
The entire V2 build remains incomplete. Older packets retain historical input
bindings; source_inputs.json binds only this stage's current source/art inputs.
