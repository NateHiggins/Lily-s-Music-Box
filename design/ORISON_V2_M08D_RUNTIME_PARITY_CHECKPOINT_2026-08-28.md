# ORISON-V2-M08D — Two-root runtime parity checkpoint

Date: 2026-08-28  
Base: `5f1bd8eabfad171b723f3fe47d7c972965d62d9d`  
Selector default: **v1** (unchanged)

## Outcome

M08D closes the incomplete two-root instantiation/save proof and the M08C runtime teardown defect. It cannot close first-shift/service-round spatial parity without violating the explicit prohibition on inventing absent rooms or service anchors. The precise dependency is recorded below. Production cutover and M09 remain unauthorized.

## Retained-object analysis and repair

The smallest v2 runtime matrix reproduced exactly four retained ObjectDB instances and two resources. Godot `--verbose` identified the chain:

`CallInterface._murmur` → `AudioStreamPlayer` autoplay playback → `AudioStreamPlaybackOggVorbis` → `OggPacketSequencePlayback` → cached `AudioStreamOggVorbis` / `OggPacketSequence` for `line_murmur_loop.ogg`.

The terminal UI constructed and autoplayed the quiet line at scene startup. Removing the scene freed the node but left its decoder and the `PropAudio` static cache entry alive at process shutdown. The repair makes playback belong to the public terminal occupancy lifecycle: construction is silent, `enter()` starts the line, `leave()` stops it, and `_exit_tree()` stops/detaches all three owned streams, disconnects the global Conductor callable, clears world references, and releases only matching cache entries. Focused normal startup, forced adapter failure, selector reconstruction/scene replacement, and teardown now finish with **0 retained instances and 0 retained resources**.

## Authority census

| Authority | v1 | v2 production composition |
|---|---:|---:|
| PlayerController | 1 | 1 |
| WorkOrders / ObjectiveTracker / MaintenanceInventory | 1 each | 1 each |
| ServiceSetCarrier | 1 | 1 |
| CallInterface / VirusSoundDirector | 1 each | 1 each |
| ChirpHunt / MinaCaseGameplay / VantryPointNetwork | 1 each | 1 each |
| CoreLoopDirector / SafetyNet | 1 each | 1 each |
| F01 mail/porter/telephone/dumbwaiter implementations | 1 each | 1 each |
| FirstShiftDirector | 1 | 0 — blocked by missing physical owners |
| ServiceRoundDirector | 1 | 0 — blocked by missing 2B/B1 geometry and owners |

The matrix asserts single named route authorities on v1 and all currently composed first-slice authorities on v2. No test double or second lifecycle owner was added.

## Exact first-shift and service-round dependency

The production first shift has six durable ritual phases (`arrived`, `clocked_in`, `report_accepted`, `returned`, `filed`, `complete`) and eleven established presentation/action boundaries. Its physical F01 route requires:

- `F01_WATCHMAN_DETECTOR` (`WatchmanClockProp`)
- `F01_NIGHT_REGISTER` (`NightRegisterProp`)
- `F01_SIGNAL_REGISTER`
- `F01_TOUR_KEY_GUARD`

None is present in the accepted v2 schema. Adding a director alone would create an owner whose public route cannot run; calling its methods from a test would counterfeit the interaction proof.

The essential service round is irreducibly spatial and ordered:

1. Lena’s 2B call and threshold conversation;
2. `F02_B_RADIATOR_01` inspection;
3. `LobbyPorterBoard` comparison (present in v2);
4. `B1_BOILER_01` comparison;
5. return to `F02_B_RADIATOR_01` for repair;
6. return to Lena to close.

The accepted v2 first slice includes F01, 2A, 4B, and their connecting core. It contains neither apartment 2B nor B1. `F02_B_RADIATOR_01` and `B1_BOILER_01` are durable production job/acoustic identities, but no legitimate v2 spatial owners exist. They remain valid saved facts and run under v1; they cannot be spatially executed under v2. This is a **cutover-blocking missing-space dependency**, not an adapter defect.

## Genuine two-root matrix

The matrix resolves each scene exclusively through `BuildingRootSelector.scene_path()` and instantiates the actual production v1 root and production-composed v2 root. It no longer preloads v2 as selector proof.

| Direction | Result | Contract |
|---|---|---|
| v1 save → v1 CampaignShell reconstruction | PASS 1/1 | first-shift phase/report/filing, CoreLoop boundary and semantic bed identity preserved |
| v2 save → v2 CampaignShell reconstruction | PASS 1/1 | same semantic facts, explicit v2 root selected |
| v1 save → v2 CampaignShell reconstruction | PASS 1/1 | supported facts cross roots without raw coordinate assertion |
| v2 save → v1 rollback reconstruction | PASS 1/1 | supported facts survive rollback; v1 resolves its anonymous-bed fixture |

Focused total: **24/24** after adding first-interaction/performance gates. The independent save compatibility suite remains **14/14 PASS**, covering the repository’s current historical/current/future/corrupt/write-failure contract. The selector is not serialized. The anonymous `bed` lookup remains v1-only; v2 CoreLoop uses `F04_B_BEDSIDE_RETURN` through the adapter.

## Continuous route and behavior status

The M08A collision-bearing review-controller route and public F01/F02/F04 interaction suite remain valid. The M08D runtime root uses the real PlayerController and exposes the same public first-slice consumers. A complete requested production-controller transaction cannot be truthfully reported because its required first-shift desk owners and 2B/B1 service-round spaces are absent. M08D does not teleport, mutate internal stages, or substitute a duplicate authority.

## Regression and performance

- Orison v2 blockout milestone suite: PASS.
- Genuine two-root selector matrix: PASS, zero shutdown retention.
- Save compatibility: PASS 14/14.
- FirstShift custody/lifecycle focused behavior: PASS 9/9 under its existing harness.
- ServiceRound public lifecycle: PASS 13/13 under its existing mechanism harness.
- M08A integrated suite: PASS, including public F01/F02/F04 behavior, save reconstruction, continuous street-to-bedside collision route, byte stability, and teardown. Startup 12.629 ms; route 43,221.037 ms; 1,730 nodes / 423 collision objects.
- Production-layout SHA-256 remained unchanged in every completed matrix run.

The older FirstShiftCustody and MaintenanceServiceRound harnesses call `quit()` immediately after their last audible prop interaction and still print a four-object/two-resource decoder warning (`appliance_pop.ogg` and `mechanical_hum_loop.ogg`, respectively). Verbose traces identify AudioPolicy pooled playback, not either composed root. The genuine two-root matrix and M08A integrated scene perform explicit scene teardown and exit at 0/0. Modernizing those two legacy harness teardowns is test-only non-blocking debt; their warnings are not hidden or attributed to v2 runtime ownership.

| Measure | Result |
|---|---:|
| v1 cold root startup | 14,110.661 ms |
| v1 nodes / collision objects | 17,540 / 1,524 |
| v2 cold root startup | 155.478 ms |
| v2 composed initialization | 148.034 ms |
| v2 nodes / collision objects | 2,222 / 436 |
| v2 first F01 interaction prompt | 0.239 ms |
| v2 cold sampled CPU / physics | 0.729 / 236.796 ms |
| v1→v1 save / reconstruct | 0.396 / 12,304.153 ms |
| v2→v2 save / reconstruct | 0.353 / 151.414 ms |
| v1→v2 save / reconstruct | 0.441 / 153.337 ms |
| v2→v1 save / reconstruct | 0.369 / 12,485.848 ms |

Cold samples include construction/import and the preceding v1 teardown; the 236.796 ms physics monitor is therefore reported as cold work, not steady gameplay. The v2 composed initialization remains below the established 1,000 ms proportional startup gate. Warm M08A stations above remain below 16.67 ms. GPU timing is unavailable headlessly and is not inferred.

## Blocker disposition

| M08C blocker | M08D disposition |
|---|---|
| Matrix did not instantiate both roots | **CLOSED** |
| v2 lacked first-shift and service-round composition | **BLOCKING: missing authored F01 desk, 2B, and B1 spatial owners** |
| Four ObjectDB / two resource retention | **CLOSED: 0 / 0** |

## Recommendation

**DO NOT AUTHORIZE M09.** Authorize a spatial milestone that builds and accepts the existing F01 ritual desk identities plus 2B and B1 service route before requesting selector cutover. M08D must not invent that architecture under an acceptance-hardening assignment.
