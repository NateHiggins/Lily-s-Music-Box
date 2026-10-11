# V2 environment dossier follow-ups: merge report (2026-10-10)

Evidence class: **INERT**

This report covers branch `claude/v2-dossier-followups` from main d38e7795
(the dossier merge) to its tip c09a37fd, which the owner asked to merge
once the in-flight work was complete. It promotes nothing. Row, space and
anchor ids are written in bold outside the fenced block. The lane receipts it
cites are wrapper receipts (`orison.run-receipt.v1`, evidence kind
suite_run). They show that a suite ran and how it ended. They are not schema-2
runtime_contract receipts, and they are not runtime proof (RUL-003).

Sources: the packet `art/reviews/v2_environment_design_20261008` (README.md,
`content/status.py`, `change_register.json`, `implementation/<tag>/` for the
tags followups4, slice83, slice84, slice85, switches and main_d38e, the last
added by this report's commit), `sources/switch_replica`, lane output under
`C:/ov/envimpl_out/<tag>/`, and the candidate verifier's report for the tip at `C:/ov/reports/c09a37fd0018/verification.{md,json}`.
Read it beside `design/V2_ENVIRONMENT_DOSSIER_MERGE_REPORT_2026-10-10.md` and
`design/V2_ENVIRONMENT_DOSSIER_MERGE_ERRATA_2026-10-10.md`; this report
settles what the errata's section 4 left waiting on the lane.

## 1. Developer report

```
REPORT - V2-ENV-DOSSIER-FOLLOWUPS - 2026-10-10
Branch / HEAD / origin/main / merge-base:
  claude/v2-dossier-followups /
  c09a37fd0018a268f694f136637fad0b182a84c4 /
  d38e77953001b2e28c24cc710c047ebfda648fe1 /
  d38e77953001b2e28c24cc710c047ebfda648fe1
  This report and its sidecar are committed on top of c09a37fd; main
    fast-forwards to that commit (no merge commit).
  6 commits in d38e7795..c09a37fd, squashed with git commit-tree from 17
    WIPs. Each commit takes a WIP's exact tree; the five code commits take
    trees the lane verified:
      1c5aa391 follow-ups (tree of 35d42b3f; game/art as 88c5a68f)
      419cb5dc slice 83 (tree of a03be466; game/art as 34b4c7c8)
      8caf89aa slice 84 (ebe9503b's tree plus 9535800b's ConnectedWorld test)
      7aa90d51 slice 85 (tree of 9535800b)
      c3737f20 light switches flush, BW-013's plate removed (tree of f70c3c95)
      c09a37fd evidence and statuses for slices 84-86
  Every commit message declares INERT. origin/main is an ancestor of the
    tip.
Worktree clean at end: yes. The branch worktree is clean once this
    report's commit is made. A local branch, backup/v2-dossier-followups-wip,
    keeps the WIPs reachable from 94e1832b; it is not pushed. The last WIP,
    42a9b3b3 (the replica), is reachable from no ref.
    The lane checkout C:/ov/envimpl is left detached at d38e7795, dirty
    only with Godot's .import rewrites.
  The canonical checkout C:/PleaseRemainOnTheLine (main) holds 3 modified
    paths (art/renders/insitu/shots.md; enamel_appliance/material.json and
    orison_v2_prep_cabinet.gd, line endings only) and 274 untracked
    entries. None is a path this branch changes; the fast-forward leaves
    them as they were.
Protected 17/17: yes (verifier PASS: 17/17 unchanged vs merge-base, 0
  authorized selector changes; 7 of 17 match the historical recorded
  baseline, as on main)      Selector: v2 (owner-authorized default
  2026-09-21; building_root_selector.gd unchanged, so the
  ORISON_BUILDING_ROOT=v1 rollback is unchanged)
Ledger before -> after:
  FIRST_SLICE_TECHNICAL 7, GOLDEN_SHIFT_V2 8, FULL_BUILDING_STRUCTURAL 127,
  FULL_BUILDING_RUNTIME 42, PRODUCTION_CUTOVER 151, V1_RETIREMENT 153
  -> 7, 8, 127, 42, 151, 153
  240 requirements. Statuses are unchanged: ABSENT 21, SHELL_ONLY 3,
  PROGRAMMED 119, SPATIALLY_PROVEN 69, RUNTIME_PROVEN 27, HUMAN_ACCEPTED 1.
  requirements_changed: []
Gates (real exit codes, -LogPath):
  Static gates, merge-base board -> candidate board, from
  C:/ov/reports/c09a37fd0018/verification.json (fresh checkout, --no-godot).
  Base board 01:41:43Z at d38e7795 (cached from the first run), candidate
  board 01:55:35Z at c09a37fd, both 2026-10-11 UTC; fresh checkout, clean.
  The static gates take no -LogPath; their stdout hashes are in that file.
    completeness (ledger)  2 -> 2   INCOMPLETE both. Red on main by design.
    spatial                0 -> 0   all drift counts 0; records 9386 -> 9455
    systemic               0 -> 0   new_actionable 0 -> 0, new_review
                                    21 -> 21; 65 findings both
    period                 0 -> 0   fail_lines 0
    reader                 0 -> 0   unread 1120 -> 1120, 0 new vs baseline
    carriers               0 -> 0   forbidden 0, legacy_uncovered 0,
                                    ambiguous_dynamic 2 both
    rulings                0 -> 0   errors 0, warnings 0; citations 33 -> 34
    tools tests: all 42 exit 0 on both boards (the 42 the previous report
      lists)
    design-doc lint: 0 on the candidate. This report: lint_design_doc.py
      exit 0, no requirement status changes.
    gate files changed by the candidate: 1,
      tools/orison_spatial_dependency_manifest.json, regenerated with
      --update-manifest for moved and new anchors.
    Verifier last line for c09a37fd: MERGE-CANDIDATE c09a37fd0018a268f694f136637fad0b182a84c4
    An earlier squash of the same trees, 2647be6e (its messages credited
      the clearance figure to a replica not yet in the packet), verified
      MERGE-CANDIDATE with the same board (C:/ov/reports/2647be6ee141).
    The commit carrying this report is verified in fresh mode with
      --report design/reports/V2-ENV-DOSSIER-FOLLOWUPS-2026-10-10.json and
      --base d38e7795 before main moves.
  Godot suites (lane receipts in implementation/<tag>/receipts; each
  receipt's log.stdout is its -LogPath under C:/ov/envimpl_out/<tag>/):
    The verifier ran with --no-godot. Suite-run evidence is the lane
    receipts: 116 in 6 tags (every receipt in followups4, slice83,
    slice84, slice85, switches and main_d38e). Every run went through
    tools/lane.ps1 with -LogPath in the lane checkout C:/ov/envimpl (its
    dirty paths are Godot's .import rewrites).
    At the tip's game and art (f70c3c95, the switches tag):
      exit 0: LightSwitchModelTest "SWITCH MODEL: 1449 checks, 0
        failures"; UpperLighting "9677 checks, 0 failures";
        ConnectedWorld "57508 checks; 0 failures"; HouseholdState "154
        checks, 0 failures"; FabricationBatch domestic_objects
        "module_checks=10220 failures=0"; SwitchCensus "0 not flush over
        the whole footprint"; import x2.
      exit 1: ApartmentBatch "26885 checks, 204 failures", labels
        identical to slice 85's (S1, section 4).
    Earlier trees, by tag (non-zero runs and their class in section 4):
      followups4 at 88c5a68f: 23 runs, 22 exit 0, among them
        apartment_door_route 45 wp, basement_route 88 wp, bedding 19
        beds 0 failures, blockout PASS, coal_delivery and coal_heap 36 wp,
        fabrication 6814 checks 0 failures, golden_repair 94 wp,
        laundry_route 17 wp, m08f PASS 29, mail_route 16 wp,
        patrol_stations 7/7, public_doors 17 wp, rear_wing_c 32 wp,
        resident_key PASS 86 wp, street_route 24 wp, tour_key 65/65,
        watch_pair 118/118, watch_register 87/87. Non-zero:
        apartment_batch 204 (S1).
      slice83 at 34b4c7c8: 21 runs, and a before-probe at 88c5a68f;
        non-zero apartment_batch 204 (S1), connected_world 8 (the
        pedestal tables), fabrication 54 (mip chain), integrated FAIL
        (1) (S9), m08e FAIL (1) (S10). Plus 7 runs at 2ea28ee0 (base_*),
        the dossier's merge-base, where all but the 8 table failures
        reproduce (those came with slice 4; main_d38e shows them on main).
      slice84 at ebe9503b: 14 runs; completion_all 154 wp 0 failures,
        each unit and the staff leg separately 0 failures. Non-zero:
        connected_world 508, the first, too-broad native check,
        narrowed in 9535800b.
      slice85 at 9535800b (frames reshot at 32784e13, before-runs at
        ebe9503b): 19 runs; connected_world 57503 checks 0 failures,
        vertical_route 124 wp 0 failures, blockout PASS. Non-zero:
        apartment_batch 204 (S1), fabrication 1 (harness: no camera
        station for F03_riser_hose), m11b 1 before and after.
      switches: census before (9535800b) and after passes 1-3, with
        each pass's suites; all exit 0 except ApartmentBatch 204 (S1).
      main_d38e at d38e7795: m11b FAIL (1), connected_world 8.
Numbers management asked for:
  Change register: 584 rows. verified 380, implemented 87, deferred 101,
    rejected 16 (main: 375 / 87 / 107 / 15). change_register.json equals
    content/status.py: 0 status or owner_notes mismatches.
    By priority (verified / implemented / deferred / rejected):
      P1 153 (117 / 14 / 13 / 9)
      P2 321 (220 / 34 / 63 / 4)
      P3 110 (43 / 39 / 25 / 3)
    7 status changes against main:
      deferred -> verified: B1_BOILER_ROOM-003, F04_LANDING-003 (slice 83);
        F03_SERVICE_HALL-001, F04_SERVICE_HALL-001,
        F05_SERVICE_HALL-001, F06_SERVICE_HALL-001 (slice 85)
      verified -> rejected: BW-013 (owner direction)
    65 more rows change owner_notes only:
      - 20 in the switch work: the 18 VESTIBULE-002 rows and
        F05_B_VESTIBULE-003, which cited the signal outlet, and
        F01_D_MAIN-004;
      - 18 in follow-ups 2 (packet evidence corrections);
      - 26 in follow-ups 4 and 5 (the errata's premises and citations);
      - BW-017 (follow-ups 5 and slice 83).
  Light switches: 144 V2 plates (census at 9535800b before the passes).
    Before: 139 stood 24-98 mm off their visible wall and 5 sat 12-37 mm
    behind it. After pass 3 (f70c3c95): 0 of 144 not flush over a 13 x 3
    grid of the rear face (meshes and multimesh finishes). The static
    replica (sources/switch_replica, run at the tip's data) puts each at
    least 4.0 mm clear of every casing, stile, skin seam and window
    joinery. No signal-outlet plate mounts.
  Slice 85: 12 anchors (risermarks, crate, hosecoil on F03-F06), 12
    furniture records, 12 wear decals; domestic_objects 138 assemblies,
    248 installations, glb 77,775,736 bytes.
  Diff vs main at the tip: 302 files (227 added, 64 modified, 11
    renamed), +69,621 / -5,794 lines. 243 are the review packet; the
    other 59 are +19,561 / -5,542. The 11 renames are slice 4's evidence
    moving byte for byte from implementation/slice34 to slice4. This
    report's commit adds 7 more: the report, its sidecar and
    implementation/main_d38e (manifest and 4 receipts).
    domestic_objects.glb 75,672,352 -> 77,775,736 bytes. surface_stock.glb
    is unchanged at 103,057,996, 1,799,604 under GitHub's 100 MiB limit.
Changes outside the expected file boundary, and why:
  The boundary: the packet; V2 owners, data and tests; art/blender family
  sources and scripts; art/data source plans; regenerated game/assets and
  fixtures. Outside it:
  - game/tests/light_switch_model_test.gd (LightSwitchModelTest) and the
    new game/tests/switch_flush_probe.gd: the owner's switch direction is
    held by the switch test, which now measures every plate's rear face
    against the finished wall and refuses a plate beside the toggle.
  - tools/orison_spatial_dependency_manifest.json, regenerated with
    --update-manifest for moved and new anchors (LF-normalized).
  - design/: this report, its sidecar, the errata note, and two lines of
    the dossier document (it no longer says the work changes no code).
  - No .import, .uid, project.godot, AGENTS.md or DOCS.md file changed.
    No V1 script changed.
Open findings not fixed:
  1. ApartmentBatch fails 204 checks at the tip (S1). It has the same 7
     label classes as at the dossier's merge-base 2ea28ee0 (192), plus 12
     in the receiver-texture class from BW-011's six radios. Not fixed.
  2. Integrated (S9), m08e (S10) and owner_service_finish's 54 mip-chain
     checks fail identically at 2ea28ee0. Their last runs are at 34b4c7c8
     (slice 83), not at the tip. M11B fails one ownership-lifecycle check on
     main d38e7795, at ebe9503b and at 9535800b; which check fails varies
     run to run. Not fixed.
  3. Eight suites with standing failures, and four of the previous
     report's unexplained receipts, were not re-run here (section 4).
  4. Fabrication capture refusals are a harness limit: F03_riser_hose in
     slice 85, and the five slice 82 stations. Not fixed.
  5. The 4 mm clearance comes from a static replica of the finish stack
     (sources/switch_replica, run at the tip's data). LightSwitchModelTest
     and the census measure flushness at runtime, not clearance.
  6. The errata note's section 4 says the follow-up runs wait on the
     Godot lane. They have run; section 4 here gives the results. The
     errata is left as written.
  7. The previous report's findings 6, 7, 8, 10, 11, 13 and 15 stand as
     the errata records them.
Decision needed from owner:
  1. Bible VIII.3 asks for a signal outlet beside the power socket in
     every room. BW-013's plate, removed at the owner's direction, was the
     only form of it, so VIII.3 is now unrepresented in V2. Either a
     socket form that reads as a socket (not a switch plate) goes beside
     the power sockets, or VIII.3 is amended or entered under the Bible's
     disputed texts.
  2. CITY_SHOP_OTIS_SON-001 (the carboy show-globe night lamp) stays
     deferred: the carboy glass casts no shadow, so its colour on the
     terrazzo needs a tinted light. It needs only a go-ahead, not a
     ruling.
  3. The previous report's decisions 1-4 stand, except the 16/16 light
     budget (its section 8, decision 7), which the errata withdrew.
MERGE-CANDIDATE c09a37fd0018a268f694f136637fad0b182a84c4
```

## 2. What the commits do

- **Follow-ups (1c5aa391).** They repair the suite failures the dossier branch
  introduced and correct the packet. ApartmentBatch counts its 18 units and
  its two script errors (SE1, SE2) are gone. The 5C bed has an inspection
  stance, the rear wing C route goes round 2C's bookshelf, garments sit on
  the native chairs, and the stock and furniture context inspectors read
  native seats. A positional-wear row is refused before mounting, and a
  refusal fails startup. The fabrication batch names its modules and prints
  one FAIL line per failure. The errata note, slice 4's restored evidence,
  slice 81's storm frames and the four lane baselines go into the packet,
  and the 15 -text paths the branch turned CRLF are LF again. Verified at
  88c5a68f (`followups4`), whose game and art equal the commit's.
- **Slice 83 (419cb5dc).** It adds a sconce on the south core wall of each
  landing lobby, F02-F06 (**F04_LANDING-003**, **BW-017**'s "one per
  landing"), and two cage bulbs over the B1 firing aisle on their own circuit
  (**B1_BOILER_ROOM-003**). The node probe now takes lamp-off frames at 20:00.
- **Slice 84 (8caf89aa).** The **F01_1A**, **F03_3D** and **F04_4D** fridges
  stood 0.10-0.13 m inside their kitchen-hall openings. They move to the
  kitchen's south wall, and the fridge context inspector now refuses a closed
  case in any door or opening passage. The completion route's 2C and 4C legs
  go round the open bath and kitchen leaves. The route runs whole for the
  first time, staff leg included: 154 waypoints, 0 failures.
  ConnectedWorld holds native seating and tables to every part of their
  variant. The old extracted-surface count failed slice 4's one-partition
  pedestal tables.
- **Slice 85 (7aa90d51).** It adds maintenance evidence on the F03-F06 service
  spine: service-colour bands with blank tags, a drain cock, a crate and a
  coiled hose, chalk, a drip ring and a scuff (**F03_SERVICE_HALL-001** to
  **F06_SERVICE_HALL-001**). It sits outside the route. The vertical route
  walks the F04-F06 halls for the first time.
- **Light switches (c3737f20), at the owner's direction.** The owner's words:
  every light switch flush against the wall, and the older dark switches the
  new toggles replace removed.
  - No V1 switch renders in V2. The dark plate beside each toggle was
    **BW-013**'s blank brass signal outlet. It was a 70 x 115 x 6 mm plate
    that read as an older switch. The loader no longer mounts it, and
    **BW-013** is rejected with that reason.
  - The toggle model's rear face is 8 mm in front of its anchor, so most
    plates stood off their walls. Three passes seat all 144 on the finished
    surface: the wall, the bath tile skin, the 16 mm public wainscot backing
    or a riser. Pass 1 seats them by the visible face, pass 2 over the whole
    footprint, and pass 3 keeps them clear of casings, stiles, skin seams and
    window joinery.
  - The F02-F04 west-hall switches move to the hall's north wall. The 1A
    and 3D bath switches leave the basin wall for the latch side of the
    door.
  - 1D's house-bell flex used to end at the outlet. It now runs down the
    wall to a terminal above the skirting.
- **Evidence (c09a37fd).** `implementation/slice84`, `slice85` and `switches`,
  the slice 85 statuses, the README's squash note, and
  `sources/switch_replica` with its per-plate clearance table
  (`implementation/switches/replica_clearance.txt`).

## 3. Runs

Each receipt is under `implementation/<tag>/receipts/`; the log it names is
under `C:/ov/envimpl_out/<tag>/`. Counts and pass lines are in section 1.

| Tag | Tree | Runs | What it shows |
|---|---|---|---|
| followups4 | 88c5a68f (game/art of 1c5aa391) | 23 | The suites the follow-ups repair, and every route the merge report said never ran on the shipped tree. 22 exit 0. |
| slice83 | 34b4c7c8 (game/art of 419cb5dc); 88c5a68f; 2ea28ee0 | 21 + 1 + 7 | The sconces and cage bulbs, frames before and after with the lamp on and off, and the merge-base runs that classify the reds. |
| slice84 | ebe9503b | 14 | The whole completion route, each unit, the staff leg; ConnectedWorld's first, too-broad check (508 failures, narrowed at 9535800b). |
| slice85 | 9535800b; ebe9503b; 32784e13 | 19 | The service spine before and after, the route boxes, the vertical route, ConnectedWorld at 0 failures. |
| switches | 9535800b; fbea083e; 32784e13; f70c3c95 | 27 | The census before the passes and after each; each pass's suites; the pass 3 suites and the bell capture at f70c3c95, which is the tip's game and art. |
| main_d38e | d38e7795 | 4 | Main itself: M11B fails one lifecycle check, and ConnectedWorld fails the 8 table checks that slice 84 fixes. |

## 4. Standing failures

The previous report's standing failures (its section 5, S1-S18 and the
seven unexplained receipts), as they stand at the tip. "2ea28ee0" is the
dossier's merge-base; its runs (receipts `base_*` in `slice83`) show a
failure predates the dossier, and so is on main.

| Failure | Now | Shown at |
|---|---|---|
| S1 ApartmentBatch | 204 failures, 7 label classes, no script errors (SE1, SE2 gone since the follow-ups). At f70c3c95: 26,885 checks, labels identical to 9535800b's. Classes: receiver texture 110, bounded fixed-furniture collision 46, wood catalogue material 18, category material 12, plant surfaces 10, coffee-table optical glass 6, plant semantic 2. | 2ea28ee0: 192, same classes. The 12 extra are the receiver-material class from the six radios **BW-011** added. |
| S2-S6 CompletionInteriors 1A, 2C, 3D, 4C, 4D | Fixed in slice 84: 154 waypoints, 0 failures, every unit and the staff leg | ebe9503b (`slice84/completion_*`) |
| S9 IntegratedTest | FAIL (1): "M08 WALK BLOCKED" at (1.59091, 3.8351, -2.50041) on the F02 stair | 34b4c7c8 and 2ea28ee0, the same position |
| S10 M08ESpatialTest | FAIL (1): BLOCKED at **PASSENGER_SHAFT_EAST** | 34b4c7c8 and 2ea28ee0, the same position. The previous report had it branch-only; it predates the dossier. |
| S11 MailRouteTest | Passes windowed: 16 waypoints, 0 failures | 88c5a68f (`followups4/mail_route`) |
| S16 CoalDeliveryTest | Passes: 36 waypoints, 0 failures | 88c5a68f |
| Unexplained 2-4: 5C_bed0 stance, rear wing C bookshelf | Fixed in the follow-ups: bedding 19 beds, 0 failures; rear wing C 32 waypoints, 0 failures | 88c5a68f, and rear wing C again at ebe9503b |
| ConnectedWorld, 8 failures (not in the previous report) | "furniture has its extracted visible surfaces" for **2A_din_t**, **3B_din_t**, **4A_din_t** and **4B_meal_table**, slice 4's one-partition pedestal tables. Fixed in slice 84: 0 failures from 9535800b on | 34b4c7c8 (8). Main d38e7795 (`main_d38e`): the same 8 |
| owner_service_finish fabrication, 54 failures | "real loaded mip chain" on 54 textures | 34b4c7c8 and 2ea28ee0: the same 54 texture names |
| M11B service openings, 1 failure | One ownership-lifecycle check: "final teardown returns to the warmed ownership baseline" at d38e7795 and ebe9503b, "second warmed cycle causes no ObjectDB, resource, or orphan amplification" at 9535800b | Main d38e7795 (`main_d38e`), so the red predates the follow-ups; the failing check varies from run to run |
| Fabrication capture stations | Slice 85's batch refuses one station, F03_riser_hose in the 0.98 m pocket; slice 82's batch refused five (2B_dress_form, 5B_aerial_wire, B1_cleat_run, B1_washer_supply, B1_rinse_taps) | Harness: the capture finds no clear camera stance. Every other check in the module passes. |

Not re-run on this branch, so as the previous report left them: S7
UpperFurniture, S8 UpperKitchen, S12 DoorHinge, S13 FloorSurface, S14
GroundCoreTransferRoute, S15 NewsReceiving, S17 VantryGateway (a V1 scene)
and S18 WakeReconstruction; nor were unexplained receipts 1 and 5-7. The
branch does not edit those suites' scripts, but it changes data the composed
world loads, so their results at the tip are unknown.

## 5. Integration continuation (2026-10-11)

Codex completed the pending report, sidecar and main baseline receipt packet.
The historical report above describes the implementation tip **c09a37fd**.
Finalization adds one archive-wide **-text** attribute for the dossier packet:
its manifests hash the archived raw bytes, which must survive a fresh Windows
checkout under RUL-010. This is an additional change outside the original
implementation boundary. No runtime code or asset is changed by finalization.
The packet preflight checks 1,866 bound files. One historical **baths/wc_probe.txt**
blob had been line-ending normalized on commit; its already archived raw bytes
are retained under the new attribute so its original manifest hash matches.

The report commit is checked in a fresh checkout against **d38e7795**, with
the committed sidecar. Focused checks in the canonical checkout will accompany
integration; their actual results are recorded separately. Earlier lane receipts
remain historical suite-run observations. Their raw runtime digest differs from
the branch checkout, so they are not presented as currently binding receipts.
The standing failures and owner decisions above remain open.
