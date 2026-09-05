# Baseline runtime diagnosis and proposed red/green controls

Read-only preparation for ASTRA-SANITIZE-0. No Godot process was started and no product, test, runner, or save code was changed during this diagnostic task. Baseline runtime evidence refers to main `c2dc01771bc25b07f5dcf7a6040102345b8c57d5`; accepted M11B source was also inspected through Git at `a9e455bfede9f89193c9acd0796eb8fc5a0c3548` to avoid proposing duplicate audio APIs.

## Decisive findings

1. The M08F fresh-profile save failure is established: the harness selects `user://tests/m08f_runtime.json` without creating `user://tests`. A clean isolated APPDATA therefore returns exit 1 at the save/reconstruction check. The unchanged harness returns exit 0 after the presence-ledger suite creates that directory. Preserve both receipts; this is a test precondition defect, not evidence that ordinary production saves fail.
2. Four Ogg objects/two resources survive the M08F process even when all 29 checks pass. Verbose baseline output names `appliance_pop.ogg`, `OggPacketSequence`, `AudioStreamOggVorbis`, `AudioStreamPlaybackOggVorbis`, and `OggPacketSequencePlayback`. A cached clip and a live decoder are different owners. Cache clearing alone is already disproven as a sufficient repair by the existing M08F calls to `PropAudio.clear_cache()`.
3. The historical statement that this run leaked through "ServiceSet receipt playback" is not proved by the current source. M08F does not call `PlayerController._try_interact`, `_present_interaction_telegram`, or `ServiceSetProp.print_telegram_card`. Its explicit invalid signal does call `WatchRegisterProp._balk` and starts the register's `pop` emitter. The ServiceSet still holds another direct `AudioStreamPlayer` referencing that same shared clip, and lacks any teardown callback. The next instrument must distinguish these owners before landing a repair.
4. Contrary to historical prose about "in-test retention assertions", the current M08F test has no ObjectDB/resource/weak-reference retention assertion. Its final checks are production-layout hash and selector default. Its comment about a process-level retention assertion is not executable proof. Exit 0 therefore cannot close retention.

Evidence: `design/astra/evidence/base_runtime/receipt.json`, `m08f_runtime.stdout.log.stderr`, and `m08f_runtime_existing_test_directory.stdout.log[.stderr]`.

## Actual ownership graph

| Owner | What it owns | Verified teardown today | What it cannot prove |
| --- | --- | --- | --- |
| `ServiceSetProp` | Two direct 2D `AudioStreamPlayer` children, printer tick and feed; feed references `PropAudio.get_stream("pop")`; receipt tween; WorkOrders and global RealityState signal subscriptions | No `_exit_tree` and no public teardown in the current file | A live/retired direct player's decoder cannot be cleared by releasing an AudioPolicy slot. Receipt playback is not triggered by current M08F source. |
| `WatchRegisterProp` | A direct 3D `_click` emitter built through `FunctionalProp.make_emitter("pop")` | Inherits `FunctionalProp._exit_tree`, which stops child 3D emitters, detaches streams, and releases each matching cache entry | Need runtime isolation to establish whether the mixer has retired its playback when the sibling ServiceSet still holds the same clip. |
| `PropAudio` | Static dictionary of shared clip resources by sound key | `release_stream` erases only the matching key/resource; `clear_cache` empties the dictionary | Neither method stops a player, detaches its stream, or directly retires a decoder. A live player may legitimately keep the clip alive. |
| `AudioPolicy` | Separate pool of 16 `AudioStreamPlayer3D` nodes, semantic source-slot state and cooldowns | Main `stop_source` stops active matches but does not detach streams. Accepted M11A adds `release_source`, which also detaches ended streams, releases matching cache entries and clears source cooldowns | M08F's identified watch-register call is a direct emitter, not this pool. Do not rewrite or globally flush the pool without proving it retains the clip. |
| `OrisonV2RuntimeRoot` / anchor adapter | Mounted production prop lifetimes and semantic/acoustic attachment | `shutdown_for_tests` asks adapter to restore/unmount/free its consumers; root destruction frees player/ServiceSet subtree | Freeing a root is not a substitute for a direct audio owner's explicit stream lifecycle. |
| `CampaignShell` | Waking/dream world replacement | Current base replaces scenes; M11C2's alternate teardown is quarantined and is not required for this diagnosis | This defect does not authorize adopting M11C2 or changing geometry providers. |

Relevant source locations at the reviewed base:

- `game/scripts/device/service_set_prop.gd:96`: public printing; `:114` schedules feed after the 0.30-second paper motion; `:122` starts feed.
- `game/scripts/device/service_set_prop.gd:408`: active model constructs tick player; `:413` constructs feed player and `:415` assigns shared `pop` clip. The legacy builder repeats the same ownership at `:524`/`:529`, but the active `_ready` calls only `_build_model`.
- `game/scripts/device/service_set_carrier.gd:28`: carrier attaches to player's camera and owns device in its overlay subtree.
- `game/scripts/player/player_controller.gd:1115`: interaction telegram presentation is the only production caller discovered for the carrier's print operation.
- `game/tests/orison_v2_m08f_runtime_test.gd:52`: invalid station signal intentionally invokes the register refusal.
- `game/scripts/props/watch_register_prop.gd:137`, `:388`, `:488`: refusal, shared pop emitter creation, and `_click.play()`.
- `game/scripts/props/functional_prop.gd:224`: existing direct 3D stream cleanup; do not duplicate it in every prop.
- `game/scripts/audio/prop_audio.gd:105`, `:109`: cache-only cleanup.
- `game/scripts/audio/audio_policy.gd:205`: main active-only stop operation. Read the accepted M11A `release_source` before any pool change.
- `game/scripts/call/call_interface.gd`: existing `_exit_tree` is a useful local precedent: stop/detach each directly owned 2D player, release matching cache keys, disconnect Conductor, clear scene references.

Engine-internal decoder construction and mixer retirement timing have not been independently inspected here. A stream being assigned without a public `play()` call must not be assumed harmless or assumed to create a playback; the controls below establish the actual result on the installed engine.

## Minimal selective ownership experiment after sanitation

Run serially through the unchanged `tools/run_godot_serial.ps1`, with explicit isolated APPDATA and retained stdout/stderr. Use the accepted canonical source after M11B landing and record its exact hash. Keep every local fixture independent and do not suppress sound on production owners.

| Control | Public action and teardown | Discriminating result |
| --- | --- | --- |
| A: ServiceSet idle | Instantiate real `ServiceSetProp`, never print, then remove/free normally | Determines whether assignment/idle ownership alone produces surviving playback/resources. |
| B: register refusal | Instantiate real `WatchRegisterProp`; send invalid station 9; verify refusal and real sound started; remove/free through existing FunctionalProp cleanup | Tests the one pop playback statically proved in M08F. |
| C: shared clip | Instantiate register plus idle ServiceSet; perform B; teardown register first, then ServiceSet, matching root order | Determines whether the surviving direct player reference explains retention after cache entry release. |
| D: actual printing | Print through ServiceSet public method; wait until feed actually starts; interrupt at that boundary with owner teardown | Tests an important production lifecycle separately from the old M08F attribution. Include teardown before delayed feed callback and replacement during feed. |
| E: policy pool | Present a pop-backed semantic cue through `AudioPolicy.present_3d` with a unique test source; retire with accepted public `release_source` | Distinguishes pool teardown from direct-player teardown and checks the accepted M11A API without reaching into pooled node names. |
| F: cache-only reference | Load the pop resource with no players, release the cache reference and all fixture strong references | Establishes the difference between a deliberately warm clip cache and a retained playback. |

For A–F, capture weak references to scene owners, clip and playback only after dropping all diagnostic strong references. Do not keep a `stream` or `get_stream_playback()` result alive in the instrument itself. Record which expected control resources intentionally remain resident. Compare two complete cycles in one warmed process and inspect verbose process shutdown; a zero node count alone is insufficient. Read AudioPolicy public `event_history()` to attribute any pooled cue generated indirectly; do not conclude "no pool involvement" from textual call searches alone.

The first decisive comparison is C against the same fixture with ServiceSet-owned stop/detach/release applied at its lifecycle boundary. A fixture-only subclass can first demonstrate the proposed cleanup without changing production. This is diagnostic evidence, not final green proof. Only then land the same bounded owner repair and rerun the actual M08F composed path. Preserve the original failing fixture with the ownership cleanup intentionally omitted as the red case.

Do not make the gate green with global audio muting, skipping the refusal/print, extending arbitrary sleeps, clearing all global caches from every prop, deleting pooled nodes from the test, or copying quarantined CampaignShell code. Allow bounded audio-server retirement only after ownership has been released; state the boundary and observe resources rather than declaring a chosen delay sufficient.

## Proposed smallest repair, contingent on those controls

If A/C/D identify the ServiceSet boundary, add idempotent cleanup owned by `ServiceSetProp`: kill and clear the receipt tween before a callback can restart feed; stop both directly owned printer players; detach each stream; call existing `PropAudio.release_stream` with the exact tick/pop resource that owner held; clear owned player references; disconnect its live WorkOrders and RealityState subscriptions where connected; clear `_work_orders`. Invoke it from `_exit_tree`. Keep durable order facts, lamp/radio state semantics, and print presentation unchanged.

This should remain local to the direct owner. `ServiceSetCarrier` need not become an audio manager, `CampaignShell` need not reach into child audio nodes, and the accepted AudioPolicy pool API need not be repurposed for unpooled players. If B/E implicate other owners instead, revise the repair to that measured owner. The shared cache may retain other legitimately live players' references; releasing one matching cache entry must never stop another owner.

The regression contract is owner-based, not code-shaped: interrupt printing and scene replacement without a late feed, without retained owned decoder/stream/scene references, without disconnecting another live device, and without lost/doubled work-order facts. A two-device shared-clip case proves releasing one owner does not silence or destroy the other. Replaying once with cleanup omitted must fail. Final production checks include M08F, the genuine two-root CampaignShell matrix, a focused ServiceSet lifecycle fixture, and the accepted M11A audio-source lifecycle test. Run a windowed audible interruption check later; headless cleanup is not listening acceptance.

## Fresh-profile save-directory repair

The proven precondition gap is at `game/tests/orison_v2_m08f_runtime_test.gd:95–100`. `RealityState.save_game` opens the requested path at `game/scripts/game/reality_game_state.gd:116` and correctly reports write failure. Ordinary production saves target the application data root; this harness introduces the nested `tests` path.

After sanitation, make the M08F harness create its own test parent before enabling persistence or invoking any source that commits. Use `ProjectSettings.globalize_path` on that declared test directory, check `DirAccess.make_dir_recursive_absolute`'s return value, and fail clearly if setup is impossible. Use a test-local saved path and restore prior save path/persistence state as already intended. Do not change production save behavior solely to compensate for a missing fixture directory. Atomic save/readback/schema work remains separate release debt under the existing save contract.

Exact red/green control: allocate two never-before-used APPDATA subdirectories under Astra evidence. Run original source in the first with no precreated application/tests directory: retain exit 1 and the write warning. Run repaired harness in the second, also without precreation: require all 29 checks and actual save/read/reconstruction success. Confirm both directories stayed under the evidence root and no real profile path was accessed. Preserve both directories and logs; do not erase evidence to simulate freshness. Add a failed-directory setup control only if it can be created within the disposable evidence directory without touching user permissions.

The existing baseline red and unchanged-source rerun already establish the diagnosis. They do not prove a code repair has landed. Current result remains: no proposed repair implemented; M08F retention source requires the selective runtime experiment; fresh-profile test setup defect is established.


## Verified false claims in the M08F capture instrument

Classification: **RELEASE_CRITICAL instrument defect**, stable proposed ledger ID **ASTRA-EVIDENCE-M08F-CLAIMS**. Root identified this additional source contradiction; this reviewer independently read the full current capture script. No screenshot from this suite is admissible as save, teardown, denial, collision traversal, controller-completion, or actual player-camera proof. Existing files remain recoverable evidence of the capture's declared framing, not erased history.

`game/tests/orison_v2_m08f_runtime_shot.gd` instantiates the real V2 root, but disables its player camera and creates a new capture camera at lines 22–25. `_shot` directly assigns that camera's world position and aim at lines 82–83. Its informational strings and `save_phase` values are supplied as literal arguments. They are not observations of the corresponding runtime contract.

Specific unsupported statements:

- Frame 13 says `SAVE → DESTROY → CAMPAIGN RECONSTRUCT · SEMANTIC FACTS PRESERVED` while persistence was disabled at line 15. The capture performs no save, destroy, CampaignShell reconstruction, or semantic equality comparison before that frame.
- Frame 15 says `TEARDOWN OWNER · ADAPTER + PROP AUDIO · 0 RETAINED` before teardown occurs and without any retained-object/resource measurement. `_write_receipt` runs first; only then does it call shutdown, queue the world for deletion and immediately quit. There is no post-destruction frame/mix boundary or second cycle.
- Frame 14 says `DENIAL PROOF · PREMATURE ACTION CANNOT ADVANCE`, but this capture does not perform and assert the premature action at that point. It supplies `closed` as the caption's phase.
- Frame 08 says `B1 DESCENT · COLLISION-BEARING ROUTE`, but the capture teleports an independent camera between positions instead of traversing with PlayerController. The world contains collision; this does not prove the depicted descent is traversable.
- The banner formats every literal proof string through the controller prompt formatter. It does not prove controller-only play or a real interaction prompt.
- `_write_receipt` records `production_runtime: true` and a per-frame capture PASS, but no field binds or verifies those stronger claims. Real runtime composition is true at its narrow scope; the appended labels are not automatically true.

The runtime test's separate PASS cannot rescue these labels: it is not hash-linked as the source of the capture claim, its fresh-profile save precondition fails, and its shutdown currently retains the four Ogg objects/two resources. A static reference or matching milestone name is not an evidence chain.

Coherent correction after sanitation:

1. Preserve and mark the historical M08F packet **capture-only / unsupported contract labels**, with explicit excluded evidence tiers. Do not silently overwrite its imagery or promote its labels into the master ledger.
2. Make this scene an honest composition inspection capture. Remove save/teardown/denial/traversal assertions from banners and `save_phase` fields unless each is generated from a verified receipt for that exact frozen run. Label capture-camera views truthfully if retained. The immediate scope can be "production V2 authority inspection".
3. Put save/denial/teardown proof in a canonical runtime receipt generated after actual events, actual comparisons, completed teardown, bounded audio retirement and the final process result. Require source/config hashes and explicit failed checks; the receipt must remain non-PASS on any skipped or failed contract.
4. If this capture is retained as a traversal gate, route the real production PlayerController through collision-bearing movement and use its camera rather than direct station transforms. This is a larger authored proof; do not imply it is completed merely by renaming frames.
5. Keep capture-integrity PASS, runtime-contract PASS, shutdown-clean status and human visual acceptance as separate fields. Strong claims require their own linked passing evidence.

Required red proofs: a targeted save failure must prevent semantic-preservation PASS; a deliberately retained owned stream must prevent lifecycle PASS even with process exit 0; a failed or absent action must not produce denial PASS; a capture-camera station teleport must not satisfy collision traversal. A static fixture should also reject the current literal unsupported proof labels/receipt shape so the known false-green instrument demonstrably goes red before repair. Restore valid controls and verify green without baselining the defects.

This section adds no feature implementation. It narrows evidence admissibility immediately and proposes the bounded harness semantics correction for the first authorized post-sanitation baseline repair.
