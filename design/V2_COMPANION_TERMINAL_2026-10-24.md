# Autonomous service companion — implementation ledger

Evidence class: **INERT**. Audit, construction decisions and unfinished work;
no runtime qualification, ledger promotion or human acceptance.

## Audit before replacement

Owner directive: autonomous companion terminal, received after the frame-mitre
repair. This supersedes the older prohibition on a keyboard and conversational
display for this device. It does not supersede game-state ownership or import
requirements. Keep the conversation on physical paper under a glazed reading
bed, with a folding mechanical keyboard, rather than restoring PhoneOS.

Verified canon: Bible VIII.2 and VIII.5.h–l; campaign begins November 10,
1928, Queens. Vantry built the Orison in 1912 and ceased servicing it in 1924.
Signal equipment has an exceptional technological advance; motors, propulsion,
power storage and the inspection lamp do not inherit that exception. Phenolic,
brass, tinned steel, braided flex, ordinary lamps and heavy batteries remain
the material and technological grammar. Do not invent a different year.

Historical form references: the Smithsonian's
[Corona portable](https://americanhistory.si.edu/collections/object/nmah_849923)
has a folding carriage and a three-row keyboard. Its folding arrangement is
inspiration for a compact instrument, not evidence for our inverted keyboard
hinge. The Smithsonian's
[de Bothezat archive](https://airandspace.si.edu/collection-archive/de-bothezat-helicopter-album/sova-nasm-2002-0035)
documents experimental rotor machinery and 1923 test records. Neither source
proves a pocket-size flying radio historically possible. Sustained powered
flight at this size is the explicitly fictional extrapolation required by the
owner's companion request. Show rotors, guarded blades, motors, supported shafts,
linkages and stabilization; do not silently justify propulsion with Rule of Signal.

Repository state: canonical checkout remains **codex/v2-acoustic-topology** at
**7a548239**, with an unrelated spatial-manifest edit. Existing owned integration
is **codex/v2-main-integration-20261024** at **4d9a1c27**, draft PR23. Keep this
work there with the already preserved repairs rather than mixing into canonical
contributors' changes. Latest fetched main is newer and remains to be integrated.
Other contributors hold the shared Godot lane; diagnostics are queued, not passed.

Engine: project requests Godot4.7; shared runner currently uses4.7.1-stable.
Desktop Forward+,1280×720 reference viewport. Avoid new render viewports,
unbounded physics queries, skeletal machinery or a resting rigid-body solver.
Existing handheld already has an isolated right-third SubViewport and three
unshadowed presentation lights; world placement must retire that extra world
when enabled, not add another perpetual pass on top.

## Existing owners and integration seams

| Responsibility | Existing implementation / preservation requirement |
|---|---|
| Construction | **build_service_radiophone_v2.py**, **radiophone_printer_cartridge.py**, editable native GLB source; preserve datum-driven printer and hot type |
| Runtime model | **mechanical_teletype.gd**, **service_radiophone_stock.gd**; catalogue PBR, metre UV, maps/mips, moving feed, selector, impression and paper history |
| Device state | **service_set_prop.gd**; radio power, incoming-call state, lamp and WorkOrders annunciators |
| Presentation | **service_set_carrier.gd**, instantiated by **orison_v2_runtime_root.gd**; currently camera-owned isolated render world, no autonomous navigation |
| Real lamp | **PlayerController** owns emitter/optics; changing device posture must not create another gameplay lamp or falsify its power |
| Direct manipulation | **service_set_hand.gd** supplies hits to the existing constrained player hand; free-cursor inspection and same hover/acquire target owner |
| Input | **PlayerController** lock/inspection/pause priorities; existing **LineEdit** text entry in **songbook_panel.gd** supports native editing/IME rather than a handmade key parser |
| Human dialogue | **ResidentConversations**, **CaseDialoguePanel** and authored resident trees retain their flags, trust and case authority; protected conversations interrupt companion typing |
| Work / inventory | **WorkOrders**, **MaintenanceInventory**; conversation may report their current facts, never privately grant parts or advance jobs |
| Save | **RealityState**, **reality_save_document.gd**, background save queue; bounded companion memory needs explicit validated campaign integration before persistence is claimed |
| Weather | Authored campaign calendar, clock and existing weather reporting; do not derive a second date or invent a forecast |
| Network | Existing HTTP transport is live weather only. No production LLM backend or credential framework found. Offline conversation is the required default |

## Implementation boundaries

Pure modules now separate input interpretation, bounded conversation memory,
structured authored replies and optional provider selection. The parser accepts
reasonable phrases, resolves ambiguous parts against a freshly supplied visible
set, and drops vanished clarification targets. Every turn receives a new context;
old inventory and observations are not reused as current truth. Requested physical
actions direct the player to the real mechanism and execute no state change.

The optional provider seam can select only approved authored reply IDs. It has
no network implementation or generated prose path yet. This deliberately limits
what it can assert; it is not a completed language-model feature. Request budgets,
timeout/cancellation and stale-response guards belong to the presentation adapter.

The initial structured library contains78 original lines and six follow-up
branches, including three four-stage conversations with specific authored forks.
Event lines require an explicit producer, are once per memory,
and have no random timer. Relationship counters do not modify resident trust.
Domain diagnostics cover stale context, ambiguity, impossible repeated requests,
branch continuation, corrupt memory, bounds and provider restrictions. Static
parsing is not engine compilation or actual-input qualification.

Movement implementation must use bounded candidate positions and reusable shape
queries, player-velocity prediction, acceleration-limited pursuit and separately
damped station keeping. Candidate visibility/clearance checks run at a fixed budget;
collision motion remains swept every physics tick. No constant orbit or sine bob.
Typing requires full open-keyboard clearance and a steady reachable presentation.
Recovery is permitted only outside the current view and behind verified occlusion.

The physical input adapter must use one focus owner, preserve draft on cancellation,
close before protected dialogue/pause, and release only locks it acquired. Actual
click/motion/release still owns the native mechanisms. Text entry is a deliberate
conversation action, not an automatic focus grab when the player merely looks.

## Issue log and milestones

| Location / reproduction | Severity / evidence | Repair | Verification |
|---|---|---|---|
| Current device follows camera rigidly | High; carrier reparents to camera and overwrites pose every frame | Autonomous world placement pending | Not implemented or measured |
| Conversation interpretation and memory | High; old PhoneOS is archived and inappropriate | Isolated offline modules, bounded memory and78 authored lines | Offline31 checks passed; no world context, focus or save integration |
| Device square corner joints | Medium; old box-strip construction | Single formed pan, continuous leather jacket, velvet lining, pierced screw-fastened brass guards | Native v11 reviewed; imported fastening observations failed33 checks, diagnosis pending |
| Keyboard and propulsion | High; previous installed device has neither | Separate native candidate, folding keyboard, guarded rotors, two-color32-by-12 tile display | v6 mechanism diagnostic failed as a whole; candidate remains uninstalled |
| Glazed paper reading bed | High; v6 dry/wet captures hide carbon lettering | Opaque masked companion glyphs with ordinary depth testing; typed moisture initialization | v4 shader-default abort retained; v7 rendered rerun queued |
| Context / campaign persistence | High; no adapter yet | Add read-only witnesses and validated save field | Not installed |
| Existing carrier controls after outward lid repair | High; preserve circuit owners and actual manipulation | Consistent outward native cover travel | Current original-carrier world route: separately scoped71-check schema-2 contract, captured-input scope only |
| Portable candidate native source | Medium; initial reopen reported25 missing texture paths | Avoid second relative-path remap after explicit image rebasing | Corrected native reopen resolves all paths; original failure retained |

A: audit and source map established; runtime integration remains. B: formed-shell
candidate built, imported verification incomplete. C–G remain open. The isolated
conversation modules are not a completed companion or normal V2 feature.
The original-carrier baseline records first-use spikes and frame-time tails;
independent movement will need a matched route with doors, inspection and typing.
Existing curtain measurements do not qualify this replacement.

## Native candidate review

**build_service_companion.py** opens the installed editable radiophone source,
preserves its printer and controls, and writes a separate candidate in **tmp/**.
Two guarded pitched rotors have bored motor barrels, supported shafts, cradle
straps and bearer ties. The keyboard has a continuous pin, alternating bored
knuckles, returned tray edges, side latch and keeper, hard open stops, bearer
brackets and paired articulated support stays. One native reusable keycap and
43 mounting sockets include space, return and backspace. Runtime instancing,
keystroke depression and control labeling are still pending.

Original native v1–v3 renders are retained as rejected construction diagnostics:
v1 did not show the repeated keys; v2/v3 closed the tray through the existing
writer; early review lettering also had incorrect spacing/contrast. Version4
moves the complete hinge forward onto actual bearers, leaving the writer under
a hood when closed. Version5 adds91 native keycap-clearance samples over the
90-degree deployment and preserves complete review instances in the editable
file. Minimum keycap/printer clearance is19.871mm against the independent
original printer vertices. This is not a whole-assembly intersection guarantee,
environment sweep, collision qualification or gameplay test.

The candidate exports47 material primitives and28,510 triangles; all85 added
stocks are closed positive-volume pieces. Exported tangents pass at minimum
agreement0.9999917. All referenced native image paths resolve. Repeated keycaps
are source instances for review and sockets for one eventual runtime MultiMesh;
47 does not include the future key MultiMesh or Label3D draws. No frame-time or
GPU saving is claimed. Native review images are not Godot captures.

Diagnostics: **art/reviews/v2_companion_20261024/**. Current editable candidate
remains in **tmp/v2-companion-native-v5/art/blender/**, rebuilt by the committed
builder. No candidate GLB has replaced the production radiophone. Imported
UV/PBR/mip checks, full moving-assembly clearance and actual typing remain open.

## Keyboard-back flip display — owner addition

The owner requested a very low resolution physical pixel image and an animated
cartoon mouth on the keyboard's backside. Native v7 adds a32×12 field of384
square, two-color tiles. Dark phenolic bodies carry thin ivory faces. Actual
spindle bores and32 column shafts support rotation; a continuous open bezel,
backing and four standoffs keep the array clear of the keyboard's moving posts.
The display faces the player when the keyboard is closed and turns under the
keyboard as it opens. No emissive LCD, screen viewport or generated lettering.

**companion_tile_display.gd** binds two native MultiMeshes. Image changes queue
only affected tiles, limit active rotations to32 and start at a240-tiles/second
budget. A settled image disables processing and performs no resting transform
writes. Batched quiet mechanical ticks accompany actual flips. It accepts32×12
two-color illustrations and has content, listening, worried, sleeping and
mouth-aperture images. The mechanism adapter derives speaking animation from
the original printer's real printing/character state. Explicit illustrations
remain visible until cleared rather than being overwritten by the idle face.
These are written runtime behaviors, not yet verified Godot operation.

The key construction also now has real guide bores and molded posts. Regular
keys share one40-instance MultiMesh; space, return and backspace use three
independently authored sizes, preserving metre UVs instead of scaling one
textured cap. The expanded candidate exports52 material primitives and32,518
triangles with134 closed positive-volume added stocks. Exported tangents pass.
Source counts exclude runtime text and are not measured frame-time results.

Native flip-review v1 exposed a portable-source path failure despite Blender's
zero process exit; its warnings and images are retained as a failed diagnostic.
After correcting the save remap, flip-review v2 reopens the saved source, checks
all image paths before rendering and produces smile, half-flipped, open-mouth,
return and umbrella views. The midpoint exposes actual edge-on tiles and shafts.
These native renders establish construction/appearance only.

An optional model/stock-applier seam on the existing physical printer preserves
the original installed model by default. The companion mechanism uses that seam
for its separate candidate. The original carrier is still installed; navigation,
typing focus, authoritative context/save wiring and occupied-world comparison
remain open. **CompanionMechanismBench** is queued windowed with imports and
checks imported surfaces, hardware poses, key travel, power gating, tile images,
bounded updates, resting writes and captures. It is explicitly an INERT domain/
mechanism diagnostic, not proof of actual player input or whole-V2 acceptance.

First imported mechanism run **mechanism_v1** completed in14.27s with232 failed
checks out of2,010 and three script errors. Blender had generated suffixed
material names outside the declared finish ABI; the refused stock provider then
left an invalid paper datum. Default mesh compression also distorted small metre
charts and tangent derivatives. The hot-type shader check incorrectly requested
generic sampler names instead of its real four-map ABI. The run is failed as a
whole; its successful motion observations are not promoted to qualification.

Native v8 reuses materials by name and checks13 declared finish names. The
optional presentation seam now refuses an invalid provider before downstream
paper setup. A narrow measured precision policy covers this companion asset;
no UV/tangent threshold was loosened. The shader check requires the existing
**steel_albedo**, **steel_roughness**, **steel_normal** and **type_plate** maps.
The full **mechanism_v2** rerun and original-printer regression remain queued.
Reader audit reports zero NEW fields; import precision policy has zero missing
or wrong sidecars. No occupied-world performance result is available yet.

## Formed carrying-case shell — owner addition, October 25

The owner rejected the remaining square-ended housing corners and requested a
single formed shell, structural ornamental guards, leather/velvet and real glass.
**build_companion_formed_shell_study.py** constructs a separate native candidate
without overwriting the inputs frozen for the queued mechanism test. Eight old
stocks—the four housing strips, rear pan and three keyboard edge strips—are
retired by exact native triangle matching. The printer, controls, guide plate,
keys, hinge, latch, stays and tile module remain.

The replacement is one continuous rounded structural pan with integral bored
fastening bosses. A continuous moulded leather jacket includes the back, with
matching speaker and mouthpiece ports. Registered **velour** supplies the fitted
cotton-pile lining. Continuous rolled brass edge guards and pierced foliate
corner plates protect the case; actual slotted screws seat on integral bosses
in the plates and enter the structural pan. The keyboard perimeter is also one
rounded piece. A 1.2 mm rounded glass pane sits above the reading bed in a gasket
and retaining frame, leaving the moving printer below it uncovered.

Final isolated **shell_native_v7** exports 59 primitives and 40,358 triangles;
its 29 added stocks are closed, connected and positive-volume. Native metre UVs
and tangents pass with minimum tangent agreement 0.9999917. All native image
paths resolve. Front, corner, rear and typing views were rendered and reviewed.
Compared with the preceding candidate this adds seven primitives and 7,840
triangles; no performance improvement is claimed. Draw consolidation and the
actual-world before/after route remain necessary before installing the device.

The original v3 Boolean sliver/UV failure and v6 texture-path relocation failure
are retained in **shell_native_logs/**. Native cleanup is volume-bounded, and
the output blend location is established before making texture paths relative.
These are construction diagnostics, not imported/runtime qualification.

The candidate remains in **tmp/companion_shell_study/v7/**. Runtime glass
refraction/condensation binding, imported UV/PBR/mipmap checks, readable text
through the glass and mechanism clearances remain open. No production carrier
or asset was replaced by this study. The earlier **offline_v2** domain rerun
passed all 31 checks and was separately committed as **14cae0e4**; the original
printer regression and imported mechanism checks remain pending.

### Formed candidate published for combined mechanism checking

Native **shell_native_v11** adds a properly rebated gasket, a retaining frame
with four integral clamp arms, and a stepped reading-shaft bearing. Twenty
native bearing samples place the clamps exactly against the original cartridge
frames. Three more measured contacts verify the shaft-bearing flange and both
glass seats; the shaft has 0.25 mm radial clearance through its bearing and
clear openings through steel, leather and lining. The measured pane is 1.2 mm
thick. Its lower clear opening leaves 4 mm beyond the retained delivered-ink
baseline. These are native fit measurements, not imported or readability proof.

The candidate exports 59 primitives, 42,824 triangles and 20 exact material
names. Native UV/tangent checks pass; all image paths resolve. Front, corner,
rear and typing renders were reviewed. The publisher resets the native keyboard
to its closed pose, preserves the original printer/control data, and updates
the separate companion asset/hash and accessory finish declarations. Rebuild
the pristine companion first, then the formed study, native fit inspector and
publisher. It deliberately refuses to apply the shell twice.

| Location / reproduction | Severity | Evidence | Repair / verification |
|---|---|---|---|
| Housing and keyboard perimeter corners | Medium visual construction defect | Four box strips and three square keyboard edge strips in original native stock | Continuous formed pan, jacket and keyboard frame; native renders reviewed, import pending |
| Glazed reading bed attachment | Medium mechanical presentation defect | Initial study had a frame without attachment to printer | Four integral clamp arms; 20 native bearing samples, zero measured gap |
| Reading-wheel shaft through case | Medium mechanical presentation defect | Shaft entered solid case/lining | Bored steel/leather/lining and stepped brass bearing; 0.25 mm measured radial clearance |
| Service lid at full opening | Medium mechanical presentation defect | Existing negative rotation intersects pan in 38/107 sampled poses; paired cutaway renders retained | Outward rotation has zero intersections in 107 samples; coupled tween/read/write/axis repair written, actual-input regression queued |

Runtime presentation now has restrained refraction on the reading pane and the
existing side-specific moisture shader as an overlay. Moisture values are
supplied explicitly; this presentation does not invent weather or scan rooms.
Connecting the eventual world companion to the authoritative humidity/rain
owner remains open. Physical Label3D key legends follow cap depression and hide
with the closed keyboard. No generated lettering textures or pixel viewports.

The original **mechanism_v1** failure is preserved. The v2 and v3 brokers were
cancelled before lane acquisition to combine the measured lid repair and key
legends with the first formed-shell import check. Neither ran Godot or produced
a test result. **mechanism_v4** is queued with two imports, the expanded native/
glass/mechanism bench, original-printer regression, and actual grab/motion/
release on the existing physical controls. It still does not qualify companion
navigation, typed conversation, save integration or whole-world performance.

The current-original-carrier 811-frame world baseline is separately recorded
in **V2_COMPANION_WORLD_BASELINE_2026-10-25.md**, committed as **61ae5c70**.
The lid-direction repair was written after that baseline; the baseline's timed
phases do not operate the lid. Future comparisons must disclose source changes.
No companion runtime qualification or shipping cutover is claimed here.

### Construction preparation report

REPORT - companion-formed-construction-preparation - 2026-10-25

Branch / starting HEAD / local origin/main / merge-base:
**codex/v2-main-integration-20261024 / 61ae5c70 / 862e54a2 / 55e60195**.
Worktree clean at end: no; unrelated owned door, disabled resident-world drafts
and import churn remain. This source checkpoint stages named companion files
only, with the companion-only import-policy and spatial additions. It is not
a merge candidate or an installed autonomous companion.

Protected 17/17: not recertified by this preparation report. Selector: V2,
with the existing V1 rollback retained. Ledger: no promotion claimed; the
dirty-tree comparison against the earlier clean main board has 128 regression
lines, including expired runtime/surface proof. Those remain merge blockers;
this report does not rebaseline them or claim semantic regressions are excluded.

Gates: complete dirty-tree preflight **static_v1_board** has 103 PASS, nine FAIL
and one INCOMPLETE. Its original results are preserved. Physical-import failures
include the three then-untracked new model/import pairs; the named companion
pair is included in this checkpoint. Other pairs belong to the pending door
work. The 34 failing spatial changes were reviewed: 33 existing storefront
anchors and the companion's generated key-name template. One additional test
name template was report-only. All prior 10,879 manifest records were preserved;
the targeted follow-up audit is clean. Only the companion record is staged with
this family. Reader reports zero NEW fields; mesh precision policy reports zero
missing/wrong sidecars. GDScript syntax and document lint pass. The combined
windowed Godot batch remains pending; no imported or input pass is claimed.

Numbers requested: 42,824 native triangles in 59 primitives; 20 exact finish
names; 23 native clamp/shaft/glass contacts, 32 guard-bearing samples, 16 clear
axial-bore checks and a 1.2 mm glass pane. Native figures exclude runtime key
legend draws and do not establish frame-time cost. The world baseline and its
first-use spikes remain separately reported in **61ae5c70**.

Changes outside the expected new-device boundary: the original printer gains
an optional presentation seam with failure guards, and its service-lid tween
and authoritative hand read/write/axis consistently open outward. The old model
and carrier remain the default. The native clipping diagnostic motivated the
pose correction; actual-input regression is queued. WorkOrders, radio, lamp,
paper history, call and save authorities retain their existing owners.

Open: imported geometry/finish/contact checks, dry/wet text readability, input
regressions, independent movement, typing focus, authoritative context/save
integration, personality integration and repeated world performance comparison.
Decision needed from owner: none.

BLOCKED merge qualification: construction preparation awaits the combined runtime checks.

### First formed-shell run: initialization failure, original records retained

The **mechanism_v4** run reached the moisture checks, then emitted two script
errors when **float** received an unset shader parameter. Its coroutine did
not finish, and the wrapper killed it at170 seconds. There is no suite verdict
or imported qualification from that run. The fix explicitly initializes both
face uniforms and keeps typed presentation caches, avoiding reads of unset
renderer defaults and redundant uniform writes. A diagnostic deadline now
writes partial failure observations and exits if the bench aborts unexpectedly;
it cannot turn partial observations into a pass. Syntax checks pass; the rerun
is pending.

The separate historical **ServiceTeletypeTest** hit its120-second ceiling while
composing the full world, with no verdict and no script errors. Source diagnosis
also establishes obsolete assumptions: the unchanged original heated-type model
has neither **SupplySpool** nor **TakeupSpool**, and no **FeedGear** nodes, while
the old test indexes both spools and expects four gears. The original test is
left unchanged as legacy fixture debt. No fake reels are added to satisfy it.
Its original timeout and source diagnosis are preserved.

The separately scoped **ServiceSetHandTest** diagnostic completed70 actual-input
checks in5.91 seconds with no failures or script errors; its capture shows the
outward-open lid. Its test-written observations are INERT, not a schema-2 world
contract. The failed batch is not promoted to runtime qualification from that
leg. **mechanism_v6** reran the corrected small mechanism
bench and **V2ServiceSetHandWorldTest** on the long runner with600 seconds for
the actual composed-world E/Space/grab/motion/release route. The unchanged
standalone diagnostic is reused rather than repeated. v5 was cancelled before
acquisition to replace the known retired-reel fixture with this current route.

All v4 stdout/stderr, wrapper receipts and separately written observations are
under **art/reviews/v2_companion_20261024/mechanism_v4/**. The original model,
carrier, call/radio/lamp/WorkOrders and save owners retain their authority.
No companion navigation, typing or save qualification is claimed.

### v6 outcome: script recovery, contact failures and unreadable glass

The corrected small bench completed in19.44 seconds, with2,145 checks,33 failed
contact checks and zero script errors. It is failed as a whole. The original
moisture-default exception no longer aborts it, but no successful sub-checks
are promoted to qualification. Original receipts, all test-written diagnostics
and dry/wet/travel/typing captures are retained.

The captures expose an actual presentation defect: the refractive window
replaces the transparent Label3D carbon lettering with the opaque scene copy,
leaving the pane blank. The proposed repair makes only the companion's paper
glyphs opaque masked ink with ordinary depth testing and no cast shadows.
It adds no viewport and preserves the glass effect. This still needs a rendered
rerun. Godot's [3D-text documentation](https://docs.godotengine.org/en/4.4/tutorials/3d/3d_text.html)
describes the transparency/sorting limits; the retained captures establish the
failure here, rather than code inspection alone.

The33 failures are imported temporary physics-ray contact observations. They
are not waived from the native measurements. **CompanionContactProbe** is
queued to compare those same imported faces through physics, direct geometry
and numerically conditioned geometry calculations. It records diagnostics only
and does not declare a pass. Geometry, game collision protection and the
50-micrometre imported seat tolerance remain unchanged pending diagnosis.

The separate composed **V2ServiceSetHandWorldTest** run completed in186 seconds
with zero script errors. Its test-written, separately scoped schema-2
**carried_controls_runtime_contract.json** records71 successful checks and five
executed contracts for the original installed instrument's specific targets,
latched manipulation, limits, circuit owners and interruption. Its source
digest remained unchanged throughout the run. This contract applies to those
captured inputs and that existing carrier, not to the new companion or later
candidate glyph changes. The companion remains uninstalled and unqualified.

### Exported fastening diagnosis while the imported probe waits

A float64, two-sided barycentric query of the unchanged exported GLB finds both
bearing surfaces at all32 points. Maximum absolute gap is1.862645149e-9 metres;
the steel front datum ranges0.027499999851 to0.027500001714 metres. This source
calculation supports neither an imported-geometry pass nor a physics diagnosis.
The imported comparison is still needed; the33 original failures remain open.
The source SHA and all32 observations are retained in **export_contact_diagnostic.json**.

### Imported contact diagnosis and rendered lettering repair

Windowed **mechanism_v7** finishes2,148 checks in16.3 seconds, with the same33
contact failures and zero script errors. It remains failed as a whole. Its dry
and wet reading captures were actually viewed: the masked carbon glyphs now
remain visible through the refractive pane, where v6 was blank. This is a
rendered presentation observation, not a successful mechanism-suite verdict or
proof of readability at every deployed distance.

**contact_probe_v1** completes in1.39 seconds, with zero script errors. Across
64 identical imported face queries, physics misses20 and returns37 off-datum
hits; direct metre arithmetic misses16 and returns41 off-datum hits. Arithmetic
conditioned to millimetres finds all64 faces between0.027499938384 and
0.027500122786 metres, within the unchanged50-micrometre seat tolerance.
The draw transforms are identity. No imported geometry, asset scale or gameplay
collision was changed by this comparison. It diagnoses a small-triangle query
failure in this measurement path, not a missing manufactured contact.

The visual contact bench now queries the same imported triangles using the
measured conditioning. Each of32 positive seats is paired with a guard moved
3mm away and restored; the negative control must both reject the seat and
measure the introduced gap within the original50-micrometre tolerance. It
changes neither runtime collision nor contact requirements. **mechanism_v8**
is queued; no pass is claimed before that run. The original v6/v7 failed checks,
probe data, executed sources, dry/wet frames and wrapper receipts are retained.
