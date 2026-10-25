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
| No companion parser / memory | High; old PhoneOS is archived and inappropriate | New isolated offline modules and authored library | Syntax only; queued domain diagnostic |
| Keyboard / propulsion absent | High; native printer is an existing working mechanism, not a flying companion | Separate Blender candidate with guarded rotors, cradled motors and folding keyboard | Native v5 rendered; not imported or installed |
| Context / campaign persistence | High; no adapter yet | Add read-only witnesses and validated save field | Not installed |

A: audit and source map established; runtime integration remains. B: native
candidate construction is in progress. C–G remain open. Do not describe the isolated conversation
modules as a completed companion, normal V2 feature or performance improvement.
Before enabling world placement, record repeatable exploration/turning/doorway/
inspection/typing routes against the unchanged carrier, then compare distributions
under the same settings. Existing curtain measurements are not this baseline.

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
