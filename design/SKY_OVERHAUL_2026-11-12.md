# Sky overhaul — November 12, 2026

Evidence class: **INERT**

This report records a scoped Forward+ Queens sky improvement. It grants no
gameplay ledger credit, human-play acceptance, or claim that every annual
configuration is artistically finished. Lily retains artistic acceptance.

## Change and reason

Ordinary Ac/Sc/Cu clouds had shallow shapes, a nearly uniform ambient floor and
visible bands at grazing angles. Their vertical noise now uses the horizontal
kilometre scale, cloud families remain coherent through height, and density
and filtered self-shadowing retain rounded relief and open sky between masses.
The ordinary march spends samples within occupied decks, skips their known
empty gap and caps grazing steps at 160 metres within its existing 160-iteration
limit and 24 km visible range. Fixed spatial stratification breaks the repeated
bands without a time-varying random phase. Horizon fading acts on optical depth
before Beer integration. Rare density formations retain their separate bounds.

Ci now uses continuous translucent ice packets with weak warped strand detail,
instead of sharp white blades. Cc retains small cloudlets with graded thickness,
soft feathered edges and shallow daytime core shading. Frequency changes are
matched in LivingSky's transport publisher, preserving physical wind velocity.
Existing mipmapped stock is reused; no new texture or external reference is added.
The campaign, weather calendar, provider consent, astronomy, Moon, event schedule,
save state, city fog and sole light/environment owners are unchanged.

## Evidence and rejected attempts

Evidence root: **C:/ov/reports/sky_overhaul_20261112/**. Raw reports retain source
hashes, effective weather values, engine receipts, logs and frames. Hidden-desktop
Godot 4.7.1 patched Vulkan/Forward+ captures use 3440 by 1440 pixels with TAA.

- The original baseline and all ten morphology attempts remain available.
  Family03 erased the overhead field; Ci07/08 made wire-like streaks. Those
  candidates were rejected. Cloudlets10 improves the visible field without
  flattening it into uniform overcast.
- Final optical matrix: twelve layer comparisons, four moving-camera dates,
  paused/seek/return controls, eight seasonal/night states and six dated events.
  Reports distinguish scripted camera movement from normal player input.
- Calendar diagnostic: 439 checks, zero failures. The service/calendar inputs
  are unchanged by the final cloudlet-only adjustment; reuse is explicit.
- The real PlayerController precipitation fixture passes 31 checks with moving
  camera/TAA, rain, snow, covered emission suppression and outdoor resumption.
  This isolated fixture does not prove save/reload or an occupied-world route.
- Roof01 preserves the missing city-greenery import and null-instance failure.
  Two serial imports repaired the absent cache. Roof02 passes all 46 checks,
  but residents obscure its images. The final optional optical capture raises
  only the camera four metres after the original input checks and restores it;
  its report discloses that camera placement. Residents and buildings stay drawn.
  Ten existing resident texture-UID fallback warnings are retained and relayed
  to the cast owner; they are not erased or presented as sky errors.
- Standalone compile03 lacked autoloads and failed on RealityState. The existing
  autoload-aware CompileChangedScripts fixture passes; the original failure stays.

## Final technical results

Implementation checkpoint **843a4cf90**. Cloudlets10: 12 views, zero failures.
Final matrix03: four moving-camera dates (28 frames), nine optical/temporal checks,
eight seasonal/night states and six event captures pass with empty stderr.
Roof03: 48 checks, zero failures, no script errors; four unobstructed city frames
reviewed. Ten preexisting resident texture-UID fallback warnings remain.
Calendar02 (439/0) and precipitation01 (31/0) retain their original receipts.
See **verification_review/FINAL_EVIDENCE_INDEX.json** for hashes and reuse limits,
**clean_baseline_board/board.json** for the clean 122-gate merge-base, and
**verification_02/verification.json** for the candidate result.
**MERGE_CUSTODY.json** records the actual candidate, merge and cleanup outcome.

Final all-layer bench median GPU times at the four dates are 4.407, 5.135, 7.548
and 4.720 ms. These are observations under variable machine activity, not evidence
of a speedup or the occupied game's frame-time budget.

The initial clean candidate stopped on one newly reported id-shaped environment
flag, ROOF_SKY_REVIEW. Its exact test-only manifest row is now registered with
the optical-camera rationale. Audit logic and all production records remain
unchanged; verification_01 is preserved as the original blocked result.

## Limits and next review

Stationary and sparse pan frames show no obvious long ghost trails, but cannot
exclude fast shimmer. Fine low-cloud grain and some horizon-aligned high-cloud
streaks remain. Lenticular banding and the halo case's flat sheet appearance
remain artistic limits. The annual catalogue, all seeds, telescope magnification,
full save reconstruction, first-use stalls and human play are not newly qualified.

The local precipitation probe exposes an existing cover limitation: entering
shelter hides the whole camera-centred particle volume, including weather seen
through an opening. Keep that and first-use attribution open in the precipitation
task; this change does not conceal it by weakening cover behavior.

Bench GPU timings are observations, not a full-world performance claim. Startup,
PNG encoding, import work and other machine activity are not steady frame cost.
Do not claim a speedup from unmatched wall-time averages.

All comparison images, original failures and provenance remain held for review.
No report artifact is released or purged in this closeout. Generated untracked
UIDs in the canonical checkout remain in place. A single temporary clean checkout
is used for static verification and archived afterward, without another import.
