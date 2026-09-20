# Title continuation and save recovery — 2026-09-05

The title now offers Continue for verified loaded/recovered saves, Begin for a missing campaign, and an explicit replacement choice for existing or protected save artifacts. GameBoot refuses invalid Continue and failed New before scene changes. Failed launch returns to a visible title with music, focus, actions, and a truthful save notice restored. A successful New followed by a scene-opening error offers Continue for that newly saved campaign. The title does not sample or invent the opening time. Ordinary player menus hide Debug Building; `ORISON_TITLE_DEBUG=1` exposes that existing developer action deliberately.

The styled replacement panel defaults to Keep This Save. Mouse shading, disabled menu actions, and explicit Tab/directional focus links contain the choice. It discloses archival preservation and the absence of archive restoration from this menu. Title notice ownership prevents a duplicate global overlay from covering the wordmark without clearing the authoritative protection latch; the global notice resumes after title retirement.

Root committed the final save/title production as `9548301873807117a870aeb6e517173e81a4713f`. No production bytes were changed by that commit. The primary final runs precede the commit at HEAD `716a64de3549155aba41e56f036cba7f3c46f7a7` with exact dirty-source copies; the two existing consumer regressions run afterward. The aggregate resolves each source from its copied raw bytes or the unchanged dependency's recorded Git blob. Cross-commit comparisons normalize CRLF to LF only, and current files also match every available anchor raw SHA256. It does not invent a before-run working-tree SHA for an unchanged committed file.

The machine index is `design/astra/evidence/title_save_recovery/receipt.json`; reproduction uses the adjacent `run_case.py`. Each case retains the actual serial-runner child exit, stdout/stderr, before/after diffs and source identity, elapsed process wall time, and fresh process-local APPDATA. No personal profile or runner-global tests directory was used. Profile contents remain excluded from the artifact manifest and named staging scope.

| Final case | Result | Process seconds | Retained diagnostics |
|---|---:|---:|---|
| Connected title handlers and real boot/storage gates | 123/123, exit 0 | 17.337 | None |
| Existing title regression | 0 failures, exit 0 | 0.982 | None |
| Existing title audio regression | 0 failures, exit 0 | 1.664 | None |
| Actual Continue into V1 CampaignShell | 5/5, exit 0 | 23.799 | Existing found-art wall-placement warning |
| Actual Continue into V2 CampaignShell | 5/5, exit 0 | 3.369 | None |
| Four-direction real root save/load/reconstruction | 30 checks, exit 0 | 92.851 | Deliberate invalid-selector warning and five existing found-art placement warnings |
| Final title state capture | 10 states/images, exit 0 | 12.295 | Vulkan loader/environment messages and RGB8 conversion warnings, itemized below |
| Existing OpenShiftSaveMatrix | 17/17, exit 0 | 1.699 | None |
| Existing M08F composed reconstruction | 29 checks, exit 0 | 2.640 | None |

All final runs retained unchanged runtime source throughout their process. Every root direction has both semantic preservation total 1 and exact-calendar total 1: V1→V1, V2→V2, V1→V2, and V2→V1. Each pair freezes campaign time explicitly, seeds November 10, 1928 at 23:59 plus 181.5 elapsed minutes, and checks the exact calendar epoch/start/elapsed through JSON save/load and the real destination root's clock binding: Sunday November 11 at 03:00:30. This supplies the calendar assertions absent from the earlier 26-check matrix.

The 123-handler test invokes actual connected button handlers, production title logic, GameBoot, and storage, intercepting only the final scene operation for deterministic failure controls. It covers cancellation with unchanged bytes, explicit New sampling once, loaded/protected write failures, stale primary rejection, modal focus actions, music restoration, notice ownership, and developer-action visibility. Actual Continue uses real scene change and a surviving observer to check both roots separately; those checks are distinct from the intercepted scene-failure tests. A failed first creation with an uncommitted temp and no verified primary never offers Continue. Before reload the retained missing state permits Begin retry; real reload protects the artifacts and requires explicit New.

Both preserved original-source controls compile and construct under the current storage API, then fail the intended two checks with exit 1: old loaded-title primary/New separation and old boot ignoring failed New/remaining in the leaving state. Exact originals and their manifest are under `legacy_sources`; only the disclosed final-scene adapter is applied by the control fixture. The new storage still preserves the original bytes in these controls, so they are not misrepresented as old-storage corruption proof. The initial capture timeout/parse error and earlier image corrections also remain in the aggregate with their original rulings.

All ten final PNGs were opened with `view_image`; see `title_save_recovery_visual_review.md` and the final capture's `visual_review.json`. At 1280×720 all ordinary actions, notices, and replacement choices are readable in the viewport. The final windowed capture retains five missing TikTok/Epic Vulkan manifest ERRORs, one registry warning, one duplicate OBS warning, and two RGB8-to-RGBA8 warnings. It has no script, scene-pairing, or object/resource-retention diagnostic. The final headless checks are clean except for the warnings explicitly listed above.

Scope remains engineering and agent composition inspection. This is not human acceptance, physical player traversal, audio listening quality, or release performance proof. Storage interruption/restart proof belongs to the separate authority-owned evidence; no power-loss durability or atomic Windows replacement claim is added here. Archive restoration remains outside this menu. Branch-forensics made no staging or commits and released the Godot lane after the two final consumer regressions.
