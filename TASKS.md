# OPEN TASKS

Evidence class: **INERT**

The shared queue. Everyone working on Orison writes here.

**This is a list of open work, not a log.** Delete a task when it is done; git
history is the record. If a task is wrong, say so on the line rather than
quietly removing it.

## How to use it

- **Add to the bottom of a section.** Ids are permanent — never renumber.
- **Claim by putting your name in the line.** No name means unclaimed.
- **Section prefixes exist so two agents adding at once do not collide.**
  `K` core loop · `D` decisions · `A` arcade · `S` studio · `M` materials ·
  `H` housekeeping; subsystem sections retain their own prefixes.
- One line each. If it needs a paragraph it needs a brief in `design/`.

---

## K — Core loop / the complete shift



Use the [Bible](design/ORISON_BIBLE.md) for canon and [HANDOFF.md](HANDOFF.md)
for current custody and qualification. The [November 21 direction proposal](design/ORISON_DIRECTION_PROPOSAL_2026-11-21.md)
puts one playable year, the authored investigation, human playthrough and
frame pacing in the rooms it uses first. Route and save suites qualify game
systems. The Bible sets the player's progression. Claude owns the current
cityscape and performance work. Preserve the prologue, audio, golden shift,
weather and existing game state. Keep partial city packets from overwriting
complete installed blocks. The prologue-teaser milestone below remains a
separate owner request. No release deadline is set.

- **K-V2-CITY-REVAMP — Claude owns current cityscape work. Codex's integration history follows.** PR151 is merged to main at **4f16053e8**. Its scoped evidence includes loaded edge71/0, composed physical38947/0 and city38193/0, reviewed59root+5entryframes, source-bound surfacePASS0 and exact candidate verification; this is not whole-V2, human artistic acceptance or a whole-city performance budget. Preserve all124 lot reservations,39 retained profiles and85 integrated replacements. One six-leg preparation pair observed p99 338.254→60.696ms,max434.340→67.996ms,>100ms6→0 with658.903ms preparation; broader cold/reload/Continue performance remains open. PR152 is merged at **aca238412**. Its qualified scope is in **K-V2-QUALIFICATION-DEBT**; do not repeat unchanged native/import/family work or read historical queue handles as live. Remaining city work: continuous450m exploration and relevant saves; finish bridge/station/industrial/waterfront composition,period streets/gaslights and rooftop life; inspect dark facades,sparse grade,flat clouds and dumbwaiter framing with the relevant owners; measure loading/cancellation/restoration and actual whole-city frame-time costs,LOD transitions and any still-generic stock before claiming completion. The owner-approved studio-maquette image is visual direction,not an exact map or runtime proof. Detailed receipts,failures,P2/pane/roof-alias/import history and narrower scoped limits remain in [city ledger](design/V2_CITY_CONTEXT_REPORT_2026-10-19.md). Superseded queue history is preserved at **9d8faac75:TASKS.md** with its original evidence references; unresolved clauses are retained here. Coordinate any necessary native batches with Claude.
- **K-V2-CITY-OVERLAYS - Technical integration merged in PR 349 at a1e43d9aa:** The production world mounts the near street furniture and building fronts from PRs 343 and 344. Three shop boards were refitted around stonework and fire escapes. Street lettering clears the signposts. The combined run passed 213 checks for installed support and clearance, two player-route envelopes, and campaign-clock lighting, with five inspected views. The current physical packet passed 818 checks and 23 paired views. Fixed-camera median overhead was 1.01 ms at the corner and within 0.07 ms at the shopfront. Full gameplay, owner copy, and artistic review remain open. [Combined evidence](C:/ov/reports/city_overlay_integration_20261118/combined_04/city_overlay_integration.json).
- **City polish, November 6.** Window candidate **b3850d755** adds room layouts and projects prologue time across both glazing banks. The installed review verified 25 neighbours and 124 horizon partitions, intact UVs and LODs, detached clock projection/restoration and no save-clock change. [City review](C:/ov/reports/develop_intake_20261104/city_window_variety_native_01/city/night_review.json). Beyond the Queensboro Bridge, [six posed stills](C:/ov/reports/develop_intake_20261104/city_far_skyline_native_02/bridge_skyline_comparison.png) support a low world-anchored skyline with a clear bridge silhouette. The grounded candidate adds one mapped masonry mesh on the existing Manhattan bank. Eight paired native frames passed at **9c18301ea** and were technically reviewed. The low far bank reads from the roof and west street, and bridge crowns stay clear. The current eastern 280–450 m ground suffix passed 23 checks at **fa0e83f3c**. It preserves the actual retaining wall, uses normal input and records 3,984 supported poses. The continuous door-to-wall run reached all 23 waypoints and retained three 0.304 m step excursions and 54 unsupported approach ticks. Full threshold qualification remains open. The fixed north canal bulkhead passed loaded collision, nearby controller walk and paired technical review. Passive rail sidings loaded, but they are too faint from the established overlook. The final mounted PR170 skyline, switcher and bulkhead passed 16 native captures. The switcher reads from the apron and stays faint at the high overlook. The original four PR170 suites passed at **0eb365963**, with 82 technically reviewed frames. PR170 merged at **3fb73fc63**. PR172 merged at **d2ed06401**, adding the distant districts and aligning the Manhattan grid. It passed the 30-view native review, 122 prologue checks and the four original V2 suites. The eastern ground walk reached 449.703 m and retreated under ordinary input. The full threshold approach, human play and artistic acceptance remain open.
- **K-V2-CITY-SKY-CYCLE-CLIP — DELIVERED candidate; Lily review pending.** November3request fulfilled after composed physical survey38884/0 and strict surface publicationPASS0. [10second3440x1440MP4](C:/ov/reports/city_sky_cycle_20261103/Orison_24_Hours_in_10_Seconds.mp4):300frames/30fps,exact10.00s,February23-24 1929 08:00-08:00,60degree Orison rooftop pan with installed sky,stars,reliefMoon and occupied-window optics. Existing detached RenderClock/presentation projects24h without changing campaign clock;capturePASS,all300encodedframes decode.20encodedframes spanning the fullclip plus4sourceframes inspected. Dark facades/flat cloud relief remain artistic limits;no performance or human acceptance. Video/intermediates stay outsideGit. Own queued stutter followup23620 was cancelled before starting to prioritize this deliverable;resume after handoff. Capture/encoding evidence: C:/ov/reports/city_sky_cycle_20261103/VIDEO_RESULT.json. Tracker-page embed remains to update; no deadline.


- **K-V2-CITY-FOOTPRINT-CLIP — Canonical Codex with City Architect: qualify real footprint-based party-wall clipping.** Original Sohmer3e849def was rejected for parcel-proxy blanking; correctedc4db44b46 now has scoped occupied-wing logic and six dependent P0R2/P2 part rebuilds,13source tests with courtyard/setback negatives and real-solid positives, but loaded/composed proof is pending. A separate reproducible current-main source witness also reports overlap between HORIZON_NEAR_2_1_P0R0's outward probe and narrow2141 P0R1's reservation even though the probe lies outside the latter's entire actual outline. Audit retained setback/nonrectangular consumers, then correct and regenerate only demonstrated affected output with actual pane/occlusion/render checks. Preserve all124 reservations, unrelated profiles, authorities and original failures; do not silently widen the frozen Sohmer patch or claim that this source predicate proves missing runtime windows or artistic intent. Source/hash witness: C:/ov/reports/city_composition_20261102/retained_parcel_proxy_witness.json. November3 prospective packet-source review also finds45 bbox-predicate overlaps wholly outside concave packet outlines; exact source hashes/segments and zero boundary intersections are in C:/ov/reports/native_intake_20261102/PACKET_OUTLINE_PREDICATE_REVIEW.json. This is not actual pane-loss or runtime evidence. Subsequent PACKET_OCCLUSION_REACHABILITY.json matches the current proposal: independent10455other-parcel+25.1mm comparisons find0overlaps and0.28m minimum private inset, so those synthetic cuts are not demonstrated reachable by other current recipe facades. Do not rebuild85 from this predicate alone or close the older retained/default/future-layout gap; bbox policy remains approximate, not footprint-exact. No deadline.

- **K0-ENGINE — PRIORITY / CONTINUOUS: WRITE THE ENGINE WE ARE DISCOVERING.**
  Treat this project as an evidence-producing engine-development programme,
  not only a game. Beginning now, maintain a durable, source-linked knowledge
  ledger covering: subsystem ownership and contracts; data-driven construction
  patterns; deterministic simulation and save boundaries; rendering,
  performance and proof instrumentation; content/compiler pipelines; test and
  render-sheet methods; failed approaches and why they failed; Godot-specific
  constraints; what is Orison-specific versus reusable; and the seams that
  would need stable APIs, documentation, packaging, licensing and support to
  become a standalone tool. Record decisions when learned, with commit/test/
  measurement evidence and migration cautions. Before the next project, turn
  the ledger into an engine requirements document and extraction plan; do not
  prematurely generalize production code or let productization destabilize the
  current game. Living record: `design/ENGINE_KNOWLEDGE_LEDGER.md`.

- **K0-LANGUAGE — INVESTIGATIVE CLARITY: HOUSE ENGLISH IS INVESTIGATIVE
  EQUIPMENT.** Build the source-grounded alternate-history occupational contact
  language specified in `design/HOUSE_ENGLISH_LANGUAGE_STRATEGY.md`. Prototype
  only the opening shift first: semantic source records, 10–25 teachable terms,
  evolving comprehension, plain/parallel accessibility surfaces, resident
  idiolects and cultural review. Never turn immigrant identity into phonetic
  caricature, obscure safety/navigation facts, or let presentation own story
  state. Scale only after blind players infer and act on a novel instruction.

- **K0-PHONE — PHYSICAL COMMUNICATION: THE HOUSE HAS LINES, NOT GENERIC
  PHONES.** Execute `design/HOUSE_TELEPHONE_ECOLOGY_BRIEF.md`: a physical F01
  apartment-house board, period-correct 4B suite set and message-bureau custody,
  trustworthy 3D subscriber set, completed public booth, and only the
  professionally justified private subscribers. Route existing call/report
  owners through transient lamps, cords, bells, jacks and slips without
  duplicating jobs, cases, dialogue or persistence. Teach House English's
  line/order/carrying/A–B vocabulary through ordinary operation before the
  first impossible connection. Ship in PHONE-A…F slices with production-live,
  accessibility, performance and quantitative render gates.

- **K0-AUDIO — LAUNCH BLOCKER / PRIMARY GAMEPLAY FEEDBACK: MAKE THE HOUSE
  ANSWER CLEARLY.** Execute `design/SOUND_AS_GAMEPLAY_AUDIT.md`. Establish the
  golden-shift listening baseline before bulk tuning; then ship an authored bus
  tree, composable mix-state owner, semantic cue catalog, pooled priority and
  concurrency policy, Vantry audibility vertical slice, interaction/state
  vocabulary, cached room/portal propagation, weather/radio arbitration and
  caption/accessibility parity. Preserve source ownership: props decide what
  happened, audio policy decides how competing truths remain intelligible.
  Sound must convey source, direction, acceptance/refusal and state without
  becoming louder, busier or an omniscient objective system. AU-0 through AU-3
  gate the Early Access golden shift; AU-4 through AU-6 complete M3/M6 polish.

- **K2 — FRESH-SAVE GOLDEN SHIFT.** Play the eleven M2 beats from curb to 4B
  wake without console, debug panel, noclip or source knowledge. Record the
  exact first missing or unclear player-facing transition; do not infer it from
  a green unit test.
- **K3 — ELEVEN-BOUNDARY SAVE MATRIX.** Save and reload after every golden-shift
  beat. Prove the immediate practical intention, job/case owner and physical
  world state reconstruct correctly at each boundary. Run K2 first. The
  [lane-backed M10 launcher](tools/run_orison_v2_m10.ps1) preserves each attempt
  and gives K3 a separate profile per boundary. The eleven human results remain
  due.
- **K4 — ROUTE POLISH INTAKE.** After K2 produces a stable route, promote only
  route-visible `blocker`/`ugly` rows from `design/walkthrough_punchlist.md`
  into bounded M3–M6 tasks. Wishes remain in the evidence ledger unless a
  playtest promotes them.

Status and sequencing rationale:
`design/MILESTONE_RECONCILIATION_2026-08-26.md`. M1's shared spine is already
implemented and documented in `game/docs/core_loop.md`; K is now an integrated
product proof, not another spine rewrite.
---

- **K-POST-V2-YEAR — Finish The Year You Died within the current earned-lead rules.** All eleven dated visits have installed movement and pointer receipts with earlier prerequisites staged. PR447 landed the companion introduction. PR448 qualified the ending's save and Title Continue. PR460 qualified the archive and plate pickups and replay. PR461 keeps the 6C ledger available during Mae's vanish act. PR462 connects the kept papers to the August receipt, with 47 installed pickup and rewind checks and 223 temporal checks covering the first commit, older saves, and Peter's receipt topic and Ewald's explicit receipt question. The [access sweep](C:/ov/reports/temporal_access_sweep_20261121/REPORT.md) preserves the individual results, including the basement's real Title Continue, the 2C trade log and sleeve, and Omar's boiler sheet. The draft has 26 speakers and 189 threads. PR449's S15 route passed 22 installed checks: Nadia walked from 5A to Photo Supplies, the real card opened her topic on the first click, and one release printed. [S15 route evidence](C:/ov/reports/s15_installed_access_20261121/REPORT.md). PR463 fixes clue grants from silence for Cal, Lena, and Ewald, verified on the actual dialogue panel. PR450 delivers the first five Tenant copies in order through the companion's saved queue. Title Continue and a real busy-printer reload passed, with first-print and queue-capacity controls. [Delivery evidence](C:/ov/reports/received_copy_delivery_20261122/REPORT.md). PR451 qualifies eight release notices with persistent paper custody, including both installed Photo Supplies cards and the compatible Nadia receipt. PR486 qualifies S14 through Nadia’s arrival, Mae’s single release copy, sleep and wake in 4B, and the final case filing. The proposed acknowledgment remains gated. [Release evidence](C:/ov/reports/release_custody_20261122/REPORT.md). PR452's Friday clock and paper custody passed 252 temporal and 16 native checks. The installed lobby encounter passed 22 checks through the normal street door, actual refusal, blackout, replay and ordinary Harukiya presence. [Receiving evidence](C:/ov/reports/friday_lobby_intake_20261122/REPORT.md). The Photo Supplies window and July 11 roof encounter passed 29 installed checks through the actual authored dialogue, roof prerequisite and single release. [Encounter evidence](C:/ov/reports/adela_dated_encounters_20261122/REPORT.md). PR467 opens the November window visit from its physical log, with 33 installed checks through the fare, authored exchange and HOME. [Window log evidence](C:/ov/reports/photo_window_log_20261122/REPORT.md). PR468 opens July 11 from the 4B desk key book. The distinct historical entry opens the date and the actual signature produces one roof release across the 56-check installed route. [July roof evidence](C:/ov/reports/july_roof_key_book_20261122/REPORT.md). PR469 verifies the fresh title through the unskipped prologue, printed S01 and first received copy, and the typed LEADS response in one installed campaign. [Fresh-title contract](C:/ov/reports/title_to_s01_20261122/REPORT.md). PR471 passes actual Continue from that S01 save through the 6C pickup, all six case-wall papers, and saved pin, date and place in 30 installed checks. [Case-wall evidence](C:/ov/reports/title_first_clue_20261122/REPORT.md). PR472 delivers the physical O1 print in box 4B and records the July date from the actual mail. The nearby installed route passes 16 checks through pickup, the valise and save. The fresh-title save chain passed all eleven visits through normal Continue and installed input. Its final native save reached the roof and both printed endings. [Case lineage](C:/ov/reports/title_campaign_chain_20261122/through_case.json) · [Ending contracts](C:/ov/reports/title_campaign_chain_20261122/through_endings.json). A fresh world now reaches the fifth physical filing with both early deductions and both residents in 5B. The same-session run passed 173 checks and 274 waypoints with fixture-controlled allowance days and visit clocks. [Fresh campaign evidence](C:/ov/reports/title_campaign_chain_20261122/fresh_through_fifth_main_03/verified_terminal.json). One Continue from that exact fifth-filing save reached the eighth filing and glove deduction in the same resumed world. The button, archive negative and drain visits passed 85 checks and 184 waypoints. The terminal native save matched after exit. [Resumed route evidence](C:/ov/reports/title_campaign_chain_20261122/after_fifth_to_eighth_main_03/verified_terminal.json). Two exact Continue saves now connect fresh Begin to all eleven filings and the finished ending across 362 checks and 674 walking waypoints. Replaying the exact unanswered choice passed eight checks for the left ending. Both ending saves persisted after exit. [Fresh save lineage](C:/ov/reports/title_campaign_chain_20261122/after_eighth_to_finished_main_05/verified_fresh_save_lineage.json). The first physical deduction now releases Mina's ready dream once. A nearby installed test passed 39 checks with the completed conversation staged. [First-dream evidence](C:/ov/reports/first_dream_20261122/verified_installed_threshold.json). The longer run exposed a 6B grip interruption from the companion feed wheel. The focused fix and exact-save 6B replay are recorded in the [grip report](C:/ov/reports/notebook_companion_grip_20261122/REPORT.md). PR #579 restores the ordinary Saturday radio exchange in 5B. The installed visit reached both spots and played all seven lines through normal interaction. See [the handoff](HANDOFF.md) for the checked scope. PR #580 restores Malcolm and Sacha's ordinary Sunday roof exchange. Both residents took the upper stairs, crossed the live public door and reached separate marks. Normal player interaction delivered all five original lines. See [the handoff](HANDOFF.md) for the checked scope. PR #581 restores Teresa and Cam's ordinary Monday hall exchange. The residents reached separate hall marks from the flat-side hall and the street, delivered all five lines through normal player interaction, and began their scheduled departures. See [the handoff](HANDOFF.md) for the checked scope. Remaining work includes an uninterrupted fresh-title route through the ending, ordinary fare pacing, ordinary encounters and witnessed performances, Ewald's placement, unresolved carrier flags, property-law review, the positive case, and Lily's playtest. Preserve the blackout, Mina's held thread, clue and knowledge custody, and proposed-only Option A. The mandatory trans-reader gate was retired. [Active tree](design/TEMPORAL_LOOP_TREE_2026-11-10.md) · [NPC delivery plan](design/NPC_LOOP_PERFORMANCE_PLAN_2026-11-12.md).

- **K-V2-PRECIPITATION — Codex, queued after current prologue integration: finish moving-field/first-use attribution and precipitation presentation.** Rain/snow visibility, deterministic lightning, wetness, fallout and lens moisture are already merged in PR66 with source-bound surface, weather-route and isolated two-world save evidence; do not repeat that construction or call its original candidate gates pending. November 12 local real-player/TAA rain/snow probe passes 31/0 with cover/resumption; [scope and limits](design/SKY_OVERHAUL_2026-11-12.md). PR384 qualifies outdoor rain and snow seen from the dry Orison vestibule. The local fixture passed 39 checks and the installed entrance passed 12 checks across seven ordinary movement waypoints. The agenda replay triggered by the calendar change now takes 142–157 ms in the matched six-hour bench, down from 233–249 ms with identical decisions for all 19 residents. A separate installed rain transition still reached 535 ms. The shorter contact field reduces scene update during a matched dry roof recenter from 9.74 to 6.84 ms. The installed entrance and paired rain, hail and frog impact controls retain their behavior at the tested offsets. Three apartment-window poses retained dry rooms. Outdoor rain and snow are faint through the 4C north pane, and the 4B views are obstructed by a sheer or nearby brickwork. First rain from a settled rooftop peaked at 38.26 ms. At the actual roof door in rain, the off-storey living-field fix took the measured lip peak from 68.15 to 28.05 ms. The matched rooftop creature birth and departure frames fell from 41.76/38.66 to 26.45/25.18 ms. A different candidate frame reached 46.65 ms. Further sightlines, first-view and residual stalls, and artistic acceptance remain open. [Trace and replay evidence](C:/ov/reports/precipitation_activation_20261118/REPORT.md). [Shelter captures and receipts](C:/ov/reports/precipitation_shelter_20261118/REPORT.md). Preserve indoor cover, readable companion/UI and calendar, publication and save owners. [Results and original failures](design/V2_SKY_WEATHER_INTEGRATION_2026-10-24.md).

- **K-V2-ANNUAL-SKY-ART — Audit the full November 1928–November 1929 weather year across hours, seasons, regimes, genera, rare phenomena and seeds.** Reuse the existing 2,190 six-times-daily renders, measure coverage/repetition separately from artistic judgment, add targeted sunrise/twilight and weak-combination renders, and implement evidence-supported cloud/lighting fixes. Use the new [weather skill](.agents/skills/godot-weather-sky/SKILL.md). November 12 [sky overhaul](design/SKY_OVERHAUL_2026-11-12.md) implements rounded low/mid relief, softer Ci/Cc and bounded stratified sampling. The scoped layer/motion/season/event matrix and 48 rooftop checks pass; calendar 439/0 and moving precipitation 31/0 are retained. November 12 follow-up [sampling and film](design/SKY_SAMPLING_FILM_2026-11-12.md) removes the visible hashed grain and reduces connected distant streaks; 12 layer views, nine optical/temporal checks, three rare controls and a decoded 24-second actual-city day/night film pass. Faint grazing bands, busy Cc, special-case art and Lily's annual artistic review remain open. The earlier shared wetness/blood retirement fix passes41 rendered checks plus calendar/service diagnostics; lifecycle proof remains separate from sky-art acceptance. Source inventory at `C:/ov/reports/sky_weather_20261112/inventory_01/` identifies cloud-genus threshold continuity and remaining solar/event TIME paths for bounded reproduction, not confirmed visible bugs. Preserve the authored weather schedule. No claim that fifty classifications constitute fifty accepted formations.

- **K-V2-SKYWATCH — Codex, queued: finish installed rooftop club/telescope/BBQ gameplay and the remaining astronomical detail.** PR67 already merges relief Moon/phases, five-planet and 9,096-star analytical foundations; PR68 adds cloud-flow/ice/twilight/mirage and fictional airship presentation. Do not rebuild those foundations or describe all airships/city optics as absent. Next survey current roof/city access, mount reviewed stock and exercise actual telescope controls; Leonids, precision/magnified optics, lunar softness at 0.1-degree FOV and final artistic acceptance remain open. Preserve roof plant, weather-inspector access and clock ownership. [Requirements and limits](design/V2_SKYWATCH_ASTRONOMY_2026-10-27.md); [story connection](design/THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md#v2-prerequisite-skywatcher-club).

- **K-V2-FILM-CADENCE — After weather integration and Smooth-mode performance diagnosis, preview optional Smooth / Cinematic 24 / Early Film 18 presentation.** Step eligible visual poses only; preserve responsive camera, direct manipulation, physical companion readability, campaign clock rate, simulation and animation-event authorities. No low-rate whole-world viewport or default engine cap. Optional weave/flicker/period grading must protect text and support motion/flicker-free viewing. [Analyzed owner brief and acceptance boundaries](design/V2_SKYWATCH_ASTRONOMY_2026-10-27.md#queued-presentation-experiment-early-film-cadence). Actual native-refresh performance remains a target, not an established result.

- **K-V2-FRONT-FACADE — Canonical Codex: finish entrance/facade integration and qualification.** Selective portal candidate **f4d73ddd** preserves unrelated facade arrays and original door/sign/light/save owners. Corrected occupied review passes673 checks with actual grab/mouse/release and six inspected captures; original fixture failures are retained. Next reconcile facade/window findings against installed interiors, complete source-bound surface and current-main candidate/regression renewal, and obtain artistic review. Native/diagnostic passes do not close the full facade. [References, evidence and limits](design/V2_FRONT_ENTRANCE_REMODEL_2026-10-27.md). The installed boot scraper and stand passed technical qualification. Review their dark rain-light presentation with the facade.


- **K-V2-FIRST-VIEW-HITCH — Codex.** The idle cistern passed 218 installed checks on 20 authored toilets and reduced the third-floor stationary worst median from 89.627 to 87.279 ms. [Cistern comparison and scope](C:/ov/reports/idle_closet_intake_20261121/REPORT.md). The 32 m shadow range reduced steady Laurel cost. The bodega custody change reduced measured scene-tree physics from 5.24 to 4.45 ms/tick on the matched night walk. Nearby bodega and composed checkout checks passed, with 818 physical checks and 23 reviewed views. The worst interval still varies. PR375 moved first arcade mount to verified baked geometry. Deduplicating identical radiator inputs reduced household binding from 3.50 s to 0.86 s in the matched trace. The waking atlas retains authored Tardi and Euplotes at 63.2 MB, compared with 169.5 MB for all Dream species. Restoring Euplotes reduced the matched lunch birth frame from 182 to 43 ms, with no new pipelines on the candidate frame. [Lunch replay and atlas parity](C:/ov/reports/precipitation_activation_20261118/REPORT.md). The city window chart builder fell from 1.344 s to 0.866 s across 149 matched installed meshes with identical render data. Skipping unused lower-detail mesh decode saved 118-264 ms for the 542 nonreducing horizon parts in paired trials. PR464 reuses the near surface for collision and LOD. The matched warm horizon mount fell from 7.304 to 6.638 s across three alternating pairs, with all 1,110 part fingerprints matching and the installed 669/441 reach split intact. Physical qualification passed 818 checks. [Startup comparison](C:/ov/reports/horizon_donor_mount_20261121/REPORT.md). The follow-up city survey passed 38,186 checks after the inspection bodies were allowed to settle and the rays distinguished the exploration boundary, asphalt cap and apron backing. Original 211 failures retained. [City ray receipts](C:/ov/reports/city_ray_custody_20261122/REPORT.md). The resident route step check fell from 21.05 to 0.64 microseconds across 17 authored graphs, with all 1,713,168 decisions matching and 106 installed visit checks passing. This measures the check itself. [Benchmark](C:/ov/reports/resident_route_step_cost_20261119/benchmark_summary.json). Bedding assembly for 20 beds fell from 451 to 164 ms in eight paired trials, with identical collision faces. The installed check passed all 80 bed contacts and the dream-room contract passed 445 checks. [Bedding measurements and receipts](C:/ov/reports/title_campaign_chain_20261122/bedding_stock_startup_01/REPORT.md). First-use and auxiliary-viewport spikes, broader title/Continue startup, and arcade streaming frame pacing remain open. [Qualification and traces](C:/ov/reports/bodega_custody_read_20261118).
- **K-V2-COMMONS-REFIT — Codex.** F01–F06 commons, aligned front windows, refitted drainpipes and the separate brick-mounted entrance lantern are implemented. All 12 lift and stair approaches, 36 first-floor authority checks, 679 installed façade checks and 818 physical surface checks passed. Day and night captures were technically reviewed. Lily's play and artistic review remain open. [Design and run evidence](C:/ov/reports/orison_common_floorplan_20261119/IMPLEMENTATION.md).

- **K-V2-ROLLING-HOOP — Codex.** Hardware & Paint sells the 25¢ hoop and stick. Take it out of the valise and hold Run while moving forward to guide it at 6.21 m/s on clear ground. All 19 installed gameplay checks and 818 physical surface checks passed. Lily's play review remains open. [Controls and run evidence](C:/ov/reports/rolling_hoop_20261119/REPORT.md).

- **K-V2-TEASER-DISTRIBUTION — Canonical Codex (tooling/QA) and owner (creator accounts/offer): prepare release infrastructure alongside the polished prologue.** Requested3/10/25USD Patreon tiers, restricted itch claim access, protected Butler uploads, Discord roles and visible title/pause build identity. Verify existing account state, annual-plan eligibility, active-only entitlement/revocation and actual role timing; official docs do not establish these from OAuth alone. Current repo has Windows and retained Android presets; first experimental upload is Windows, macOS/Linux remain unqualified deliverables. No live setup/upload/account/tax/patron QA is claimed. Keep broad retired marketing/fundraising archived; prologue appearance/audio/save/performance acceptance gates release. [Plan, corrected provider details, dependencies and six acceptance checks](design/EARLY_ACCESS_GO_TO_MARKET_PROJECT.md). Trigger: prologue ready; no calendar deadline.

- **K-V2-PROLOGUE — Canonical Codex: polish the merged normal-entry prologue for actual players.** PR86 merged039fb64a after clean115-gate comparison: zero regressions,17 protected paths unchanged,zero accepted exceptions. Combined physical651/0 and occupied temporal77/0 pass with empty stderr; actual readout clock/target/cancellation,natural32-second sky,17-second cutaway,pause/skip/privacy and validated reload are exercised. Earlier title16+287,domain121,newspaper50,companion50 and repaired fire-only2,195 evidence retain scope. Original failures remain; the excessive long city route was interrupted,not accepted. Stationary callback controls now separate ordinary/physics costs;261-fixture isolation shows no measured benefit,so preserve lighting personalities. Concurrent native CPU rendering limits timing confidence. Original LPC prologue babble is merged; the continuous actual-title programme now passes16 outer/122 inner checks with zero reload/document replacement or paused frame,all five lines and three natural voice gestures. Listening/mix,learned English,full save-boundary coverage and artistic review remain open. Owner priority now: finish these remaining prologue/input/save/readability/audio gaps; then isolate remaining callback families under coordinated host load and obtain fresh-player/artistic review. No production speedup or release acceptance. Preserve original Tardi appearance,exact dialogue/timing and all game/save/input authorities. [Evidence and limits](design/V2_PROLOGUE_2026-10-28.md#clean-candidate-comparison-and-main-integration). No deadline. October31 (Claude, developer this week): three player-order stalls repaired; validated save/load matrix through the cabinet, 94 checks; the intermittent fresh-world crossing and fresh-player review remain. PR480 covers the exact failed visitor Continue, the look-away reload and native crossing. On current main a fresh fixture stopped at the first sighting, earlier than the preserved post-rediscovery stall. Two full-phase trace controls reached the crossing at 800x600 and a 3440x1421 drawable view with zero return-dwell resets. The smaller run also passed 31 S01 checks. [Mirror trace comparison](C:/ov/reports/title_campaign_chain_20261122/fresh_mirror_dwell_main_04/REPORT.md). PR 378 repairs the dry shower stream's invalid basis and verifies the current valve matrix and two title Continue phases ([ledger](design/V2_PROLOGUE_2026-10-28.md#player-order-stalls-and-tutorial-reload-matrix--october31)).
- **K-V2-STOREFRONT-REFIT — Canonical Codex, proposed after current repairs:** reconcile the October28 cards against current six frontage owners, prove a compact shared kit on Otis & Son, then adapt lunch/hardware/news, existing bodega and Harukiya under its original frontage-only scope; Lily's later **V-SHOP-CIRCULATION** commission supersedes its footprint/interior restriction. Preserve doors, counters, hours, purchases, streaming and saves. Current source comparison is15/19 unchanged; historical/estimated dimensions remain labelled. Resolve shared entrance/ground envelopes before construction; November 1 owner choices are linen first, dark-green grocery and no optional News hatch. Queens address research reviewed in plan §6. Exact 1928 lot/number remains unresolved. Compare the existing fictional layout with candidates before site selection; proposed nonnumeric locality wording awaits lettering review under editorial D7. Use changed-part benches and nearby real-input checks, with one coherent integration renewal. [Proposed scope, sequence and decisions](design/V2_STOREFRONT_REFIT_PLAN_2026-10-29.md). Research intake is not rebuild authorization or acceptance; no deadline.

- **K-V2-BATH-WINDOW — Technically verified.** The 4B bath has an opaque curtain recess against 4C. The original control and saved blind record, wet-stack vent and real alcove window pass focused checks. The prologue tutorial and renewed physical surfaces pass. Lily's play and art review remain open. [Evidence and older save limit](design/V2_PROLOGUE_2026-10-28.md#november-19--4b-bath-curtain-recess).
- **K-V2-TIME-REGISTER — Remaining presentation acceptance (Lily/current integrator).** Revision7 integration is merged in [PR #118](https://github.com/NateHiggins/Lily-s-Music-Box/pull/118); evidence and original failures are in the [prologue ledger](design/V2_PROLOGUE_2026-10-28.md#compact-companion-revision7-runtime-integration--october31). Next review broader FOV/accessibility/readability and wrist manufacture/contact limits, then record a polished native-resolution teaser. Full ordinary prologue/golden-shift playtest and artistic acceptance remain open; diagnostic staging is not their completion. Existing32s sky/17s stinger and gameplay/save owners remain authoritative. No deadline; no new unrelated development before handoff.

- **K-V2-WINDOW-DEPTH — Background-window shader installed; rooftop night captures inspected.** All 149 non-Orison city window partitions use six shared context materials, with restrained lamp/colour/layout variation, deterministic optical rooms and the campaign clock. The expanded native-fullscreen review completed without reported failures/stderr and confirmed the Orison is excluded; original positions, UV0, indices and LOD bytes remain exact. Next measure matched occupied-world frame cost and review street/telescope views and LOD transitions; broad artistic and surface/weather qualification remain open. [Implementation, retained failures and captures](design/V2_BACKGROUND_WINDOW_OPTICS_2026-10-31.md).



- **K-V2-PLAYER-FACES — Codex: generate and integrate original player expressions, starting with the V2 intro sequence.** Research meme-face history for expressive economy and reaction timing; retain the supplied androgynous drawn character, camera-linked gaze and readable face lighting. Next survey the native facial UV region, author a consistent expression sheet and bounded atlas, then connect witnessed prologue beats and inspect actual mirror playback, pause/reload and rendering cost. [Initial sequence, research and verification scope](design/V2_PROLOGUE_2026-10-28.md#player-expression-sequence--october29). Queued; no generated faces, runtime verification or artistic acceptance yet. No deadline.


- **K-V2-ADELA-PREVIEW-FOLLOW — Canonical Codex; remaining boundaries and appearance only.** [PR151](https://github.com/NateHiggins/Lily-s-Music-Box/pull/151) is merged at4f16053e8 (verified GitHub merged state); PR152 subsequently qualifies original authority/save/apartment/surface debt. Preserve existing native156,822triangle/28bone/PBR producer proof, isolated15/0 and installed10-waypoint diagnostics with their debug-fixture limits. Controlled cost, full prologue/CampaignShell Continue/reload boundaries and Lily's appearance review remain open; no second narrative resident. [Evidence and limits](design/V2_ADELA_TEMPORARY_FOLLOW_2026-11-03.md).

- **K-V2-HOSE-CLOSURE — Canonical Codex.** Installed F02 repair, charge, carry and disk reconstruction pass 65/0. Visible first-solid impact wetting verified at installed landing and independent moving wall. Local payout reaches 15.09 m. **purchased_gasket_native_04/** passes 42 paid dressing/restore checks. **purchased_gasket_valise_04/** passes 51 native route checks from the 10¢ sale through valise transport, same-body return, collision-checked seating from 8 mm off centre and paired disk reconstruction with exact cash and spent custody. Earlier failures are preserved under **purchased_gasket_native_01–12/** and **purchased_gasket_valise_01–03/**. **carried_case_existing_goods_01/** passes 34 checks. **packed_washer_producer_02/** passes 22 checks including full/blocked refusal and **packed_washer_title_01/** passes 8 checks through actual Continue. **occupied_hose_b1_preflight_08/** clears the native landing with the same nozzle, then records the original closing-leaf failure. **occupied_hose_b1_door_hold_01/** passes 164 native checks for automatic, resident and manual closure refusal and normal close after clearing the hose. **occupied_hose_b1_full_04/** passes installed 15.09 m reach, exact source, nozzle aim, limit feedback and supported release with dry authority intact. PR158 merged the qualified hose changes. The native write-refusal and same-body retry pass 56 checks through disk rebuild. Human play and artistic acceptance remain due. [Installed maintenance](design/V2_HOSE_INSTALLED_MAINTENANCE_2026-10-24.md) · [Spray evidence](design/V2_HOSE_SPRAY_READABILITY_2026-10-24.md)

- **K-V2-BOOK-NOOK-CLOSURE — Canonical Codex.** The installed book route proves same-body shelf parking and normal Space exit, return/release and validated disk reconstruction. Separate corridor access passes 11 waypoints. These receipts retain their original runtime digests. Native samples from the nearby nook show readable hardback and paperback pages at 24-degree zoom. Installed same-book opening and return pass. The original 24° aperture crossed behind the spread. **book_lighting_on_hose_native_01/** passes 121 native checks with centred/off-centre lit 24°, real lamp off/restored, normal Space return and warm hinge timings. Cold opening and the actual title Continue are verified in nook_cold_and_laurel_current_01. The same loose Volume0 restores through normal look and movement, and the first hinge gesture has its print ready. PR167 merged reading fit, shoulder lighting and same-copy return. PR168 merged original-book valise custody and whole-binding reading fit at **3214e67ae**. Native custody passed 23 checks through pack, refused writes, blocked take-out, fresh disk reconstruction and same-copy retrieval. Ordinary goods and newspaper regression routes passed 34 and 92 checks. Reviewed native lamp views show the compact book at 695×520 in an 800×600 viewport and the hardback at 1724×1243 in a 3440×1440 viewport. Fine paperback footer type stays faint. PR576's installed held-book route passed 41 checks through full-case refusal, glove reading, disk reconstruction and same-copy shelving. Lily’s play and art review remain open. Preserve the current bindings, publishers, art and keepsakes. [Nook route and shelf](design/V2_NOOK_SHELF_DRESSING_2026-10-24.md) · [Book evidence](design/V2_BOOK_EDITORIAL_AND_BINDING_2026-10-22.md)

- **K-V2-INTERACTION-COVERAGE — Canonical Codex: close exact-part targeting and general held-object/manipulation coverage in existing V2.** Survey authoritative reticle available/grabbed/blocked/inspectable/travel-limit states, free-cursor inspection, pickup-to-hand and XYZ translation/rotation with release snapping for fittings. Exercise real click/motion/release, pause/focus and intermediate saves across installed families; no duplicate targeting scans or legacy-toggle acceptance. Preserve easy doors, player accommodation and slow self-close; environment sweeps only where gameplay useful. [Established repair/coverage inventory](design/V2_STARTED_WORK_CLOSURE_2026-10-23.md).
  PR #571 installed the first-person glove. PR #577 verified the shared held-item presentation and standing mirror on Toon Lily. The full-length walk evidence is in [HANDOFF.md](HANDOFF.md).

- **K-V2-LORE-FOLLOWUPS — Unclaimed, owner rulings 2026-10-31.** Heat dressing for June and July (bedding on fire escapes, open windows); a door or place for Adela at Holmes Airport; behaviour for the Radio Service line tell. See `design/ORISON_LORE_ADVERSARIAL_PASS_2026-10-31.md`.
- **K-OPS-SIZE — Awaiting owner approval, requested 2026-10-31.** Shrink the project on disk and in file count. Plan with four tiers in `design/REPO_SIZE_PLAN_2026-10-31.md`: local scratch, sparse worktrees, uncited tracked captures by class, and history rewrite (not recommended). The first worktree sweep is done; nothing else starts before the owner rules on its section 5.
- **K-V2-RADIO-SHOPS — Claude, consolidated under K-V2-SHOP-OVERHAUL below.** Preserve installed hardware purchasing and the existing finance/inventory/save authorities; the older programme remains provenance, not a second implementation assignment. [Existing programme and limits](design/V2_RADIO_SHOP_NETWORK_2026-10-22.md).

- **K-V2-SHOP-OVERHAUL — Claude, next batch unstarted: laundry station, shop slice5 and draw-call measurements.** PR100/94605245 now merges shared13-shop catalogue/goods/stock/repeat-sale/save plumbing and the carried case, following PR96/98 rulings. This supersedes the initial reading-only report. Canonical6f71734a reconciles it with current city work; final focused commerce passes and current physical renewal651/0 is published with zero defects; candidate6ba6622d passes the exact946 comparison. Historical slice1 follow-up was real counter qualification; reconcile the later merged counter work before assigning replacements. the standalone commerce test explicitly does not mount shops and seeded case input is not thirteen completed shops; preserve case keys, inventories, residents, clock and validated saves. Follow [rulings §9](design/V2_SHOP_OVERHAUL_PROPOSAL_2026-10-30.md#9-owner-rulings-2026-10-30): no sole wear in first build; check Mae's job against alibi/rent receipt/sale day before shipping; keep Lena/Cam clue owners intact. Prices are authored estimates;13 interiors and seven uncarded frontages lack historical research. Merge coherent batches with a coordinated hold for source-bound surface renewal. Actual grab/payment/reload, reader NEW0, route cost and Lily's playable review remain required; no deadline. 2026-11-01: Luncheonette first build merged (cup and plate lifted by hand, overheard dated opinions from seated residents); sitting gesture and three-stool cut merged after it; owed: visible food, menu board, draw-call measure; see the proposal's last section. Otis counter and tap merged 2026-11-01; its prescription errand still owed. November3 bridge confirmation: weather PR150 finished; no V2 files/worktrees currently held or V2 jobs queued. Remaining laundry station, shop slice5 and draw-call measures have not started; Claude will name exact paths before claiming them. Earlier Shoe/Laundry sequencing above is history, not a second assignment.
- **K-V2-NEWSPAPER-POLISH — Claude: finish and review the Sunday redraw batch.** PR97 merges back pages,65 set advertisements, weekly cartoons and chain-day pages; PR99/ae8e69b1 subsequently merges the52 Sunday redraws and newspaper panel sizing. Next review the rendered pages and publication/reading boundaries with Lily; combined source-bound surface renewal is pending with the city batch. Merged authored content is not Lily's artistic acceptance; no deadline.

- **K-V2-RESIDENT-CLOSURE — Codex and confirmed resident-route owners.** Reconcile the eighteen preferred bar places with authored attendance. PR398 verified opposing FIFO, obstruction, seating and departure for three staged residents. PR401 verified three unforced Friday arrivals and one restored seat. A separate Saturday run added Jonah, Juno and Cam. PR403 verified Lena after repairing the retained-waypoint stall. Nine of twelve sampled selectors have an observed arrival. Three sampled need-driven choices did not recur in fresh-world replays. Keep the original schedules and verify remaining natural navigation, distinct circulation, conversations, loaded materials, save reconstruction and measured crowd cost before closure. [Family scope](design/V2_RESIDENT_CAST_AND_BAR_PLACES_2026-10-24.md). [Staged contract](C:/ov/reports/harukiya_attendance_witness_20261119/native/runtime_contract.json). [Friday observation](C:/ov/reports/harukiya_full_roster_selection_20261119/friday_pavement_connection/friday_observation.json).
  PR #571 qualified the six new lobby and return walks. The men's stair correction is installed. Keep the longer descending back-leg lift in the NPC animation follow-up.

- **K-V2-BACKGROUND-STICKFIGURES — Unclaimed: populate streets and shops with anonymous stick-figure pedestrians and visitors.** Owner direction2026-10-30: reuse the player's child-drawing/stick-figure model with varied walking,idling,browsing and shop-entry/exit animations; keep named residents' distinct models so they stand out in the deliberately surreal crowd. Schedule after current prologue/voice priorities. Reuse existing navigation,shop hours,streaming and crowd/LOD ownership where available; background fill must not create named residents,story witnesses,inventory or quest facts. Budget density,animation and collision from measured occupied-world cost; preserve player passage and existing resident routes. Verify street/shop transitions,occlusion and frame-time tails with a focused route. No implementation or acceptance yet; no deadline.


- **K-V2-RANGE-REFIT — Canonical Codex; remaining cost and appearance review.** The native replacement, separate starter, actual control/collision repair and validated reload integration are merged through [PR127](https://github.com/NateHiggins/Lily-s-Music-Box/pull/127), merge3246aab9. Loaded input98/0, installed18-actor/654-record checks5,864/0, physical qualification651/0 and the final119-gate candidate comparison pass with zero regressions; exact scopes/original failures are archived in design/V2_HOUSEHOLD_STOVES_2026-10-08.md. Do not repeat completed native or input work. Measure added collision/startup cost alongside the existing stutter task and obtain Lily's appearance review; whole-shift and artistic acceptance remain open. No deadline.



- **K-V2-PAPER-PLAYER-ACTIONS — Unclaimed; requested by Lily, 2026-11-01.** Design and build later newspaper items reporting genuinely performed, plausibly public player actions; integrate plot design, newspaper generation and the runtime reader. Survey existing durable facts (RealityState, CaretakerEconomy, purchases, PawnSales.book(), errands, repairs and dialogue flags); preserve their owners. Start with the typesetter/panel/data, `design/ORISON_EDITORIAL_PASS_2026-10-22.md`, `design/ORISON_SUSPECT_CHAINS_2026-10-31.md`, `design/THE_YEAR_YOU_DIED_TREATMENT_2026-10-30.md` and DOCS.md. Record printable/never-print actions, publication delay, each paper's voice, naming/privacy, deterministic save/load, additive treatment of authored issues and dated mystery safeguards. These items never supply a clue or unlock anything; money and side content never buy a clue. Run `tools/audit_period_dates.py`; after script changes update the spatial dependency manifest and renew an expired surface packet per PIPELINE_TOOLS.md. Done requires a live reader (NEW 0), a real-state route performing an action then reading its item in a later issue, required gates with the actual board inspected, a manually merged PR (no auto-merge), and a plain account to Lily of inclusion/exclusion rules and unresolved rulings. November 1 owner rulings: draft examples before choosing eligibility; identify only the public avatar after an established introduction; at most one brief per eligible issue, in the next scheduled issue after an overnight delay. See `design/ORISON_NEWSPAPERS_2026-10-23.md` for safeguards. At intake, no feature branch, implementation files or prior work existed: two Claude side-session attempts each failed with “Claude Code didn't start within 5 minutes.” No deadline.

Paper-task execution follows AGENTS.md/DOCS.md and Bible precedence: branch from origin/main, named-path staging, short fresh worktrees with two imports, and shared-lane Godot runs with LogPath. Use PR121's hidden-desktop wrapper for windowed tests. New design documents declare `Evidence class: **INERT**` correctly within their first 30 lines and pass the design lint; reader NEW remains 0. Lily is she/her; never use an older personal name. Coordinate any plot overlap with **claude/adela-astoria-offer** (unmerged; mystery data/resident conversations) and leave the sitting/stools work in **C:/ov/shops** untouched. These are queue additions, not implementation assignments or acceptance.

- **K-V2-CONTROL-OVERHAUL — Canonical Codex; requested by Lily, November 1.** After the active range checkpoint, implement the audited function catalogue, configurable keyboard/mouse and controller bindings in Settings, and coherent pause/resume with existing audio, clock, input, protected conversation and save owners. Expose existing inventory now through the carried-case/PersonInventory authorities; qualify actual controller inventory and held-object paths, settings reload, conflict/default/cancel handling and rendered focus without click-through. Map implementation stays deferred. Scope and inspected gaps: `design/CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md`, November 1 section. PR504 qualifies title Settings focus and click handling, keyboard Apply/Cancel, synthetic controller Back, committed audio restoration and fixed Apply/Back at 800×600. PR505 qualifies Start/Back and Escape, controller focus and Apply, audio preview rollback, and a held cabinet that resumes and releases only on a fresh Interact. Contextual reading pause, remapping, controller inventory and Lily's play review remain open. No deadline.
- **K-V2-EXPLORATION-MAP — Deferred design; requested by Lily, November 1.** Preserve the external interactive 4B example (visited-room reveal and editable personal pins) as a design study. Later design a live exploration map and durable notes through existing discovery/campaign/save authorities, without leaking unvisited geometry or promoting personal hunches to story facts. Live integration is deferred by Lily's inventory/map clarification; the example is not an implemented gameplay map. No implementation owner or deadline.

- **K-V2-NATIVE-INTAKE-QUEUE — Canonical Codex with Claude; remaining intake only.** PR145/149/147/151/152 are merged. PR152 merged at **aca238412**. The85-body/23partial-block architect delivery is integrated with39retained profiles and124reservations; authoring is stopped. Original runtime14 authority/save,60room/9leg and38947-check physical surface proof is published; preserve its raw evidence and limits under **art/reviews/v2_qualification_debt_20261104/**. Do not repeat completed intake, request the obsolete fb3167942 comparison or describe those PRs/native blocks as awaiting integration. Historical checkpoints and original failures remain at **c7e2e3883:TASKS.md** under this task and in the [city ledger](design/V2_CITY_CONTEXT_REPORT_2026-10-19.md).
  The installed reading and valise checks are recorded under **K-V2-BOOK-NOOK-CLOSURE**. Retain current-weather titleBEGIN17/0 and timing18/0,21/0 as historical controls; maximum226.316ms, route-local/TitleContinue,cold startup and playable stutter remain open. Preserve fixed-inspection versus limited free-look distinctions, furnished-room/art review, concealed lower bypass optics, ten textureUID fallback warnings and controlled old-body incremental-cost gaps. Prior bathroom GPU medians.735/.6585/.677ms do not measure whole-city cost; gas-range contact refit already merged viaPR127. [Entry evidence](design/V2_PROLOGUE_2026-10-28.md).
  Reconcile remaining preferred families from **C:/ov/reports/native_intake_20261102/INTAKE_RECONCILIATION.json** and **C:/ov/asset-prototypes/interactive-v2-review-20261101/NATIVE_INTAKE_INDEX.md** against current consumers. Preserve unresolved boiler and prop traces, all original authority and saves, and the resident key's original bounds, pivot and installed 0.5 m brass scale. Each changed family needs loaded derivatives and mipmaps, affected interaction and reload checks, and cost assessment. Intake remains limited to the frozen families.
  - Merged technical intake includes radiator receiving delivery (PR152), passive vent registers (PR404), washer UVs (PR405), and switchboard UVs and tethered plug input (PR407). PR406 corrected the obsolete door-drag assertions. [Vent](C:/ov/reports/passive_vent_intake_20261119/REPORT.md), [washer](C:/ov/reports/washer_chart_intake_20261119/REPORT.md), [door fixture](C:/ov/reports/direct_input_cabinet_fixture_20261119/REPORT.md), [switchboard](C:/ov/reports/switchboard_chart_intake_20261119/REPORT.md).
  - PR408 qualifies the annunciator terminal charts with 41 loaded mesh and spring checks, 46 installed dispatch and disk reconstruction checks, and 818 composed surface checks. All 23 paired views were reviewed. Human play and artistic acceptance remain open. [Annunciator evidence](C:/ov/reports/annunciator_chart_intake_20261119/REPORT.md).
  - PR409 qualifies the closed resident key and its existing 0.5 m brass scale with 43 spawned checks, 378 key and save checks, 65 doorway checks, and 818 composed checks across 23 reviewed views. The isolated cabinet capture verifies the visual anchor and turn. [Resident-key evidence](C:/ov/reports/resident_key_native_intake_20261119/REPORT.md).
  - PR410 qualifies the radiator paper-tag tangents with 15 installed checks and 818 composed checks. PR411 relocates the notice to the room side below the handwheel and clarifies its lettering. Nearby and installed 2B tests each passed 17 checks, with 818 composed checks and 23 paired views reviewed. Owner visual review remains open. [Paper-tag tangents](C:/ov/reports/radiator_tag_tangents_20261119/REPORT.md), [notice readability](C:/ov/reports/radiator_tag_readability_20261119/REPORT.md).
  - PR412 qualifies the eight radiator air-vent charts with 170 loaded-stock checks, 11 installed cap and disk reconstruction checks, and 818 composed checks across 23 reviewed views. The current vent passes 19 installed checks through cap removal, the exposed needle, cap return, sealing and fresh-world disk reconstruction. The workshop spare now rides in the valise, with 63 walking waypoints and 12 receiver checks covering refusal, threading, visit restore and disk reload. PR498 passes 19 installed checks from an initially threaded original and a packed spare. Real unthreading parks the original where the pointer can still reach it, and the spare then seats and seals without losing either identity on reload. PR499 moves the 2B dress form off the service approach. Nine installed checks cover standing access to both wedges, independent travel, support contact and the former blocked stance. PR500 exercises the complete installed service visit with the valise, including 176 walking waypoints, both physical comparisons, the sealing turn, resident return and disk reconstruction. PR501 aligns the isolated hand bench with preset parking and the actual replacement thread. The packing, needle, stock, wedge and steam groups pass together. Human play and artistic acceptance remain open. [Bench verification](C:/ov/reports/radiator_hand_bench_20261123/REPORT.md) [Service contract](C:/ov/reports/radiator_service_visit_20261123/REPORT.md) [Wedge evidence](C:/ov/reports/radiator_wedges_20261123/REPORT.md) [Original insert parking](C:/ov/reports/radiator_original_insert_20261123/REPORT.md) [Air-vent evidence](C:/ov/reports/radiator_air_vent_intake_20261119/REPORT.md) · [Vent return](C:/ov/reports/radiator_vent_inspection_20261123/REPORT.md) · [Workshop spare](C:/ov/reports/radiator_insert_valise_20261123/REPORT.md).
  - PR413 qualifies 19 radiator mechanism charts with 421 loaded checks, including 41 packing stages, 21 installed physical-input and disk checks, and 818 composed checks across 23 reviewed views. The preset packing return passes 26 installed checks through withdrawal, parking, reseating, closing and fresh-world disk reconstruction. [Mechanism evidence](C:/ov/reports/radiator_mechanism_intake_20261119/REPORT.md) · [Packing return](C:/ov/reports/radiator_preset_packing_20261123/REPORT.md).
  - PR414 qualifies the fixed boiler casing and mounts. The 172 loaded checks, installed water-column input and cavity checks, five corrected disk reconstruction checks and 818 composed checks passed across 23 reviewed views. The boiler adds six draws and the concrete hearth reads lighter. Frame timing, human play and artistic acceptance remain open. [Fixed boiler evidence](C:/ov/reports/fixed_boiler_intake_20261119/REPORT.md).
  - PR415 qualifies the fixed electrical enclosures and feed, including 23 mounted spans, both retained cover sets and sixteen saddle bearings. Passed 159 loaded, 444 installed and 818 composed checks with 23 paired views reviewed. Six orphan screw draws were removed. The original fuse probe failures are retained. [Electrical evidence](C:/ov/reports/electrical_fabric_intake_20261119/REPORT.md).
  - PR416 resolves the fuse qualification failure by delivering cursor events through the test viewport. Passed 62 nearby checks and 50 installed checks, including the physical 15-amp repair and a fresh world restoring the saved protection. Continuous basement access and owner acceptance remain open. [Fuse evidence](C:/ov/reports/fuse_inspection_qualification_20261119/REPORT.md).
  - PR417 refits the night register's five ruled-page charts. Import and the first shift ritual passed, along with 46 installed checks and 818 composed checks across 23 reviewed views. The installed diagnostic covered mouse signing and disk reconstruction. The existing 1.93 mm held pen contact gap and owner acceptance remain open. [Register evidence](C:/ov/reports/night_register_rule_intake_20261119/REPORT.md).
- **K-V2-LOBBY-FLOATING-SCULPTURE — Retired at Lily’s request.** PR 566 removed the Venus installation from the lobby. The earlier placement and route checks are historical. [Removal and qualification](https://github.com/NateHiggins/Lily-s-Music-Box/pull/566)


- **K-V2-LIFT-CONTROL-INTAKE — Installed and technically verified.** The three native assemblies retain their mount frames and the live lift controls use a 3 mm physical press. The 117-check live cycle and disk reconstruction passed, as did the composed surface review. Human play and art review remain open. [Fit, gesture and evidence](design/ORISON_V2_HOMES_AND_LIFT_PROGRESS_2026-09-25.md#native-call-plates-cab-controls-and-dial).

- **K-V2-QUALIFICATION-DEBT — PR151/152/168 merged.** The exterior shadow candidate renewed the original authority/save, 60-room apartment, rendered-surface and six-route exterior suites at **74ad19328**. Both source guards passed. The four original packets and 82 technical frame reviews are published. PR169 merged at **090ee3a18** after exact candidate **dbaf1952c** passed 119 comparisons with zero blockers or regressions and 17 protected paths unchanged. Laurel movement stutter, human play, artistic acceptance and whole-V2 qualification remain open. See [current handoff](HANDOFF.md) for evidence and retained failures.

- **K-DOOR-PASSAGE — Implemented/technically qualified on main; human play remains (RUL-018).** Guided directional passage, authorized unlock, click/key and stay-open policy implemented. Policy47/0, player65/0, keys/save362/0, NPC115/0. At755ac96e4: apartment34waypoints/0, closer161/0, hose crossing167assertions/0, nearby world106/0; stderr empty. Companion self-recursion repaired; regression05 passes own-controls91/0, work-clearance78/0 and renewed world106/0 with empty stderr/current source bindings. Original failures retained. PR255 merged2f133edd1 with exact qualifiedfe16c8428 tree; final132-gate comparison zero new regressions/protected17/17. Human play and game-feel acceptance remain. Canonical staged bar excluded; Athena/Optimus held.
- **K-NPC-LOOP-PERFORMANCE — Codex.** [Combined candidate #608](https://github.com/NateHiggins/Lily-s-Music-Box/pull/608) passed the 13-visit, 49-phase conversation suite (1,048 checks) and the installed Friday witness routes (108 checks). Default Friday mail, Saturday laundry and both Kessler replies have separate installed proof. The [six installed guest cases](C:/ov/loop_review_batch02/guest_visits_standing_mark03/shots/runtime_contract.json) pass unlocked arrivals and locked refusals at tea, drama and box (157 checks), including Nadia’s first-person conversation and restored camera/input. [Sunday reception and Continue](C:/ov/qa-profiles/price-continue-repair03/evidence/runtime_contract.json) passed 21 installed checks and 41 save-compatibility checks. Both brothers returned to their noon marks after title Continue; the player-closed door stayed shut. [Pantry-pressure mail](D:/ov_reports/loop_release_20261127/pantry_mail02/evidence/runtime_contract.json) passed 44 installed checks, including all five lines and Peter’s departure. First-slice renewal passed 369 checks, and all 23 surface views passed technical review. Mailbox lip sync and artistic review remain open. [Full scope](design/drafts/npc_loop_scripts_2026-11-12/SOURCE_INTEGRATION.md).
- **K-VOICE-PRODUCTION — Codex recording, Claude runtime playback.** All 109 cast parts for 107 authored loop lines are privately assembled with lip cues. Resolve the installed mailbox frame that lagged audible speech by 316 ms, then verify both speaking bodies, guest handoffs, interruption and reload before publishing the manifest. In-game listening, facial review, the separate resident archive, uncast roles, Lily’s reference and dynamic inventory remain open. [Scope and custody](design/VOICE_LINE_INTAKE_2026-11-11.md).
- **K-CAST-SWAP-REMAINDER — Claude, Omni w9189b10b24ac:** all eighteen residents wear rebuilt bodies, change clothes by the wardrobe rules, sit at measured stool heights (PR330) and are borrowed by the dream (PR331). Left: the second transient guest beside the first (needs route, door and occupancy integration, not a trailing body), and retiring the old bodies once Lily accepts the rebuilt cast in play; old bodies stay the fallback until then.

- **K-LOOP-ENSEMBLE (Codex)** Qualify resident work, listener reactions, dialogue and first-person framing on all authored visits and ordinary exchanges, including blocked arrival, interruption, return, rescue choices and both endings. Keep acted, runtime-tested and played results distinct. [Scene directions](design/LOOP_SCENE_DIRECTION_2026-11-26.md).

## D — Unresolved decisions and integration

**D1–D4** travel with the deferred studio brief below. **D5** was answered by the
relative-luminance default; **D6**'s cabinet decision is retired with that plan.
Neither changes period pub games or the separate mechanical fortune-teller.

- **D7** **Integrate the backed-up work** (2026-09-19): the main checkout's
  and the dream-voxel worktree's uncommitted work is now safe on
  backup/main-checkout-wip-2026-09-19 and backup/dream-voxel-s2-wip-2026-09-19,
  but it is still not integrated anywhere. The agent that owns each should
  commit it properly; then delete the backup branches. Both still exist on
  the remote as of 2026-10-25. The golden-shift half of this row is answered:
  the owner approved that cleanup on 2026-09-19, its branch is tagged
  `archive/2026-09-19/claude/golden-shift-v2-verify-c72c73` and its worktree is
  gone. `design/REPO_HOUSEKEEPING_2026-09-19.md` §7.

## A — The mechanical fortune novelty

Playable video cabinets remain retired. **A2/A4–A10** and the old cabinet-specific
plan are cancelled by the owner; original sources/programmes are preserved.
The future redesign remains deferred, separate from **A11**, which stays in V2.

- **A11 — BUILD “THE HOUSE HEARD BIG,” ONE 1927 MECHANICAL FORTUNE
  NOVELTY.** Owner-approved; execute `design/ORISON_FORTUNE_TELLER_BRIEF.md`
  and the audited owner contract in `design/HOUSE_HEARD_BIG_ORCHESTRATION.md`.
  Do not restore a video-cabinet cluster. Mechanism: John J. Scharli Jr., US
  1,621,756 (filed 1925,
  granted 1927), a coin-controlled fortune-teller whose mechanical head nods
  yes or shakes no according to the coin's path. Alternate: the 1926 Mills
  legend-wheel fortune/vending machine, US 1,586,455. Compare against a compact
  bagatelle/trade stimulator and mutoscope only with pre-1929 primary evidence;
  familiar coin-op pinball silhouettes are presumptively too late. One object,
  one cheap mechanical loop, bounded sound, no viewport, and no story authority.
  Audit the obsolete `orison_original_advert_lobby_v1.png` source at the same
  gate: default recommendation is archive as concept provenance and remove its
  unused runtime prop after reference migration, not rescale it into production.

## G — Local music and found traces

Preserve local songs, recording/reconstruction and listening. The phonautograph's
existing playback/trace rules remain in Bible §III.2 and the Songbook references;
archiving a completed local-contract note does not change those rules.
Network distribution, phrase duels and the House Rig audition are deferred below.

- **G4b** The sleeves are the hook and they are deliberately thin: "for M." with
  four residents whose name starts with M, a WORS sleeve with the date rubbed
  out, one found behind the pipes, one with no sleeve at all. **Nothing in the
  bar can resolve any of them.** What the basement studio should be able to do
  is say something about a trace the bar cannot - a cleaner read, a second
  voice, a date - and that is the errand.

- **G-FILM-FIRST-LIGHT — Codex.** Screen the continuous Vantry bench study, then stage one resident listening, test one reset with retained evidence, and assemble the pilot. [Four milestones and acceptance checks](design/CINEMA_DUAL_PIPELINE_PLAN_2026-11-26.md).

## B — The Harukiya rebuild (owner commission 2026-08-16)

Lily accepted the venue look and the all-evening stage layout, then played and
accepted the live set on November 18. [Venue acceptance](D:/ov_reports/harukiya_overhaul_20261112/closeout_20261118/FINAL_ACCEPTANCE.md)

- **B1, B1a, B1b — Stair and red door delivered.** The 15 treads span a 1.60 m shaft.
  The rail and stored goods leave about 0.90 m at the pinch point. Opposing traffic
  takes turns there. The reinforced oxblood door opens onto the room. The central
  well measures 5.32 m clear. [Entrance and passage checks](design/HARUKIYA_ENTRANCE_REFURB_2026-11-14.md) · [Measured section](design/HARUKIYA_DESTINATION_OVERHAUL_2026-11-12.md)
- **B2 — Landing dressing delivered.** Loose paper and metal scraps mark the treads.
  Bundled newspapers, crates, a rolled rug and cleaning gear give the service side
  a purpose. Lily reviewed the entrance as part of the venue. [Entrance and room views](D:/ov_reports/harukiya_overhaul_20261112/closeout_20261118/Harukiya_review_1.jpg)
- **B3 — Lounge jukebox installed. Lily’s review of its setting is open.**
  From the public aisle the player can select three original records, read the
  lit title, stop the motor at the coin return and continue to any of the 24 seats.
  The installed destination run passed 1,543 checks. [Destination receipt](D:/ov_reports/harukiya_jukebox_20261125/room03/shots/runtime_contract.json)
- **B4 — Venue construction delivered.** The stage and backstage, balcony, pool
  table, darts, counter and seating are in service. The destination receipt
  covers physical access and use. The venue review covers the room’s appearance.
  [Balcony, practicals and red-door views](D:/ov_reports/harukiya_overhaul_20261112/closeout_20261118/Harukiya_review_2.jpg)
- **B5 — Preserve the bar’s identity in future edits.** Keep the teal descent,
  red steel door, deep counter canopy, barrel stock and crowded backbar pictures,
  violet felt and lighting from visible fixtures. Lily retired the two arcade
  cabinets in Q02. [Identity ledger and amendments](docs/harukiya_reference_notes.md) · [Owner decisions](design/V2_TASK_RELEVANCE_REVIEW_2026-10-27.md)
- **B-PERFORMANCE — Live trio accepted.** Adela leads at the piano, Lily plays
  bass and sings harmony, and Stacy plays drums. The remaining writing covers
  the whole-person portrait, costume and found-family scenes, Lily’s own lines
  and the story’s date and knowledge boundaries. Preserve the murder canon and
  the ruling that transness can never be the twist, a clue or a motive.
  [Story and writing decisions](design/V2_ADELA_SOUND_PICTURE_PLOT_2026-11-01.md) · [Performance and found-family brief](design/V2_ADELA_PERFORMANCE_AND_FOUND_FAMILY_2026-11-01.md)

- **B-PULL-UP-A-CHAIR-MV — performance recapture delivered November12:** full1080p24 song,23shots under **C:/ov/reports/pull_up_a_chair_music_video_20261112/performance_v2/delivery/**. Adela lead+piano; Lily drums+selective harmony. Native singing/contact proofs,4372-frame reach sweep, pickup repeat, encoded motion proof, exact final frames/full decode and allshot/seam/ending samples pass. Original audio preserved. Music-video workflow added to canonical machinima skill. Derived timing/harmony/fingering and inherited mesh limitations in **performance_v2/DELIVERY.md**; continuous audiovisual review and artistic acceptance remain open. All jobs terminal; no upload or gameplay qualification claim.

- **B-DRUM-BRUSHES — Codex in progress, Lily request November12:** model a pair of wire drum brushes for the Harukiya kit, and study referenced drummer technique before animating them. Deliver Blender source, game-ready UV/PBR meshes, measured handle grips and contact points; demonstrate Lily holding them correctly, continuous snare sweeps, taps/accents, wrist/finger motion and transitions to/from rest. Review close views and a short moving proof on the actual kit, synchronized to appropriate brush audio; preserve the existing stick performance. Native brush pair asset and collision-free loader merged PR3380324dcc0f:47closed stocks,45wires,5692triangles/two draws per brush, existing maps only. Native02 three views inspected; loaded03 Vulkan47/0, imported tips/UV/tangents/mips and malformed-datum negatives verified. Clean qualification brush47/0, fresh physical798/0/23reviewed views and candidate0regressions/0waivers17protectedV2. Original failures retained. Lily deferred further pose work on November17 (good enough for now, return later). STOP brush/other pose refinements; private finite probes terminal, no production pose change. Flex/contact/skin, brush audio and authored performance integration remain OPEN for later; existing sticks/bass pose unchanged. [Asset and next step](design/HARUKIYA_DRUM_BRUSHES_2026-11-17.md).

- **B-PULL-UP-BASS — full trio delivered for review November12:** **C:/ov/reports/pull_up_a_chair_music_video_20261112/bass_v3/delivery/Pull_Up_a_Chair_Bass_1080p.mp4**,1080p24,4372frames/182.166667s. Approved r17 looks in private fixture; Adela lead/piano, Lily bass/harmony behind and beside bass, Stacy drums. Native Lily opacity repair preserves geometry/rig/texture bytes and was handed to Fable for gameplay integration. Loaded outfit surfaces,4372-frame contact sweep(max3.51mm),10s motion proof, both capture chunks, full final decode and all23shot/seam/ending samples pass;3649 source hashes unchanged. Originals/failures and final private sources retained; jobs terminal/freeze released. **bass_v3/DELIVERY.md** records limits: fine hand/cloth contact, static fringe, derived musical timing; continuous audiovisual review and artistic acceptance open. No upload or gameplay qualification. Then **K-NPC-LOOP-PERFORMANCE** verification.

## E — Entropy: the building gets dirty (owner direction 2026-08-16)

Design orientation, not yet a build. Brief:
`design/ORISON_MAINTENANCE_ENTROPY_BRIEF.md` (PROPOSAL — owner review
required). The pitch: dynamic grime, litter, burnt bulbs, wall damage,
clogged WCs, dripping taps and simple appliance faults, all restorable by
a maintenance worker with immediate visual feedback — **Sisyphean in
aggregate, instantly rewarding in the hand.**

- **E1 THE ARCHITECTURE IS THE SECOND SENTENCE, not the first.** The
  owner's follow-up is the real design: *strip the authored decal spread
  so the building is pristine, then simulate resident action and let the
  damage fall out of it.* Today wear is authored — `build_wear_decals()`
  bakes it into the glTF and `AtmosphericDecalPass` places residue from
  rules and unit hashes — so a designer decides the floor looks used.
  Under E1 the condition of the building becomes the **output of the
  eighteen residents already running routines, schedules, navigation and
  240 life sockets**. The building then tells the truth by itself: the
  stair people actually use wears, the corridor outside a struggling
  resident reads differently, and a case that changes behaviour changes
  the wear without anyone authoring it.
- **E2 "PRISTINE" DOES NOT MEAN "NEW" — do not strip the wrong layer.**
  The Orison is 1912, reopened 1928: sixteen years old at game start and
  never new during play. **Inherited patina stays baked** (the dished
  marble tread, the rail polished gold at hand height, wallpaper faded
  from the window) because that is architecture. **Accrued grime gets
  simulated.** The test: *could a person with a mop, a bulb and an
  afternoon undo it?* Yes → simulation. No → architecture.
- **E3 BURN-IN GENERATES THE PAST WITH THE SAME MACHINE.** Day one must
  not look sterile, but the answer is not to author a starting mess — it
  is to run the simulation forward for some weeks of unattended resident
  traffic and open on its output. One machine makes history and present,
  every mark still has a cause, and "how long the building went
  unattended" becomes a free difficulty dial.
- **E4 THE DRAW-CALL TRAP, named before anyone hits it.** One node per
  stain is hundreds of draws in the exact currency this frame is poorest
  in. Build on `MultiMeshInstance3D` per (surface class × floor), toggling
  instances — PS6's after-hours grilles already prove the shape at 1360
  instances. The surface recipe is solved too: `story_decal.gd` (atlas
  region → cached ImageTexture → QuadMesh, ALPHA_SCISSOR 0.08, shadows
  off). Godot's `Decal` node is not used anywhere here and this project
  renders on gl_compatibility — but **re-test before relying on either
  answer**, per the `light_projector` lesson that a documented engine
  limitation is a claim with a date on it.
- **E5 THE SIMULATION IS COARSE.** An accumulation model, not a footstep
  model: residents tick counters on authored anchors, a mark appears when
  a counter crosses a threshold, and the whole thing advances per shift on
  the existing schedule clock rather than adding a second one. Persist
  state per anchor id as a small integer and reconstruct visuals from a
  seed — never serialise a stain's transform.

- **E7 MINIMUM PROVABLE SLICE, arcade-V1 discipline.** One corridor, one
  grime type, one mop, one bulb: seeded anchors in one MultiMesh with the
  station re-measured, a mop stroke that clears an instance **in the same
  frame**, a bulb replaced from stock bought at HARDWARE PAINT (closing
  the loop through the existing errand system), survival through real-file
  save/load, and re-soiling only across a sleep boundary — never in view.
  If that slice is not satisfying, breadth will not save it.
- **E8a OWNER RULING 2026-08-16 — THERE IS NO SCORE.** No meter, no
  percentage, no completion figure, no "building condition: 62%". The
  state of the Orison is legible **only by looking at it**. This is the
  one place where a UI number would destroy the entire feeling: a
  percentage converts a building you are caring for into a task you are
  failing, tells the player the global victory is theoretically available
  when E2's whole design says it is not, and replaces the evidence-reading
  the system exists to create with a glance at a corner of the screen.
  Applies to HUD, the ORDER device and any menu. Residents noticing is
  allowed (E8b); arithmetic is not.
- **E9 OWNER RULING 2026-08-16 — PURGATORY, AND MURPHY'S LAW IS A
  DIRECTOR.** *"This is purgatory. Apply Murphy's law and make it part of
  the horror."* This promotes entropy from a chore layer to a **horror
  system** and settles the Sisyphean question at the level of metaphysics
  rather than tuning: the building never comes right because that is the
  condition of the place, not because someone picked a decay rate.
  Sisyphus is not badly balanced; he is in the correct location.
  **The architecture the ruling implies — "when this happens is a gameplay
  decision":** *the simulation loads the gun, a director fires it.* The
  resident-traffic model decides what is ELIGIBLE to fail and how close it
  is; it never decides when. A separate owner, of the same family as the
  existing sleep-pressure and dream directors, picks the moment for
  dramatic effect. Pure simulation is arbitrary, pure scripting is
  predictable; this is neither, and it is tunable without touching wear.
  **The discipline that stops it becoming punishment:** Murphy's Law must
  be *dramatically* timed, never *punitively* timed. Test every instance
  by whether it makes a better story or merely a longer walk. It must
  never invalidate committed work, never undo a repair already made, and
  never fire during a protected interaction — `call_locked` and the dream
  boundary already define those windows and it respects them exactly as
  sleep onset does.
- **E10 OWNER RULING 2026-08-16 — APPLIANCES HAVE THREE STATES:** working
  → **functional but failing** → dead. The middle state is the whole
  point: it is the warning, the thing a maintenance worker is supposed to
  catch, and the thing Murphy's Law is allowed to punish you for ignoring.
  A radiator that knocks before it dies is a fair building; one that
  simply dies is a cruel one — the maze brief's fairness bar ("the player
  understands in the half-second before impact") applies here in slow
  motion. It also makes neglect legible as sound and behaviour long before
  it is legible as failure, which is free horror: the building complains
  for weeks before it stops.
- **E11 OWNER RULING 2026-08-16 — DIRT DOES BOTH.** A general grime accrues
  everywhere as the honest baseline of a working building, **and** it
  clusters where the fiction says: the bar after a night, the laundry, the
  stair everyone actually uses. Two layers, not a choice. Ambient means no
  surface is exempt and the mop always has somewhere to go; clustered is
  where the drama and the evidence-reading live. Separate MultiMesh
  instance sets with separate thresholds, so ambient stays coarse and
  cheap while the hot spots carry detail.
- **E8b STILL OPEN** (brief §9): does degradation advance per shift rather
  than per hour — the last unruled question.

- **E13 — DEFERRED AFTER V2: GENERATED COMMENSAL C2 ANCHORS (BLOCKED BY E14 AND SHARED-FILE
  SCHEDULING).** After a successful C1, reserve an uncontended `gen_layout.py` pass
  and emit marker kind, species affinity and clearance-validated run-lines as
  generator facts. Never hand-edit JSON or put coordinates in runtime code.
  `gen_layout.py` is known contended ground: inspect shared index/worktree,
  confirm no other lane holds hunks, preserve them if it does, and stage every
  generator/output file by exact name. This is the PS12a lesson made an
  acceptance condition, not a note discovered after a conflict.

- **E15 — DEFERRED AFTER V2: COMMENSALS C2, WAKING BREADTH (OPEN; C1 SUCCEEDED).** Add
  roosting pigeons and one proximity flush, rare validated rat gutter-runs,
  positional guano/web decals, and restrained Passage/B1 casts. Room 0 has no
  animal-exclusion rule. Maintain one
  MultiMesh per class per zone, hard submission caps and no runtime routing.
- **E16 — DEFERRED AFTER V2: COMMENSALS C3, §E INTEGRATION (BLOCKED BY E15 AND ITS OWNER
  RULING).** Move pressure onto §E anchor persistence, route personality-
  filtered ambient complaints through the existing place/fault work-order
  binding, add period countermeasure errands, and let Murphy's director choose
  fair moments from eligible pressure. Never advance a case, undo a repair or
  fire during protected interaction/dream windows.
- **E17 — DEFERRED AFTER V2: COMMENSALS C4, SEPARATELY RULED BREADTH.** Price and rule broader
  audio and the optional Harukiya mouser independently. The rejected haunting
  hush/flush hook is not part of this owner. Commensals never carry signal, imitate the motif,
  confirm a haunting, stalk the player or become dangerous.

## S — Basement studio (deferred after V2)

**D1–D4 / S1–S5 / related G2/G4b**: preserve installed space and listening systems;
defer expansion, storage cages, staffing and echo-return choices. Later survey the
actual V2 room before authoring a restoration desk, chamber or dead-channel chore.
Receiving local/shared versions must not acquire a new basement-visit gate.
Source: `design/ORISON_STUDIO_BRIEF.md`; original requirements remain in Git.

## R — The street's shops

Built in `art/data/shop_interiors.py`. Guide: `design/SHOP_INTERIOR_BUILD_GUIDE.md`.
**The rooms are display cases, not spaces.** They were authored to be looked
into through a storefront; the owner wants them walked around in, by the player
and by NPCs. R2 needs a brief before anyone builds.

- **R1** Measure before resizing. Interior width is the authored bay less the
  200 mm party-wall inset. **Floor area is the number that matters, and it is
  small**: news 8.4 m², radio 15.0, locksmith 17.0, pawn 26.4, druggist 28.7,
  photo 30.0, funeral 30.8, cobbler 32.4, hardware 33.8, diner 35.0, laundry
  37.8 — all of it under a **3.30 m clear ceiling** (`SHOP_CLEAR`). That ratio
  is the complaint: these are tall narrow slots, not rooms. Player capsule is
  `BODY_RADIUS` 0.33, so a 0.66 m body needs ~0.9 m of aisle not to scrape.
- **R2** Enlarge and re-plan. **RULED BY THE OWNER 2026-08-10: DO NOT GAIN
  SPACE VERTICALLY.** Ceiling height is not usable space — a taller slot is
  still a slot. Three requirements, together: *historically accurate*, *less
  interior clutter so the player can move*, *use the space to its fullest*.
  They reconcile the way a real 1928 shop did — **density at the perimeter,
  clear floor in the middle**. Goods went floor-to-ceiling on the walls, behind
  and under counters, and overhead on rails; the customer floor stayed open,
  because the shopkeeper fetched. Fully stocked and walkable is the period-
  correct answer, not a compromise between them.
  Mechanically: **depth is the cheap axis** — `SHOP_PLAN` cuts further into the
  block and nothing is behind the south row. **Width is not:**
  `_south_street_wall()` makes every shop its own building, so `x0/x1` drives
  the footprint, void, awning, blade and signage together. Two cannot grow
  backward at all — the diner sits in the Harukiya's mass (`nbr_s2`) and the
  druggist in `nbr_w`. Nothing has been built yet: `SHOP_CLEAR/SHOP_H` are
  still 3.30/3.55 and every `SHOP_PLAN` depth is as filed. *Needs the brief.*
- **R3** NPCs have no way in. Movement is anchor-to-anchor in
  `resident_routines.gd` — there is **no NavigationRegion3D or NavigationAgent3D
  anywhere in the project** — so "NPCs move around inside" means authoring venue
  anchors per shop, not dropping a navmesh. Overlaps #22 (favourite spots) and
  should be done with it rather than twice.
- **R5** Two things the re-plan must not break: the **181 per-shop buffers**
  (fittings falling back into floor-wide buffers is what made the bodega go
  black), and `ShopEntryTest`'s ruling that the NEWS CIGARS proprietor side stays
  inaccessible — that one is deliberate, so changing it must be a decision.
  Watch the street elevation too: **32.53 ms** after the door pass streamed 120
  doors (it was 47.11 when this was filed), so there is real headroom for
  fittings now — but it is still double the budget, so spend it deliberately.
- **R6** **Residents walk through furniture, everywhere, today.** `resident_nav.gd`
  builds its AStar graph from `fl["walls"]` alone and never reads a prop, so the
  router cannot see a counter, a shelf or a display case. Harmless while NPCs
  only cross open corridors; fatal the moment they are asked to move inside a
  fitted shop. R2's re-plan is wasted unless the router learns about fittings —
  and the fix is worth having building-wide, not just on the street.


## V — Navigation, access and the play space

- **V-MINA-BATH-PASSAGE — merged in PR313 (eb036f837), full route technically verified.** The 15 cm sink-stance change clears the installed 90-degree door and all 31 final-leg samples. PR369 and PR370 clear the checkout custody and front approach. With the endpoint check corrected, the composed Vulkan tour reached all eight prescribed destinations and returned home from each in one run, 523.6 m and zero failures. The test used ordinary player input to clear the public approach and stepped the clock for checkout. [Receipt, original failures and scope](design/V2_MINA_BATHROOM_CLEARANCE_2026-11-16.md#current-destination-coverage).

- **V-SEATED-DRAPES — Claude, Omni w39b8516474ec.** PR330 installed the technical skirt and seating fixes. The authored drapes, drum and piano garment strain, inter-panel leg exposure and nine small soft-cushion overlaps remain with this order. Coordinate source freezes before new renders.
- **V-SHOP-CIRCULATION — Codex, Omni w2f2ceb29be3d:** The eleven-shop arcade and 2 m mirrored storefronts merged at **e7c3fc4be** ([PR 342](https://github.com/NateHiggins/Lily-s-Music-Box/pull/342)). The north-side bodega's paired 2.10 m frontage and 2.86 m rack aisle merged at **b57d520ff** ([PR 346](https://github.com/NateHiggins/Lily-s-Music-Box/pull/346)). Loaded frontage 1,256/0, 18-waypoint entry/receiving/trade/return and paired disk restore, composed surfaces 818/0 with 23 reviewed views, and exact comparison zero regressions. Native path sweeps clear. The original Rhea/Nadia overlap is preserved. The targeted follow-up passed 164/0, observing the existing timed cue, full separation and both native approach endpoints. The ordinary FIFO test passed 163/0. Nearby mixed passage passed with full body clearance and the original resident yielding. Baked arcade clock re-entry now restores all eight moving hands. The regression passed 677/0 after the original 677/9, and the composed route passed 52 waypoints. The 63-piece candidate passed 679 nearby checks and two ordinary walks plus a sprint approach at 52/0 each. Reload took 5.67–5.77 s, down from 6.58 s, and loading render p95 was 121–128 ms, down from 153 ms. PR352 merged the qualified 63-piece loader at **437b530da**. Its standalone Windows build reached Vulkan runtime ready and all 63 packaged pieces matched their hashes. Residual frame pacing, owner play and artistic review remain open. [Source and proof](design/V2_ARCADE_PLAZA_REWORK_2026-11-16.md).

Opened 2026-08-13 from the map-redesign Phase 0 measurements
(`design/FINAL_MAP_REDESIGN_BRIEF.md`). R6 is the parent complaint; these are
the specific defects behind it, and V1 is the revamp the owner asked for.

- **V1** **Revamp resident pathfinding.** `resident_nav.gd` builds one AStar3D
  per floor from `building_layout.json` room rects, door markers and leafless
  wall openings, and **never reads a prop**. R6 is the symptom, this is the
  job. Wants a brief before code: the router has to learn fittings without
  becoming a navmesh, because there is no `NavigationRegion3D` or
  `NavigationAgent3D` anywhere in the project. Today: 336 nodes over 8 floors,
  57 wall-crossing edges rejected, 314 relinked.
- **V2** `validate_with_collision()` raycasts **once**, two physics frames
  after build (`resident_routines.gd:350-354`), against whatever colliders
  exist at that instant. Props spawned, moved or possessed later are invisible
  to the graph, and the relink step will happily connect an island through a
  gap that closes afterwards.
- **V5 DONE.** **Four shops sat outside the lateral stage boundary.** `STAGE_W`
  −20.10 / `STAGE_E` +20.60 against a parade running x −32.4..31.6 leaves
  laundry, cobbler, hardware and photo — **139 m² of fitted, lit interior** —
  beyond the playable bounds. **ANSWERED 2026-08-13 by `RouteProbe`: they are
  REACHABLE, and the play space leaks.** The south pavement sweeps walkable
  end to end to x −30.0 and x +29.5, and all four shop doors are reachable —
  every approach stops at 94%, on the glazing or on the laundry's own
  `HingedLeaf`. `ExteriorStreetStageBoundary` is two boxes 7.55 m deep centred
  at y −13.45; they close the north walk and part of the carriageway and never
  touch the south pavement. A player can stand ~10 m outside the intended
  lateral limit. Containment failure, not inaccessibility. Phase 3 moved all
  eleven shops into the Passage; Phase 4 replaced the partial boundary with
  visible hoarding/weather across both complete street sections.
- **V7** Reach versus authored height: the interaction ray is 2.1 m from a
  1.41 m eye, while measured shop counter tops run 1.05–1.18 and photo's brass
  top sits at 1.41–1.45, i.e. exactly at the eye line. The build guide states
  0.90–1.05. Decide which is canon before a Passage reuses those boxes.

## L — Light

`tests/RoomLumaAudit.tscn` guards this. **Run it windowed** - it reads pixels
back, and a headless run reports every room black. It turns each room's own
switch on before measuring, because a room the player has not lit is a mood
choice while a room still void after the switch is a defect. `LightingAudit` is
the companion and checks COVERAGE only; it never looks at a pixel, which is how
this went unseen for months.

**127 rooms PASS, `KNOWN_DARK` empty.** Keep it empty - anything added there is
an open defect, and rooms that are *supposed* to be dark go in
`INTENTIONALLY_DARK` with a reason.

- **L9** Owner call, now that they are visible: `B1_BOILER`, `B1_COAL`,
  `B1_ELECTRICAL`, `B1_STORAGE_CAGES` and `ROOF_OPEN` all read between 12 and 56
  with their lights on. A boiler room is *allowed* to be dark. If any of them
  should be, move them to `INTENTIONALLY_DARK` rather than leaving them lit by
  default.
- **L10** The audit measures one frame per room from a corner, with a fallback
  to the room centre. Rooms whose interesting half is neither will read
  optimistically. Worth a second angle if this ever becomes a shipping gate.

- **L14 THE RUNTIME LIGHT BUDGET IS 16/16 AND `UNLIMITED` IS DEAD TEXT.**
  Found 2026-08-16 by an adversarial review of a V4 lighting plan, after I
  had already written the opposite into HANDOFF from reading constants
  instead of callers. `light_rig.gd` declares `UNLIMITED = 4096` and its
  header narrates a desktop budget removal — but `building_root.gd:456-465`
  calls `set_budgets(16, 16)` (cinematic max quality) or `set_budgets(14, 8)`
  (every other path) immediately after constructing the rig, on every boot.
  There is no branch that leaves it unlimited. Empirically, every run prints
  `[LIGHT RIG] budgets resolved: 16 active / 16 shadow`.
  **Consequences:** real lights are scarce after all — sixteen active, and a
  new one EVICTS an existing one, so any lighting design must name its
  victim. The "measured at 16/16" tables across the docs were describing the
  live budget, not just a test condition; only the mechanism they blamed was
  stale. **Cleanup owed:** delete or correct `light_rig.gd`'s dead
  `UNLIMITED` narration and `building_root.gd:460-461`'s comment that
  "sixteen is the renderer's actual per-object ceiling" (it is 128) — a file
  that argues against its own caller is how this survived. And the rig
  already knows the lesson: it prints the resolved pair precisely because "a
  wrong budget number survived in three documents because nothing ever
  printed the one actually in force" (`light_rig.gd:328-330`). Read the
  print, never the constant.
- **L13 SHADOWS ARE THE SCARCE CURRENCY — RULED AND ENFORCED 2026-08-16.**
  `positional_shadow/atlas_size=8192` subdivides per caster, so every added
  shadow-casting fixture shrinks every existing shadow — raising the caster
  count while leaving the atlas fixed is how you make shadows worse by asking
  for more of them. **Owner ruling: a new fixture ships with
  `shadow_enabled = false` and has to earn a caster slot.**
  Authored fixtures already obey this by construction: LightRig ranks them and
  grants shadow through `LightFixtureProp.set_budget(..., with_shadow)`, so
  they cannot creep. The population that *can* creep is ad-hoc lights built
  directly in scripts, which answer to nobody — measured at **8** in the
  production scene (exterior moon, the carried service lamp, the entry
  composition rake, one further composition spot, four street-lamp omnis)
  against 16 LightRig-governed fixtures. LightingAudit now gates exactly that
  population (`UNGOVERNED_CASTER_BUDGET`); raising it is allowed and is the
  point, but it must be a deliberate edit naming the new caster, not drift.
  V4 lighting spends against this rule.

## T — The street and its traffic

Ruled and built under `design/ORISON_STREET_BRIEF.md`. The owner's later weather,
road-clearance and night-readability directions supersede the brief's four old
questions: the ends are quiet dense storm rather than loud tears; only traffic
emerges (no expelled debris or people); the rail-less tram is the authored wrong
5%; and traffic continues at night.

- **T1 DONE — BUILT RULINGS RECONCILED.** §8 now records the four decisions
  already present in production. This is documentation of the approved street,
  not a new spatial or fiction decision.
- **T2** **BUILT.** `StreetTraffic` - one MultiMesh for every vehicle, scaled
  and tinted per instance, plus a second for lamps. Ten kinds: dray, motor car,
  coal lorry, van, hansom, milk float, tram, hearse, and the wrong 5% (one too
  long for the road, one with no horse and the horse's pace). **It costs
  nothing**, which is what instancing from the start bought: street elevation
  measures **30.30 ms against the 33.28 ms baseline**, and objects went 14,081
  -> 14,145 for fourteen vehicles.
- **T2b** **Voices built, on FORGED audio - placeholder.** Five
  `AudioStreamPlayer3D` reassigned to the nearest vehicles each frame (fourteen
  would be fourteen voices competing on the worst station in the game), pitched
  by speed and by vehicle size so a lorry sits lower than a car. The loops
  themselves are synthesised in `_forge()` and **should be deleted the moment
  real recordings land** - see `design/STREET_AUDIO_SHOPPING_LIST.md`, which
  lists six sounds, CC0-only, with #1 and #2 alone enough to pass the brief's
  own test of crossing by ear.
- **T2b-old** Original note: The brief asks that a player
  can cross by EAR with the camera facing a door, and there is no sound on it
  at all yet. That is the single biggest gap between this and the brief.
- **T2c** **Silhouettes built.** Four original batches carry bodies, cabs,
  wheels and lamps, so each vehicle is a stepped shape on four wheels rather
  than a crate sliding down the road. T2d adds one shared wet-road reflection
  batch, and T2f adds one sign batch only when that rare truck is present.
- **T2d DONE — NIGHT TRAFFIC READABILITY.** Every live vehicle now paints one
  5.2 × 1.55 m broken tungsten reflection ahead of its nose. The whole stream
  shares one shadowless `TrafficWetHeadlightPools` MultiMesh; an empty road
  submits zero instances. It is a soft additive reading cue on the wet paving,
  not illumination: zero `Light3D`, zero shadow, no body self-emission and no
  brighter street lamps. Twin sources widen and dissolve inside a broad noisy
  pool instead of reading as clean game stripes. Fixed canonical-night
  control/control/final frames live in
  `art/renders/traffic_night_readability_t2d/`; the duplicate control records
  live-rain variance. `TrafficNightReadabilityTest` passes. A focused 1440p
  fresh-process pair measured 29.99 ms hidden versus 30.29 ms live while the
  runtime population itself differed by 10 objects / 15 calls, so the delta is
  inside run noise; the structural cost is exactly the one shared draw.
- **T2e** **SUBSUMED BY T2d.** Lamps remain emissive quads and the new roadway
  response remains an additive batched reflection; neither is a realtime light.
- **T2f DONE — WE TUNA PIANOS.** A rare 1928 one-ton piano-repair box truck
  joins the ordinary two-way stream at 2.0 / 99.0 selection weight. Its final
  projected body stays inside 5.8 × 2.05 × 2.30 m and embeds four dull material
  plates — side, rear, paint and the repaired shark-and-mustachioed-tuna panel
  — in one shared shadowless truck MultiMesh. The older separate sign batch is
  fallback-only and submits zero instances while the production GLB is present.
  There is still zero light, collision, stop rule, dialogue or permanent
  scenery. `PianoRepairTruckTest` now proves the landed mesh contract rather
  than the superseded box fallback; production-street frames are under
  `art/renders/piano_repair_truck/`.
- **T2g DONE — COACHWORK SURFACE.** Ordinary body and cab batches keep their
  authored per-kind tints but now take normal and roughness from `car_paint`,
  with zero metallic; tyres independently use matte `rubber_aged` and the one
  shared wheel mesh rises from 10 to 16 radial segments. No owner, draw, light,
  shadow or motion rule was added. Whole-frame change is below live-rain noise,
  but the foreground-vehicle crop is 10.4× its A/A floor. Contract and frames:
  `art/renders/traffic_paint/README.md`.
- **T3 DONE.** No death, damage, UI or dedicated crossing point. A hit now
  carries the real player with the vehicle for 0.72 s, damps rather than removes
  steering, gives the camera one restrained 4.9° roll and recovers without an
  input. Look remains live. Traffic owns four seconds of repeat immunity, so
  contacts cannot stack into a launch; calls and noclip cancel/reject the state.
  The carry vector follows world X, correcting the old cross-lane axis error.
  There is no health state, get-up prompt, fail screen or bespoke impact audio.
  `MAX_WAIT` remains an enforced promise rather than a tendency.
- **T3b DONE.** `PlayerController.stagger()` is the narrow public contract;
  `StreetStaggerTest` drives it through production `StreetTraffic` and proves
  displacement, recovery, retained look, non-stacking, protection and the
  absence of damage state.
- **T4 SUBSTRATE DONE.** The partial lateral collision is retired. At exact x
  −20.10 / +20.60, wet timber works own both pavements and quiet local weather
  owns the carriageway; `StreetContainmentTest` proves all six lanes. This does
  not settle T1's loudness, debris, arrivals or night-traffic questions.
- **T5 DONE.** The 4.4 × 1.4 m shelter is restored at (−12.6, −25.55) with
  literal 100 mm posts, glazed back, centre mullion, timber bench, bounded
  local material ownership, physical close-weather cover and a zero-light
  **CARS STOP HERE** board. Only eastbound trams serve it: one stop at x
  −10.40, one 4.5 s dwell, then an eastward resume; every opposite-lane or
  non-tram control passes through. Both pavement bypasses remain capsule-clear.
  Five visible owners cost 14 submissions and no measurable time at canonical
  street elevation (29.98 ms visible and hidden; repeat reversed inside noise).
  `TransitShelterTest` 20/20 plus containment, route, weather, lighting,
  Passage ownership/visibility and WalkTest FULL x8/480 all pass. Day/night
  proof: `art/renders/transit_shelter_t5/approved/`. T2d remains open; this
  task does not mislabel the deliberately crude tram silhouette as finished.
- **T5b DONE — ROAD CLEARED.** The superseded utility-excavation set piece is
  gone: four trench slabs, four spoil heaps, two loose planks, sixteen striped
  contractor barricades and one loose-paper assembly. It belonged to the old
  across-the-road shop layout and was fencing all four traffic lanes after the
  final x −20.10 / +20.60 timber-and-weather boundary took ownership. The
  zebra, traffic, shelter, wet-road detail and both visible stage ends remain.
  `RoadClearanceTest` proves zero obsolete production records, all sixteen old
  barricade stations capsule-clear, and the six-span boundary intact. F01 is
  −10,816 vertices / −17,952 indices / −381,296 bytes; fixed A/B plus a live-
  rain noise control is in `art/renders/road_clearance_t5b/`.
- **T6 DONE.** The first controllable frame now starts on the south kerb beside
  a low teal-black motor car, facing the full 30 ft crossing and Orison door.
  It holds 1.15 s without seizing the camera, accelerates to 6.4 m/s, merges
  into the eastbound lane, crosses the exact x +20.60 storm boundary once and
  is removed at x +27.00. It reuses the shared shadowless traffic batches,
  including T2d's wet-road response, adds no light or collision, cannot replay
  after `intro_complete`, and ordinary traffic resumes after a 5 s first-image
  clearance. The traffic
  player-reference startup bug is also closed. `ArrivalCarTest` passes; three
  fixed morning-rain frames are in `art/renders/arrival_car_t6/`. Transit,
  containment, route, weather, lighting, Passage ownership/visibility and
  WalkTest FAST all exit green. The single FULL x8/480 attempt produced no
  result inside the 60 s bound and was terminated; no FULL result is claimed.
- **T7 DONE.** The historical canonical-night street elevation was 29.30 ms
  against 16.6, still CPU-bound on submission. T7a closes P7's safe script-side
  remainder: the floor/prop/door gate now evaluates an exact eight-storey
  region signature and skips the ~734-actor scan until a visibility boundary
  changes. Direct in-scene attribution measures 0.003 ms/signature versus
  0.207 ms/full scan, **0.204 ms avoided per stable physics tick**. A fresh
  same-build frame pair read 28.79 ms cached / 29.58 ms old scan, but differed
  by 647 render objects, so the 0.79 ms is explicitly not claimed as causal.
  T7b then measured the actual playable north pavement, correcting two probe
  defects first: a detached eye-height override admitted F02, and the census
  counted render-layer-zero zone content plus lights inside arcade SubViewports.
  At the clean lens, Orison-core fixture shadows were the submission leak.
  `LightRig` now keeps their illumination but declines their shadow maps only
  while the player is physically in STREET; entry/facade lights, the phone,
  moon and Passage retain shadows, and ORISON restores the ranked shadow budget
  on entry. Same-build fresh-process controls are 35.929/36.486 ms versus
  26.486/27.042 production: **36.208 -> 26.764 ms (-9.444 ms, -26.1%)**,
  with mean calls **25,309 -> 12,207 (-51.8%)**. A paused same-process A/A/B
  render proves the small visible delta without hiding live-rain noise under a
  false zero; evidence is `art/renders/street_core_shadow_t7b/paired/`.
  LightingAudit passes the outside suppression, exterior preservation and
  inside restore. T7c then removes a second ownership leak: low STREET was
  still submitting 1,150 F01 draws wholly enclosed by the Orison shell. The
  new spatial index gates only complete AABBs behind the shell; WindowGlow,
  the landmark entry, facade-touching compound props and moving residents are
  explicitly protected. Its layer blocker composes with PASSAGE instead of
  allowing either zone to restore the other's hidden geometry. Same-build
  controls are 26.735/26.252 ms versus 22.870/22.794 production: **26.494 ->
  22.832 ms (-3.662 ms, -13.8%)**, with mean calls **11,873 -> 9,433
  (-20.5%)**. Exact production A/A/B frames at three street viewpoints live
  in `art/renders/street_core_geometry_t7c/production_pair/`; entry, windows,
  neon and facade architecture remain intact. `StreetCoreVisibilityTest`
  passes 16/16, including direct STREET/PASSAGE transitions. That pass appeared
  to leave a 6.23 ms gap, but T7d found both the final ownership leak and a
  benchmark-window defect. The approved Harukiya mass is a second F01 interior
  at x -12.0..6.4 / z 28.32..38.2; T7c's central rectangle never owned it.
  A dimensioned second prism now gates its 264 enclosed draws while retaining
  the street face and restoring exact layers on the descent into the bar.
  `StreetCoreVisibilityTest` passes 20/20. T7e batches each neon letter's fixed
  tube/support/boot primitives per finish without merging the letter animation
  unit: the focused proof is 285 -> 51 draws, exact AABBs and working drop/
  restore; the street census moves the Orison blade 202 -> 46 and tenant sign
  98 -> 20 visible objects.

  `WeatherPerf` now warms 120 frames and reports both direct wall-clock time
  and Godot's rolling FPS monitor. At 30 frames the monitor still included
  startup/shader history, so the absolute 22.832 ms T7c remainder was not a
  settled frame; its same-build relative improvement remains valid. With both
  new retained controls on, fresh direct clocks are 17.850/17.649 ms; production
  is **15.905/15.530 ms** (mean **17.750 -> 15.718, -2.032 ms / -11.4%**),
  objects 6,743 -> 5,554 and calls 7,938 -> 6,481. The independent rolling
  monitor also passes at 16.035/15.950 ms. Exact three-view proof lives in
  `art/renders/street_harukiya_t7d/production_pair/` and
  `art/renders/street_neon_batch_t7e/`. The real playable street therefore
  clears 16.6 ms with **0.88 ms direct-clock headroom**; T7 is closed.
- **T8 DONE.** `design/ORISON_DRIVING_RAIN_SKY_PROPOSAL.md` §17 records the
  production checkpoint: one geography-locked four-state storm family, slow
  lower cloud inside the existing sky draw, bounded middle-distance fog, one
  batched realistic rain draw, roadway mist, one synchronized hidden sky key
  and restrained cloud-light fingers. Twenty before and twenty final frames
  plus a fixed-camera cloud-motion pair are under
  `art/renders/weather_sky_t8`. The real-pavement control measured the weather
  below the +0.8 ms contract; WeatherSkyTest 31/31, containment, route,
  lighting, Passage ownership/visibility and WalkTest FULL all pass. Street
  ends, traffic `MAX_WAIT` / `GAP_SECONDS`, the three-zone map and one-light
  budget remain unchanged.
- **T9 PROPOSED — the street wall.** `design/STREET_WALL_PROPOSAL.md`: frame
  the arcade gate (its K0 host is one storey short, per the gateway
  proposal's own §3.1) and close the facade ring around the play area —
  three-layer system, eight-station survey evidence in
  `art/renders/street_facade_survey_v1/`, +0.5 ms perf contract, phases
  W1–W4. Awaits owner ruling on §6 (west-strip character, ghost-sign copy,
  lintel carry); W1/W2/W4 are not blocked by fiction questions.

### T-ENDS — one railway, two bottlenecks (owner proposal 2026-08-18)

Owner: *"lets have one end of the street limited by an overpass that runs close
to but slightly offset from 90 deg over the road? that would limit sightline in
that direction"* — and then, to find the other end an equivalent reason to
bottleneck view and traffic.

**This supersedes the atmospheric answer, and that is the point.** §4 of
`ORISON_STREET_BRIEF.md` records the owner's "tear in the universe" proposal
staged down to "quiet storm, hoarding and middle-distance loss". Haze is what
you use when the world runs out; architecture is what you use when it carries
on somewhere you are not going. The second reads better and costs less
apology — and it retires the hoarding at x −20.10 / +20.60 that the brief
itself calls honest and temporary.

**THE PROPOSAL: it is all one railway.** An elevated line flies over the east
end; the same line comes down to grade and crosses at the west. One piece of
world, one material family — riveted steel, creosoted timber, ballast, soot —
built twice. The Orison is caught between two crossings of one railway, and the
reason you cannot leave is infrastructure rather than metaphysics, which is
exactly the register §4 was reaching for when it warned that a screaming portal
spends the quiet the game runs on.

#### Why the skew is the whole idea, and 90° would not do

At a right angle the bents line up in perspective. From somewhere on the
pavement you get a clean shot straight down the line of columns and out the far
side, which is the one thing a terminator must never give you. **On a skew the
columns never align from any standing point on the street** — each hides a
different slice of what is behind it, and the occlusion holds as you walk.

It also breaks the street's own symmetry for free. The corridor is 16.3 m from
building line to building line (`BLDG_N` −12.0 to `BLDG_S` −28.316). At **79°**
the deck meets the north line **3.2 m** along the street from where it meets the
south, so the two pavements terminate at different points and the soffit reads
as a long trapezoid rather than a band. That asymmetry is what says the
right-of-way predates the street and did not care about it.

#### Where they go, and the systems payoff that decides it

`SPAWN_X` is 52.0 and vehicles are dropped past 56 (`street_traffic.gd:26`).
**Put both structures at that radius and they hide the spawn.** Traffic
currently pops into existence in open view at x ±52; under a viaduct's shadow
and behind a standing freight cut it *arrives from somewhere*. That is the
strongest argument for the whole proposal and it costs nothing extra.

- **EAST, the viaduct** — deck soffit ~6.2 m clear over the carriageway, deck
  ~1.4 m, so ~7.6 m to the parapet. The `ne` blocks run 11.5–21.5 m, so it
  threads *between* buildings rather than over them. Bents just inside each
  kerb; with the skew the north bent stands 3.2 m along the street from the
  south one. A train crossing is a moving occluder and a sound with no visible
  cause from the pavement.
- **WEST, the level crossing** — the same line at grade at about x −50, where
  `nw4` is already the *sooted* block, which is what stands next to a goods
  yard. Gates, a gateman's shanty, a signal, rails and ballast laid across the
  asphalt. **A standing freight cut is the total occluder**: boxcars parked
  across the crossing close the view completely and can leave.

#### What it gives the traffic system, which already wants it

The gap the player judges is currently produced by `MAX_WAIT` and
`GAP_SECONDS` — a promise with no cause. **Gates give it one.** When the gates
drop, traffic queues and then releases in a bunch, which is both a legible
reason for the gap and a better rhythm than a random one. The brief's §2 says
the crossing should be a texture rather than a challenge; a level crossing at
the end of the street is how a real road produces that texture.

#### Open questions for the owner

- Which end takes which. The soot on `nw4` argues for the yard in the west and
  is the only evidence either way.
- Whether a train is ever *seen* on the viaduct, or only heard. Only heard is
  cheaper, quieter and probably better.
- Whether the freight cut is scheduled or permanent. Scheduled costs a system;
  permanent is a wall wearing a good disguise, which the brief has already
  rejected once in another form.

#### Not costed

Nothing here is priced. It is new geometry at both ends of the heaviest floor
in the game, and §DP's rule applies — cost is recorded, not used as a veto —
but nobody has measured it and this entry should not pretend otherwise.

### T-GHOST — the truck's garbled skin as a haunting (owner idea 2026-08-18)

Owner, on being shown the repaired piano truck: *"the director can briefly
remove the fixed panel to reveal the garbled art to cause confusion and
disorientation to a viewer, unsure of what they saw."*

**The defect is already the asset, and it is already loaded.** The Meshy atlas
whose lettering is gibberish at every triangle budget is still on the mesh; the
readable sign is a separate material assigned last over 379 faces
(`build_traffic_vehicle.py`). Swapping that one material back reveals the
unreadable original underneath, on a vehicle already moving past at speed.

Why it is worth building: it is the cheapest possible haunting. No new asset,
no new system, one material swap on an object the player is not studying. And
it fails in the right direction — a viewer who catches it cannot check, because
the truck has gone, and the next one is correct. That is the register the whole
game works in, and unlike a flicker or a stinger it points at nothing.

**Accessibility, which is not negotiable and is easy to get wrong here.** The
brief bans flashing at photosensitive frequencies outright. A material swap
that returns within a frame or two IS a flash. So: the reveal holds for a
readable interval (of the order of a second, not a frame), happens at most once
per vehicle, and never repeats on a cadence. It should read as *doubt*, not as
strobe.

Owner decisions still open: whether the haunting director already has a hook
for street objects, whether it fires on being looked at or on not being looked
at, and whether the rear doors change with the flank or stay correct so the two
disagree.

- **T-V2-TRAMS — Standing order, City Codex, after the city is complete.** Add trams and trolley wire on the Queens Boulevard side of the V2 street, with blue-violet flashes at the trolley pole. Increase arc frequency on the aurora nights defined in `game/data/weather/phenomena.json`. See `design/ORISON_SUN_2026-11-04.md` on `claude/sun` for the existing aurora integration.

### W — Current glazing and joinery gaps

The historical W-GLAZE/W-SHOW/W-JOINERY completion and measurement journal is
archived in the pre-trim source. Preserve optical materials, room reveal/seals,
source-owned joinery, loaded UV/mipmap requirements and any still-reproduced
appearance/access defects under the current V2 surface audit. Do not treat old
pictures or a technically passing surface contract as owner appearance approval.
`design/V2_SURFACE_REQUIREMENTS_2026-10-11.md` governs new city windows as well.

## P2 — The Passage (rehousing the shops)

Ruled as M0.5. Build drawing and measured baseline:
`design/FINAL_MAP_REDESIGN_BRIEF.md`. All eleven shops move. Code is `passage`;
fiction remains “the Vantry Arcade.” This supersedes R2's street re-plan: they
are two answers to the same problem and only this one is built.
- **PS1 DONE.** Check 3 fixes the exact portal, throat, expansion line and
  20 × 26 m hall in `art/renders/map_check3/passage_top_down.*` (`3153ed0`).
- **PS2 DONE.** The obsolete street parade is the isolated rollback commit
  `e102a41`; Phase 3 immediately rehoused all eleven identities in the Passage.
- **PS3 DONE.** Glass barrel vault, iron ribs, eleven units and a six-metre
  terrazzo aisle are built. Phase 5 adds eleven brass threshold nosings, paired
  edge drains and cart-specific wheel wear as three gated finish draws.
- **PS4 DONE.** Three loaded 1920s handcarts form the movable middle layer.
  They are real 46 kg rigid bodies, shoveable by player contact or `[E]`, and
  freeze with their collision disabled whenever STREET owns the frame.
- **PS5** **Carrying changes crossing.** The keystone of the loop: a crate slows
  you, blocks sprint and sits low in frame, so the return leg of an errand is
  harder than the outbound. Wires the Passage directly to section T with no UI.
- **PS6 DONE.** At canonical 03:00, ten ordinary units are dark behind
  source-positioned sliding iron lattice grilles and all three public
  handcarts are frozen behind visible frame chains. HARDWARE PAINT is the one
  night-service exception: Mina's proved maintenance shift buys the carbon
  transmitter capsule there, so closing it would break the full loop. From
  06:30 to 02:00 all eleven circuits return, the grilles fold against their
  piers, their collision disappears and the carts are released. The complete
  state is three bounded MultiMesh draws plus ten real barriers; shopfront
  coordinates exist only as `passage_shop_hours` generator markers.
  `PassageHoursTest` (15/15), Passage navigation/entry/visibility/ownership,
  LightingAudit, GoldenLoopTest (65/65) and WalkTest FULL all pass. Canonical
  before/night/day renders and the same-build focused performance control are
  in `art/renders/passage_hours_ps6/`.
- **PS7 DONE.** Eleven source-owned shop batches import as 263 bounded local
  draws; NEWS CIGARS keeps its inaccessible proprietor side. PassageVisibility,
  PassageNav and ShopEntry all pass on the rebuilt geometry.
- **PS8 DONE.** The real player now walks one deterministic reversible route
  ORISON → STREET → PASSAGE → HARDWARE PAINT customer floor. Passage owns F01
  without submitting the apartment stack, non-Passage F01 actors or 170 foreign
  site draws; the vertically bounded gate keeps the aerial street station honest.
- **PS9 CLOSED 2026-08-14 — owner accepted the measured blocker, and M0.5 is
  COMPLETE.** `ab120dc` is the final production checkpoint. The acceptance was
  earned, not resigned: shadows, prop ticks and submission were each attributed
  and their ceilings measured (brief §10aj–§10an); three ownership leaks were
  found and fixed for −3.1 ms at northbound; and the exhaustive remaining
  ceiling proves no candidate flips the station within the approved
  constraints. Northbound stands ≈17.8 ms against the unchanged 16.6 target —
  **≈1.2 ms over, at canonical pinned night, which is now the authoritative
  benchmark state** (perf_probe pins DAYNIGHT=0; historical interior numbers
  are DAYTIME and must not be compared against canonical-night runs). The 9 m
  shop-batch contract stays enforced — it protects local light selection and
  bounded AABBs — and **cross-shop batching is deferred to project-wide P1**,
  where it requires its own visual, lighting, culling, ownership and
  interaction proof. M1 may begin.
- **PS10 DONE.** WalkTest FULL is a fresh PASS in 48.3 seconds at x8 / 480 Hz.
  Physical walks and shared-elevator contention run before the harness pauses
  unrelated resident routines for the stateful Case 02–08 batch; case order,
  timers and consequences remain intact.
- **PS11 K1 PHYSICAL DIORAMA DONE.** Redesign the jarring STREET → PASSAGE gate under
  `design/VANTRY_GATEWAY_AND_SUBWAY_PROPOSAL.md` and
  `design/VANTRY_SUBWAY_KIOSK_PROPOSAL.md`. Gate A's reversible host/kiosk
  blockout, K0 historical exterior and K1 shallow stair now pass their exact envelope,
  visible-collision, ownership, route, FULL-walk, seven-view render and
  same-build performance controls (§§14–15). K0 replaces the stepped shell
  with iron panels and wire glass, adds unlit `EXIT` / `RAPID TRANSIT`, reuses
  the same two lights, and fixes the east approach's actual black owner: the
  unfinished outward face of `EastSouthWorks`, not the kiosk. K1 cuts only the
  approved kiosk footprint and adds eight real treads, a 1.05 m clear stair,
  tiled cheeks and turn, iron rails, lower landing and a finite dark terminus.
  Its exact source/runtime proof, eight-view dry/weather render set, FULL walk
  and same-build performance control pass in proposal §16. Sound/reflected
  train light remain optional later gates; the next map/environment package is
  T8. A station, cutscene, route, interaction or fourth zone remains rejected.
- **PS12 OWNER COMMISSION 2026-08-16 — THE ARCADE RECONSTRUCTION.** Rebuild
  the Vantry Arcade as a grand 1926 commercial building (Windsor Arcade
  ancestry). Authority: `design/VANTRY_ARCADE_RECONSTRUCTION_BRIEF.md`,
  phases V1–V6. **V1 (the nave raised) is BUILT and verified locally**:
  9.90 m ribbed glass nave, clerestory order, crossing lantern + pendant
  clock, south terminus + directory, throat vestibule, street frontispiece;
  full Passage battery + WalkTest FULL PASS; northbound measured **13.03 ms**
  at canonical pinned night — the PS9 accepted blocker station now passes the
  16.6 gate. Record: `art/renders/vantry_arcade_v1/README.md`. The V1
  `gen_layout.py` hunks + regenerated JSON/GLBs are HELD uncommitted pending
  the parallel session's in-flight W1 street wall in the same file (never
  publish another lane's WIP); commit V1 code immediately after W1 lands.
  **V2 (the rooms behind) is BUILT and verified locally** (2026-08-16):
  eleven rear stock rooms + borrowed lights over every back wall, the
  funeral chapel with parted drapes and chancel rail, service vestibules
  with real light-falloff darkness; battery + WalkTest FULL PASS,
  northbound 13.20 ms; content alarms deliberately raised (1300→1550
  records, AABB gate 9.0→10.5, mesh cap 280→310) with measurements in the
  comments. Record: `art/renders/vantry_arcade_v2/README.md`. V2 generator
  hunks (gen_layout.py + shop_interiors.py) join the V1 hold.
  **V3 (frames, plaques, the face) is BUILT and verified locally**
  (2026-08-16): bronze/nickel glazing families + opal transoms + brass
  tenant plaques per trade; daylight elevation review passed after two
  fixes (continuous sixteen-voussoir archivolt, stepped center attic
  crowning the skyline); PassageVisibilityTest now pins DAYNIGHT=0 itself
  after a wall-clock flake (went red purely because the machine crossed
  2 AM). Battery + WalkTest FULL PASS, northbound 13.54 ms. Record:
  `art/renders/vantry_arcade_v3/README.md`.
  **V3b (street respacing) is BUILT and verified locally** (2026-08-16, owner
  direction "space the arcade on the street better, move the subway exit"):
  measuring the east flank found V3's frontispiece pier base and the K1 kiosk
  plinth **interpenetrating** by 10x620x160 mm — a stale clearance, since K1
  measured its 1.10 m from the bare portal before anything projected from the
  face. The kiosk moved 18.10→18.55 for balanced 0.42/0.40 reveals, taking its
  stair, GROUND_HOLES entry, pavement cut and approach light with it; the
  assert now guards the reveals so the bug returns as a build failure. Full
  battery + WalkTest FULL + StreetContainment PASS. Record:
  `art/renders/vantry_arcade_v3b/README.md`. **Open, not ours:** the kiosk
  footprint overlaps the in-flight W1 flank wall band in plan — predates this
  and belongs to the W1/K0 reconciliation.
  **PS12a HOLD RELEASED 2026-08-16 (`f7963af`).** The generator, the
  regenerated JSONs and all eight rebuilt GLBs are committed; a clean
  checkout now builds the reconstructed arcade and the rebuilt Harukiya.
  About 39 of the 1163 added lines are the parallel session's W1 street
  wall, disclosed in the commit message rather than swept in silently —
  every test ran against that combined tree and passed. If that session
  reshapes W1 it merges normally on top. Historical note follows.
  **PS12a (was) HELD CODE — THE WHOLE RECONSTRUCTION WAS UNCOMMITTED.** V1+V2+V3+V3b
  live only in the working tree's `art/data/gen_layout.py` and
  `shop_interiors.py`, because those files also carry the parallel street-wall
  session's in-flight W1 upper storey and publishing another lane's WIP is
  banned. Everything else (records, renders, shot harnesses, test contracts,
  the `nocol` builder change) is committed. **The moment W1 lands, commit the
  generator hunks** — until then the repo builds the pre-reconstruction arcade
  from a clean checkout, and every render in `vantry_arcade_v1/v2/v3/v3b` is
  ahead of the committed generator. Verified integrated: both change sets
  coexist and the full battery passes on the combined tree.
  **PS12b KIOSK / W1 FLANK OVERLAP — not ours.** The subway kiosk footprint
  (now x 18.55..20.20) overlaps the in-flight W1 flank wall band
  (x 17.35..20.60, y −28.42..−27.92) in plan. It predates the V3b respacing
  and is unchanged by it. Belongs to whoever reconciles W1 with K0/K1; flagged
  in `art/renders/vantry_arcade_v3b/README.md`, deliberately untouched.
  **PS12c STREET ELEVATION IS STILL OVER GATE** at 25.80 ms vs 16.6 (pinned
  night). Pre-existing, unchanged by the reconstruction — the arcade's own
  three stations all pass. Belongs to project-wide P1, not to this lane.
  Next: V4 lighting hierarchy
  (bronze needs light to read; rear rooms get their half-light; the
  night-jewel state), V5 use/aging, V6 abnormalities + perf.

## F — The street film tent

- **F-RELOCATION — Complete the requested period one-person film tent beside the
  bar, retire the three mounted apartment projectors and their abandoned leads,
  and verify entrance, sidewalk and subway access.** Preserve current film
  decoding, source programmes, power, case/haunting and save authorities while
  relocating presentation. A candidate tent is not an installed, qualified venue.
  See `design/V2_STARTED_WORK_CLOSURE_2026-10-23.md` and the current runtime's
  `orison_v2_projectors.gd`. Do not restore old machine counts or apartment rules.
- **F3 — Retain unresolved motion-based content curation.** Inspect complete
  clips, not a single frame; remove incompatible trailers/titles from a shortlist.
- **F5/F11/F12/F5b — Reconcile unfinished film/plate presentation with the tent.**
  Keep any still-missing long-exposure accumulation, optical wear, gate weave,
  keystone, projector beam and state-driven burn as explicit gaps after checking
  the current renderer. Reuse existing accumulators rather than duplicate one.
- **F6/F7/F8 — Preserve film audio semantics and the unresolved reel-selection
  work.** Local chosen programmes/found objects remain distinct from the Tenant
  running a machine. No invented collectible, reward or haunting reach follows
  from this queue cleanup. The magic-lantern alternative in **F13** is historical
  proposal material, not a reason to replace the owner's nickelodeon direction.

Historical completed parts and superseded **F2/F4/F4b/F4c/F14/F15/F16/F9/F10**
placement/count assumptions are archived by source commit in the review record.

## Q — Direct manipulation

Historical **Q1–Q6** completion notes are archived. The current contract remains
primary-click grab, constrained mouse motion, next-click release and supported
inspection. Actual input, pickup/held-book behavior, focus and interruption
requirements remain under **I**, **K** and AGENTS.md; old toggles prove none of them.

## X — The haunting

Audited in `design/ORISON_HAUNTING_AUDIT.md`. Measured, not opined: the
instinct that something in here does nothing was right, but it is not an idle
system - **it is more than half the authored content.**


- **X3** **Rebalance toward the undeniable.** 56 of 120 act slots (47%) are
  whisper, caption or sound; the acts that cannot be missed - vanish, fall,
  scatter, fault - are **7 of 120, under 6%**. Do not delete whispers; require
  that **every rung-3 and rung-4 entry contains at least one physical act.** A
  reenactment made of sound is a radio play.
- **X4** **Trim 18 ladders to 8.** `PoltergeistLibrary` serves a cast that was
  cut two-thirds away: §IV.1 ruled six cases plus Rhea and Nadia as sanctioned
  expansion, and under §III.1 the Tenant attaches to a CASE - so ten ladders,
  **40 act slots**, belong to residents who cannot be haunted. **Archive, do
  not delete**: it is good writing and two are already the expansion.
- **X5** `appliance_fit` is implemented and unreachable from any ladder. Wire
  it or cut it.
- **X6** Left alone deliberately: `DomesticWitnessSystem` and
  `BuildingPersonalityDirector` both looked like trim candidates and neither is.
  The witness clocks are per-apartment character objects and the personality
  director is what stops this being a random-number generator.

## N — Installed dream content

Historical completed **N3/N6–N13** notes are archived, not deleted from the game.
The future murder-year campaign uses maintenance and dream material as optional
investigations; it has no mandatory repeating repair/narcolepsy sequence. Current
V2 route/save qualification and protected conversations remain unchanged. New
defects in installed content still enter **K4/I/H** from actual evidence.
See Bible §VIII.5.o and `design/THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md`.

- **N-V2-DREAM — Claude, Omni wc0265c4a2ba0 (Lily's ruling dream_v2_direction_20261116):** step1 merged PR331 (V2-derived ten-room vocabulary/hazard proportions). Step2 technical integration merged PR3366fcf52aed, including PR334 and Codex receiving corrections: actual campaign-day ScheduleDirector resolution (weekday/monthly/special/chance), derived room aliases, annual-wrap-safe prior date and available-date initial fallback. Final date7/0, selection491/0, Windowed rooms445/0, producer8/0, physical798/0 with reviewed frames; clean candidate0regressions/0waivers17protectedV2. Human play/art acceptance across all6subjects remains open. Next: step3 Inside the Cell (being's interior, reviewed with Lily by film); Past the Mist later, The Day He Never Sees for endgame. Preserve original failures and regenerate catalog with its generator, never by hand. Pursuit capture repair merged PR337ef2152234: current V2 native wall/floor staging, shadow-only check, campaign restoration and fail-closed verdict; rendered lamp pair inspected with empty stderr, two destination negatives exit1, candidate0regressions/17protected. Finite capture diagnostic only; original false PASS retained privately in dream_pursuit_receiving_20261117/. Evidence: private dream_her_day_codex_receiving_20261117/. PR340 frozen0fca82db0 returned to Claude by Codex: exact candidate board retains stale-surface FAIL despite0regressions; new perch payload355surfaces has0UV/tangent data and uses default triplanar/untextured sills. Correct actual dream physical intake and clean packet signature before merge; reverse doorway-climb coverage requested. No demonstrated waking player/pursuer regression. Private review dream_parkour_20261117/codex_review/FINDINGS.md; no root engine/new checkout.

## FA — Installed fauna, with new breadth deferred

- **FA-V2-GAPS — Retain repairs and acceptance gaps for installed creatures.**
  Preserve the native tentacle encounter, Tardi, microscopy, local autonomy and
  accepted contact/dissolution behavior. Use current family records and their
  stated limits; historical fauna contracts do not qualify all of V2.
  `design/CREATURE_MAIN_INTEGRATION_2026-10-26.md` is the integration baseline.

**FA3–FA4 / FA-V5 / CT-2**, related unbuilt **E13/E15–E17/DF/DT** breadth and new
families are deferred. As gameplay uses appear, vet them and add bounded work;
do not treat this as cancellation of installed ecology or approved future people.

## M — Current surface, device and creature gaps

- **M1** Supertiles and stable per-wall UV offsets. Explicitly **not** part of
  the plaster repair, which was fixed without them — an optional later
  anti-repetition enhancement, with a real VRAM cost to decide first.
- **M2** `family_mean_spread` is defined on the compiler side but has never run:
  one texture per material means no family to compare. If the planner ever emits
  texture variants, that gate is unexercised.
- **M3** Compiler textures are 128² at roughly 64 px/m, which is the deeper
  reason features come out large relative to the tile.

- **M-V2-TENTACLE-GAPS — Reconcile TB1–TB16 and DT3/DT4 against the installed
  native family and newer owner briefs.** Keep only remaining anatomy, ocular/
  crystal details, attachment, deformation, surface, collision and rendering
  acceptance gaps; do not restart completed cage/rig/bake construction. Compare
  earlier requirements rather than silently mark them all done. Source:
  `design/DREAM_TENTACLE_BLENDER_BUILD.md`, `design/HERO_TENTACLE_REMAINING.md`,
  `design/TENTACLE_GANG_SURFACE_COMPLETION_2026-10-26.md` and the PR63 baseline.
- **M-V2-ORGAN-GAPS — One installed field/organ/lifecycle gap list for DF/DO/LC.**
  Preserve signal-specific answers, local autonomy, field/optical occlusion,
  withdrawal/residue, stage handoff and save/case truth boundaries. Reconcile
  **DO3/LC6** residuals with completed substeps; defer unbuilt breadth unless a
  vetted gameplay use needs it. Historical scripts, packets and receipts remain.
- **M-V2-MICROSCOPY-GAPS — Track only current installed-family acceptance and
  repair limits.** The completed **MBIO1–MBIO6** construction journal is archived;
  use `design/V2_TARDIGRADE_MICROSCOPY_2026-10-25.md`, current Tardi records and
  `design/CREATURE_MAIN_INTEGRATION_2026-10-26.md`. The external impossible-organ candidate remains INERT/research-only: review is not authorization to install or alter the established friendly prologue specimen. October30 research intake: [paired diagnostic review](C:/ov/asset-prototypes/tardi-impossible-organ-20261028/diagnostic_review/REVIEW.html) and [limits](C:/ov/asset-prototypes/tardi-impossible-organ-20261028/diagnostic_review/DIAGNOSTIC_NOTES.md) expose cavity depth but still read as ordinary pockets/neck/chamber; they do not establish impossible space or continuous topology change. Those historical framing proxies are not current installed-camera evidence. Reported replacement totals21,312–21,464 inspection /5,276–5,316 normal exceed both production ceilings; GPU wall/mineral attachment, deformation and tangent handling remain unresolved. No integration or runtime acceptance follows from these external previews. Do not repeat accepted anatomy
  and field construction just because its historical checklist is long.
- **TL-GAPS — Finish the current autonomous companion, physical paper/keyboard,
  controls, sound, lamp and readable presentation against their actual owners.**
  November 25, Codex, PR #582. Compact crown, exposed current date and capacitor,
  and five-line companion text passed the installed walking, reading, typing and prologue checks. Lily’s visual review is open.
  October28 refit: approximately phone-sized, close to the face, contextual right
  third framing; flight-path body language with puttering/weaving and effortful
  upright correction, steady for reading/typing. Recheck native proportions,
  arm fit, mirror scale, lamp alignment and actual input. Direction and current
  limits: `design/V2_COMPANION_TERMINAL_2026-10-24.md`.
  Reconcile legacy **TL2–TL5** mechanism/material/wear/tactility goals rather than
  rebuild the retired handheld shell or restore ink/heat instructions. Preserve
  protected typing drafts, pause, power, memory and validated campaign state.
  Source: `design/V2_COMPANION_PHOSPHOR_2026-10-25.md` and companion integration
  records. **TL6–TL9** (RETURN, reality inspection, impossible correspondence and
  creature recognition) remain unresolved narrative capabilities for explicit
  story-fit reconciliation, not silently completed or cancelled features.
- **TL-VOCAL — Give the companion a learned synthetic speaking voice.** Owner
  direction2026-10-29: begin with Speak & Spell-inspired babble and original
  16-bit game-inspired laughs, crying, emotive whines and other reactions;
  indirectly acquire English through interaction, mimicking any word it hears.
  Preserve articulate physical-printer dialogue and existing narrative/input
  owners. Learn from actual witnessed utterances, never future/offscreen text
  or the companion's own babble; persist learning through validated campaign
  storage. Use existing voice-volume control, bounded playback and cooldowns;
  do not silently enable a microphone. First complete the current crossing
  repair, then integrate and audition this voice. The crossing checkpoint is now
  pushed. Own nonlexical prologue playback is now implemented and technically exercised; learned English and recorded-reaction integration remain open. External October29 sound
  research and 19 source-supported finalist recordings are in
  **C:/ov/reports/companion_sound_research_20261029/**; [report/ranked ten](C:/ov/reports/companion_sound_research_20261029/REPORT.md), [32-item rights register](C:/ov/reports/companion_sound_research_20261029/CANDIDATES.csv) and [labelled69.875-second audition reel](C:/ov/reports/companion_sound_research_20261029/AUDITION_REEL.mp4) are delivered. Original hashes/decoding were verified; listening review was NOT performed. Audition, item-specific
  rights recheck and contextual assignments remain open, with uncertain archival
  clips held out and the attribution-required alternative separate. Recorded reactions are a separate proposed output channel from learned speech: never learn English or story facts from the companion's own recordings. Cooldowns/event assignments in the report are proposals; preserve protected conversations, readable paper, the exact final communicated prologue line and the quiet17-second Tardi ending. The original synthetic sketch is also unaccepted. No blanket
  legal clearance or artistic approval is implied.
  October30 own-voice research is ingested at
  **C:/ov/reports/friendly_mechanical_voice_research_20261030/**:
  **RESEARCH_BRIEF.md**, twelve original designs in **VOICE_GESTURES.csv** and
  **SOURCE_REGISTER.csv**. Owner selected original friendly LPC-style voice on2026-10-30: rounded180Hz body,8kHz ten-order all-pole core,25ms parameter targets,reconstructed48kHz; careful pauses,soft endings and self-directed correction persist as English improves. Four external audition packets are delivered (comparison,babble,learning,sentences); see the prologue ledger intake for exact paths. Start with a small offline-rendered original WAV gesture set through existing AudioPolicy/Voice ownership; do not ship Python authoring tools or audition reels. Three original prologue WAV gestures now use existing AudioPolicy/Dialogue ownership; occupied first-contact21/0,validated-reload fixture22/0 and policy52/0 pass. Final merged-tree116-gate comparison has zero regressions and unchanged17 protected paths/requirement states; full mix/listening remains open. No learned-English renderer is installed yet. Keep pronunciation,
  heard-word provenance, semantic knowledge and current speaking permission
  separate; exclude own speech, recordings, echoes and audition playback at
  source. The proposed offline listening sheet remains separate from arbitrary
  learned-word synthesis and validated persistence. No prologue timing changes.
- **MX3/MX4 — Retain actual material-ingest and rollout gaps.** Verify calibrated
  height/relief, tile scale, ORM/detail/mask authoring and still-unaccepted classes
  against the installed pipeline. Recheck old missing-map/42-height assertions;
  do not blindly repeat old triplanar rollout, disable PBR or restore obsolete
  Compatibility budgets. Archived MX specifications and the material catalogue
  remain the reference, not another current-state claim.
- **MP/DP — Keep surface quality and loaded-mipmap verification active.** Preserve
  close-up detail, material scale/grain, UVs, normal calibration, optical glass,
  side-correct moisture and loaded texture requirements. Use
  `design/V2_SURFACE_REQUIREMENTS_2026-10-11.md` and actual same-settings renders.
  Old floor-repetition, glass-map and translucent-plane journals are references;
  archive disproved premises and promote only still-reproduced defects.
- **T4-4 — Preserve the temporal-evidence gate for future organ/anachronism work.**
  Record observation → misreading → embodiment, runtime owner and case/save/time
  boundaries. Future forensic time travel does not silently transfer authority
  to a visual effect or license arbitrary future props.

Completed **MC-P/LF/DT/DO/LC/MBIO/T4/CT/MX** clauses are archived with their
source/evidence pointers. Both contradictory **CT-1** queue entries are retired
as a historical atlas-status duplicate, not renewed V2 artistic acceptance.
Standing material specifications remain in the Bible, catalogue and surface
requirements; this queue is for outstanding work.

## EN — Encroachment presentation

- **EN1 — Owner appearance review remains open.** Historical frame delivery is
  not human acceptance. Compare the actual installed layer/portal/fold behavior
  and any still-live artistic concerns before preparing another bounded review.
  Source: `design/DREAM_ENCROACHMENT_BRIEF.md` and the original EN records.

Completed **EN1b/EN3/WK1** and completed portions of **EN2** are archived. Retain
any still-reproduced portal-camera, fold placement or ornament/performance issue
under the current installed-family gap audit; old timing numbers are not targets.

## C — Cast (ruled 2026-08-10, ORISON_BIBLE §IV.1)

Six residents carry cases: Mina, Peter, Juno, Cal, Omar, Mae. Rhea and Nadia
are the sanctioned expansion. The other twelve are case-less, **not absent** —
they keep their door, schedule, mailbox and place in the web.

- **C1** ~~Six bespoke case minigames.~~ **Superseded 2026-08-10:** the target
  is a mechanism, not a minigame — see `design/PROP_ACTIVITIES.md` §2. Cases
  express through objects you handle, not through bespoke rules modules. What
  each of the six cases *does* still needs deciding, but it is hours each rather
  than days.
- **C2** Per-resident data is built for 3–5 of the cast on most axes (hero
  models 5, life profiles 3, decor 3, wall art 3). Only animation profiles are
  complete at 18. Decide whether the case six get finished first.
- **C3** The twelve case-less residents need a defined minimum presence — door,
  light, schedule, signature sound, mailbox — so "case-less" reads as a person
  without a chapter rather than an unfinished resident.

- **C4 — Future harpy and succubus/oni characters with in-world cultures.**
  Preserve the rigged originals and walk libraries in `art/source/held_characters/`.
  Vet actual gameplay uses and develop the cultures/roles before adding runtime
  characters; today's eighteen-resident roster stays unchanged. The earlier U2
  assumption that these were disposable non-cast assets is superseded.

- **C5 — Lily/Stacy installed review: human play and artistic acceptance remain open.** PR239 merged `fabaae847`/verified source`98a50809c`: imported component128/0, MPFB98/0, scalar-release27/0, rendered Harukiya56/0, clean122-gate candidate zero regressions/protected17/17. Technical intake complete; four frames reviewed with explicit shadow/clump/cropping limits. Preserve original failures and source-bound proof in `polish_01/`; this is not whole-V2/audio/save qualification.
- **C7 — Full-cast intake, Omni w0dd8e4436993, technically qualified.** PR248 merged the tools and PR249 installed cast_r16. Mina reproduces all 14 frozen geometry payloads, including spectacles. Loaded body/top/hat UVs match across 23 channels, and both tested outfits have full mips on 39 distinct textures. All 20 bodies and 250 wardrobe components pass tangent checks, with Vulkan wardrobe 1053/0 and clips 43/0. [Qualification and limitations](C:/ov/reports/cast_qualification_20261118/REVIEW.md). Resident rollout, individual hair polish and seated drapes retain their separate orders (w9189b10b24ac, w02f78aa6af18, w39b8516474ec).

## L — Light and decay

- **L1** Bulb burnout and renewal (`design/PROP_ACTIVITIES.md` §4). The
  mechanism is small; the design is the three fixture classes — yours, theirs,
  and the ones that never come back on — and a rate set slightly faster than a
  shift can clear.
- **L2** Bulbs onto the bodega shelf beside the valves, sharing the studio
  chore's errand. One trip, two reasons.
- **L3** Let the infection blow bulbs, so the permanent dark follows the active
  case rather than being tuned by hand.
- **L4** Check `LightRig`'s per-storey budget against fixtures going dark. Should
  be performance-positive, but it was written when the cap was 16 and wants
  re-reading rather than assuming.

## U — Unused and dead systems

From `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` (AUDIT 2, run 2026-08-10). **That
document is the evidence — method, confidence, negative controls. This is the
queue.** Both P0s in it are already repaired: the monitor/signal-terminal split,
and the four isolated roof fixtures now terminating at a real riser.

- **U1** `B1_ROOM0_DOOR` is built data no runtime path reads — a control that
  silently controls nothing. **Owner fiction ruling required:** make
  `Room0.setup()` consume it as the threshold anchor, or remove it at the
  generator and state that Room 0 has no basement entrance. *The audit is
  explicit that deletion must not be chosen silently.* The dream brief does not
  need it either way: that entrance is not physical.


## PRIORITY — OWNER RULING 2026-08-16

> **"Don't stress mobile stuff right now, let's make a working game
> first."**

Standing until reversed, and it re-sorts several open items:

- **Mobile is deprioritised, not abandoned.** L12 (the unmeasured mobile
  light budget) stops being a blocker and becomes a note. `light_rig.gd`
  keeps `ACTIVE_N_MOBILE` and its rationing — nothing is ripped out —
  but no decision waits on a phone any more.
- **Desktop-only trades are now takeable.** The first consequence landed
  immediately: the shadow atlas was refused at 16384 earlier the same day
  *solely* because it costs 1024 MB of VRAM against an unmeasured mobile
  budget. With that objection withdrawn it is taken — free in frame time,
  and it doubles every shadow's linear resolution while giving the caster
  budget real headroom. `project.godot` carries the reasoning and the way
  back (`atlas_16_bits=true` halves it to 512 MB).
- **Completeness beats polish.** Work that makes a shift playable
  end-to-end outranks work that makes an existing room better. In
  practice that puts **N7** — Mina's hazards, the run cap, the three wake
  outcomes — ahead of the Harukiya's remaining phases and ahead of the
  rest of the P8 sweep.
- **When mobile returns**, the first three things to re-measure are the
  atlas, `ACTIVE_N_MOBILE`, and every "measured" claim in the docs that
  was actually an argument (see L12).

## P — Current measured V2 performance

- **P1 — Follow K-V2-FIRST-VIEW-HITCH with current occupied-world evidence.**
  Separate scripts, physics, loading/streaming, shader compilation, render
  submission, shadows and private-viewport costs; retain cold/warm distributions
  and actual input. New city work must measure its incremental cost on the same
  route/settings and preserve visual detail through measured tradeoffs.
  PR521 removed five overlapping service lights on F01–F03. Its stationary F03
  sample moved from 57.1 to 55.3 ms median. PR525 pauses the dream margin off
  its floor and caps physics catch-up at two steps per frame. Save, loop and
  surface qualification passed. The unmatched 329 s versus 112 s reload needs
  a controlled comparison under Claude's open 30 fps order.
  [Current handoff and receipts](HANDOFF.md#orison-stairs-and-frame-pacing---november-24).
  October28 frame-linked passage attribution isolates atomic fitting calls up
  to37.446ms despite the8ms cooperative budget; split/reduce that work without
  relaxing source/collision validation. See the dated section in
  `design/V2_COOPERATIVE_NATIVE_FITTING_2026-10-23.md`; probes are not a repair.
- **P2/P3/P6/P8 — Historical leads, not automatic prescriptions.** Reproduce
  relevant occlusion, shadow, mirror/reflection and tier/culling issues in the
  current V2 composition before optimizing. Keep any reproduced defects active;
  archive old V1 station numbers, rejected fixes and superseded budget levers.

The next release is desktop-only. **L12** and mobile parts of **P1/P4** are not
near-term delivery gates; existing export/source configurations remain until
deliberate cleanup. Explicit V1 rollback/protected paths remain intact.
Measured repair history: `design/V2_BACKGROUND_HOUSEHOLD_SAVES_2026-10-23.md`.
Performance/counter procedure: `.agents/skills/godot-development/SKILL.md`.


- **P-BODY-MESH-LOD — Implement authored body-mesh switching alongside detail
  omission.** Design: `design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md` §9. After the
  current cleanup/measurement checkpoint, pilot one measured traffic stock:
  optional versioned visual schema, true near/mid/far body mesh sets, Blender
  export/validation, projected-size selection with hysteresis, bounded MultiMesh
  migration and ready fallback. Preserve existing gameplay/part/save owners,
  native index LOD, critter budgets and relevant mirror/telescope/inspection
  detail. Compare cold/warm same-settings frame distributions, draws, triangles,
  shadows and memory; inspect actual rendered transitions and affected input,
  then qualify the candidate. Roll out only where measured benefits justify it.
  City elevation/street/transport/gaslamp families already have scoped authored
  replacement bodies; this traffic-schema rollout remains unimplemented.
  Current city native review: office HORIZON_FAR_3_0_P1 lower geometry removes
  only320of96344triangles(0.33%); it and the largest base body are already in
  the queued9profile measurement. Review actual cost/transition evidence before
  any further authoring; counts alone are not a speedup or reason to simplify.
  Reuse
  the completed INERT Model A stock study (29,662/12,378/7,600 triangles) after
  its imported/motion/cost checks rather than rebuilding it. The demonstrated
  retained-tank automatic-tail collapse is repaired by holding original bodies;
  complete authored tank replacements remain a measured follow-up.
  Before further city geometry beyond the next isolated five-body cohort, shard
  complete city-body exports/loader ownership by block: the architect reports a
  99,958,788-byte near GLB. Preserve whole-body replacement LOD, runtime material
  and source bindings, pane/roof/support controls and access. Its publication
  ceiling changed95-to100MiB; retain the original refusal and do not raise it
  again. File-limit compliance is not a measured frame-time or memory budget.
  **QUEUED: traffic integration and family rollout are not runtime acceptance.**

## I — Prop and set interaction review / the service wire

Owner ruling 2026-08-15; design contract in `design/PROP_ACTIVITIES.md`,
“THE SERVICE WIRE ANSWERS BACK.” This is a deliberate production pass, not a
license to add collision and popups to every wall panel. It enters the queue
after the currently sequenced dream work unless the owner explicitly promotes
it.

- **I4 — Complete the physical response pass.** For every matrix row not marked
  ambient, make E answer appropriately. OPERATE receives a reversible mechanism
  and authored click/clunk/scrape/hum; INSPECT receives a restrained close-look
  or material/audio acknowledgment; RESIST-REFUSE receives a visible/audible
  attempted action and specific reason. Preserve existing authoritative owners:
  the presenter may read refrigerator state, for example, but never open the
  door itself. No silent prompt, silent failure or generic animation pasted
  across unrelated mechanisms.
  - **LANDED 2026-08-15:** the first dishonest-silence batch now answers
    (F03 utility latch, chained Passage carts, busy toaster and jobless HARDWARE
    PAINT counter). The laundry batch follows the actual machine: five separate
    washer controls plus the airer cleat and a non-operating rinse inspection.
    All five task lamps now have a local key that the central LightRig cannot
    turn back on or charge against the active-light budget while open.
    All five line-fed picture receivers now operate their tuning knob while
    preserving the case-bearing signal instead of offering a false power cut.
    All 24 baked close-coupled closets regain one record-aligned cistern handle,
    one water cycle and truthful FULL/REFILLING copy without duplicating the
    porcelain floor geometry.
    All five baked valve radios regain a local knob, click, quiet programme bed
    and reversible power condition; case-anomaly props remain separate owners.
    All 21 wardrobes now own their actual paired doors at runtime. The rebuilt
    floor glTFs contain a hollow cabinet, rail and non-loot resident garments,
    but no duplicate baked leaves; E opens/closes both textured leaves with a
    creak and resident-private copy. The closed/open production pair lives in
    `art/renders/wardrobe_split_i4/`.
    The Harukiya jukebox now has separate selection-bank and coin-return ray
    owners, moving controls, sign response and a local spatial pickup cycling
    three shipped bar records. Its return stops only the cabinet; it never
    borrows the unlocatable WORS emitter.
    All 18 case-driven domestic clocks now own a neutral close inspection:
    the glass answers with a local tick and movement, while owner-result copy
    reports only visible live/disturbed condition and never prints a resident,
    case id, tell or solution. The lobby notice board and original Orison
    broadside likewise own one assembly-level target each, with a pinned-sheet
    or brass-fastener response instead of child collisions over every notice.
    The maintenance headquarters case wall now has one exact wall-sized target,
    a brass acknowledgement and live residue count; its slip explicitly says
    REVIEW ONLY and cannot advance an order or duplicate RealityCases state.
    All 19 possessed domestic mechanisms now answer through the same owner that
    stages and restores their case movement. Sixteen distinct physical kinds
    share no generic copy: each has a researched mechanism fact, source ids and
    a local material response. Returned condition is limited to AT REST or
    VISIBLY ALTERED; case ids, resident names, tells and causes are excluded.
    Case authority cancels any restrained handling motion before applying its
    own tell, so inspection introduces neither a second truth store nor a
    competing animation owner.
    The front directory's existing assembly owner now depresses one real call
    button, rings on every press and distinguishes SOUNDED from STILL RINGING
    without choosing a resident or inventing call state. The Vantry reference
    clock answers through its actual sealed setting cover: a metal rattle and
    sourced line-clock condition, never a false winding or adjustment verb.
    All 14 baked loose-paper stacks and eight pinboards now have one exact
    record-aligned inspection owner. One paper corner lifts or one tack presses;
    no sheet/card receives its own collider. A closed 22-id table reconciles
    every generated record, including the bodega and Harukiya papers, to
    clue-safe visible category and authority copy. It never reads Mina/case
    state or prints paper contents. Period copy now cites William M. Kelly's
    1914 paper fastener and the Gillespies' 1921 thumb-tack tool directly rather
    than borrowing apartment-mailbox provenance.
    Mina's six case-specific targets now answer through their authoritative
    callbacks: the wrapper performs a distinct card, book, pencil, calibrator,
    time-clock or letter touch, calls the existing action exactly once and
    forwards only its result dictionary. Mina still owns every caption,
    calibration, visit and resolution transition. The unavailable letter keeps
    no prompt and no collision until recurrence enables it. Five direct period
    patents source the object facts; no presenter or wrapper gained a case flag.
    All eleven Vantry Arcade storefront signs now own one fascia-sized ray
    target, never a collision per word or glyph. Inspection gives the fixed
    assembly a brief enamel-lettering glint and a local tap. Shop name and
    trade remain generator facts; OPEN/CLOSED/NIGHT SERVICE and LIT/DARK are
    read through `PassageHoursDirector`'s public presentation boundary, so the
    sign neither copies the schedule rule nor invents stock, prices or economy.
    The ORISON blade, DRUGS wall cabinet and HARUKIYA stage neon now each own
    one reachable service inspection. The tall blade's target is its actual
    low transformer box; wall forms use one bounded frontage target, never
    glyph collisions. Copy reports live/dark glass, visible dead/dropout runs
    and transformer condition from the sign owner. Inspection is read-only and
    cannot compete with business-hours or Conductor control of the circuit.
    The remaining three hero sign owners now answer at assembly scale. HALF
    BAKED uses one valance plane and reports its real fluorescent dropout plus
    authored 24-hour condition; Harukiya uses its low arrow as the service
    point while its card follows the existing OPEN / AFTER HOURS / CLOSED
    director; the Orison identity plaque has an exact bronze-face target kept
    physically distinct from the landmark door. Each gives a material-local
    tap, one R028-sourced slip, and no letter, bulb, screw or kanji child owns E.
    The entrance marquee likewise answers as one assembly: a shallow look-plane
    sits proud of the outboard fascia at a standing angle, rather than putting
    collisions on glazing, fittings, letters or cresting. Its iron tap and
    R028 card report the rain-shedding prismatic tray, seated returns/tie rods
    and fixed two-lamp/fascia-wash arrangement without adding a light switch.
    Roof service now respects its existing endpoints. Each of the four central
    ventilators refuses at its named belt guard with a casing rattle, live/idle
    automatic-cycle state and an isolation requirement; E never starts or
    stops the motor, and rotors/rain caps remain ambient. Each of the five
    C-stack chimney breasts answers only at its removable iron thimble, reports
    sealed plaster/rings/resonance, and leaves both masonry and the
    Conductor-owned three-millimetre knock pose untouched. R037/R039 source the
    two families and production rays prove all nine authored endpoints.
    `ServiceWireResponseTest.tscn` is the focused proof. I4 remains open.
- **I5 — Set-piece coverage.** Audit the eleven Passage shops, lobby/service
  desk, basement plant and laundry, representative apartments, roof, street
  furniture and the service set in hand. Give foreground ledgers, counters,
  crates, repair plates, machines and hero dressing an inspect/refusal contract
  where movement would be dishonest. Repeated architecture, inaccessible trim,
  rain dressing and bulk shelf stock stay ambient and must be explicitly counted
  as such rather than quietly omitted.
- **I6 — Deterministic proof gate.** Add a production-scene audit that fails on
  any registered E target without a valid card, any non-ambient matrix row with
  no reachable collision owner, any OPERATE row with no observable before/after
  state, or any RESIST-REFUSE row that returns silently. Prove all 18 fridges
  open and close, seating still releases on the second E, gameplay-bearing props
  preserve their existing transitions, and saved state reconstructs the correct
  condition line. The audit prints coverage by class and by zone with zero
  unattributed foreground heroes.
- **I7 — Render, usability and performance gate.** Produce paired captures in a
  kitchen, Passage shop, lobby, basement and street at 16:9, ultrawide and touch
  scale, including rapid interaction replacement and a long localized line.
  Prove the card never obscures the crosshair/interaction target or protected UI.
  The content library and areas add no per-frame prop callbacks; profile the
  presenter closed, visible and rapidly replaced. Run one Godot at a time under
  60 seconds: focused interaction audit, service-set test, maintenance counter,
  relevant case tests and WalkTest FULL x8/480. Document and commit the matrix,
  research ledger, data, code, captures and exact result before closing I.

## SR — The Orison Service Round

Owner direction and architecture: `design/ORISON_SERVICE_ROUND_BRIEF.md`.
Target mix over rolling active play is 1:1:1 hands-on maintenance, people /
travel / search, and observing / avoiding / eventually communicating with the
Dream organism. M1's shared activity contract and live radiator consumer are
proved at `art/renders/maintenance_service_round_m1/README.md`.


**SR6/SR7 — Deferred after V2:** retain the rolling attention ledger and
vertical-anatomy expansion briefs, but finish current route, maintenance,
accessibility and reload repairs first. Existing authorities stay installed.

## H — Housekeeping




- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
  - **H13-PRESENTATION — LIVE PRESENTATION AUDIT (INSTRUMENT BUILT AND FIRST RUN 2026-08-21; GENERATOR FIXES STILL WAIT).** `res://tests/PresentationAudit.tscn` boots production `BuildingRoot` with WalkTest's discipline and runs seven passes: live cross-class AABBs with an assembly whitelist (25 leads), authored-base support rays (16; every kitchen toaster base 215 mm inside the furniture hull), WalkTest's `[ART]` sweep verbatim, dressing-per-m² census with bottom decile (five zero-record rooms; 2D's bedroom), 1.4 m wall rays (5,783 rays, 0 see-through — lead closed), height-classified ceiling rays with the real `show_all_floors` toggle (the corridor 22% is the atrium light well plus one stray point per floor), and a windowed eight-station OrbitSweep (granted set direction-blind; 0/288 frames dropped a centre-in-view light — the "lights disappear with direction" lead is not gating, churn or culling). The 183-still harness rerun wrote 182 frames. Rows are in `design/walkthrough_punchlist.md` under 2026-08-21; proof, JSON and CSV at `art/renders/presentation_audit_h13/README.md`. The first generator fix landed the same day: `_toaster_marker`'s yaw-rotated offset stood every generated kitchen's toaster on its dishrack; it is in the run frame now, `_validate_kitchen_worktops` guards it, only the ten toaster markers moved (no GLB rebuild), and the re-audit is toaster-clean (support faults 16 → 6). The roof ventilator V-B, which the garden pass had buried in the east bed, now stands on open roof south of it (marker move). 2D/5D's empty rooms are the building's own vacancy rules; the 6A monitor overlaps are the prop's cable mesh through a 50 mm desk top. Remaining leads (bar speakers/songbook mounting, 4B closet/vestibule dressing) are taste calls for the walk, not generator defects.
- **H22 — Trace remaining cross-script data reads.** The audit follows the
  source of all 26 darts questions and eight Otis floor names. Conditional
  reads still need review for individual entries. These include the darts
  blurb, the case-definition enabled flag and five fields handed to the
  witness clock during configuration. Getter aliases and
  other collaborator arguments remain open. [Earlier sample](design/REPO_HOUSEKEEPING_2026-09-19.md)
- **H23 — Optional waking-cell voxel-light presenter.** Verify that a lamp
  reaches the intended cell in an upper-floor apartment when the presenter
  is explicitly enabled. Preserve the ordinary waking-cell behavior. Use
  the [developer creature fixture](game/docs/v2_launch.md#creature-testing-in-a-debug-session)
  for isolated creature experiments. Its exhibits and reserved bays carry
  no V2 campaign or release requirements. [Original voxel-light failures](design/REPO_HOUSEKEEPING_2026-09-19.md)

- **H26 — V2 golden-shift evidence.** V1 removal retired GoldenLoopTest.
  The V2 repair, recurrence and Dream runs cover separate segments. Full
  eleven-beat coverage remains open. Record the uninterrupted player route
  under K2 and each save/quit/relaunch under K3. The [K2 timeline](art/renders/orison_v2/m10_golden_shift_v2_01/k2_timeline.json)
  has no observed beats and the [K3 matrix](art/renders/orison_v2/m10_golden_shift_v2_01/k3_boundary_matrix.json)
  has 0 of 11 verdicts. Keep the historical failures and scoped runtime contracts.

- **H-CODEBASE-SIZE — Codex, priority cleanup: make the repository manageable by reducing audited excess file count and size.** October30 non-destructive census finds69,554 tracked paths and472,520 files present/205.6GB logical file bytes under canonical,including nested worktrees,Gitobjects and caches; these are not all shipping files. Inventory tracked source,untracked/generated files,Godot caches,review/evidence artifacts and worktree copies separately; report counts/bytes by major directory without traversing reparse targets. Select bounded cleanup/consolidation batches using consumer and regeneration checks; prevent generated clutter returning through ignore/export policy where appropriate. Preserve editable/runtime assets,current acceptance packets,original failure evidence,saves,shared history and unmerged work; archive recoverable originals with indexed provenance before removal where needed. Verify affected imports/build/static consumers and record before/after counts and bytes. PR76–79 already consolidated25,740 plus4,878 source copies and retired734 historical images; do not repeat completed cleanup. No blanket deletion or branch/worktree removal. [Scope and recovery](design/AUDIT_UNUSED_SYSTEMS_REPORT.md#october-28--historical-evidence-storage-cleanup).



- **H-LOCAL-HANDOFF — Canonical Codex: finish app-owned temporary-baseline cleanup after this chat is handed back to Local.** Preserve codex/v2-prologue-20261028 and the clean baseline evidence; verify current app attachment, Git/index and reparse targets before archiving only the temporary v2-baseline worktree. The app previously refused archiving its calling chat's primary checkout; the owner's promised handoff is not proof it happened. Never remove other agents' worktrees/branches or bypass that refusal.

## Deferred after V2 — preserved scope, not current blockers

- **G1 shared side / G2 / G6a / community S5:** network song distribution after
  V2; keep local songs, found traces and immutable playback. Consent, moderation,
  report/block, takedown, retention and platform controls remain prerequisites if
  public/friends sharing is resumed. `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`.
- **G6 / related G8:** phrase-duel and lyric-book expansion after V2; retain the
  existing private music work. `design/ORISON_SONGBOOK_PHRASE_DUEL_BRIEF.md`.
- **G7:** defer the House Rig audition/decision; current sound and Music Bible
  authority remain. No added bass/distortion chain is silently approved.
- **A12:** future arcade redesign remains a commitment; the old cabinet-specific
  plan is cancelled. Do not restore cabinets ahead of that redesign.
- **E13 / E15–E17 / FA3–FA4 / FA-V5 / CT-2 / unbuilt DF/DT/LC breadth:** preserve
  current creatures; vet additional families as real gameplay uses appear. Keep
  explicit prerequisites and no new unchecked story/save/time authority.
- **SR6/SR7:** rolling attention and additional vertical anatomy are deferred;
  current route, maintenance and save repairs remain active above.

## Queue provenance and standing rules

October 27 owner decisions and exact pre-trim source references are in
`design/V2_TASK_RELEVANCE_REVIEW_2026-10-27.md`. Completed/superseded text is
recoverable from Git; original failures, receipts and assets are not erased.
The Bible, AGENTS.md, skills and existing references own standing rules. In
particular the deliberate pointer-release contract remains binding in
`design/REPO_HOUSEKEEPING_2026-09-19.md` §10; H24 was a rule, not unfinished work.
Funding, marketing and the fundable-release task are retired. Save reliability,
accessibility, responsive controls, visual quality and honest qualification remain.
