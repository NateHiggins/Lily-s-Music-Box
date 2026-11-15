# Harukiya lighting pass — November 15

Evidence class: **INERT**

Lily requests repositioned/redesigned bar lights for ambiance and efficiency.
This is an implementation/review record, not runtime or artistic acceptance.
Bible Accords9/11/15 and the November12 Neo-Noir Neon1929 amendment govern it.
Motivated colored light, localized warm social pools, readable faces and usable
passage take precedence over a uniformly bright room. Coordinates are adaptations
to the current destination; they are not historical reconstruction claims.

The original occupied images show amber brick behind nearly silhouetted gallery
faces, broad picture-wall pools and relatively weak stage emphasis. A live player
lamp is present in those images; its hotspot must not be misattributed to a wall
fixture. That controller and its lamp preference remain unchanged.

## Implemented candidate

The original eighteen fixture IDs retain their circuit, hours, flicker and surge
owners. Nine shaded pools use a shadowed spot with restrained unshadowed spill
instead of their shadowed omni. The venue-local subclass forwards existing rig
range, attenuation, color, source size and shadow-opacity controls into the beam.
Other consumers of LightFixtureProp are unchanged. This costs an extra nonshadow
light per shaded fitting; the expected shadow-pass saving is not a measured gain.

The stage pair moves1.15m toward the audience, with native rods/plates exported
from the existing Blender builder. DECK2 moves from overlapping lower-east lounge
coverage to the gallery east wall; both native material parts/collision children
translate with the existing actor. The helper validates all pairs before mutation
and refuses duplicate application. No new fixture IDs or independent fill owner.

The final stage uses an audience-side warm piano key, cyan kit/counter endpoint
and restrained magenta room edge. The existing well lamp receives a ninth cone
toward the north seating row after occupied images exposed dark faces; this
last optical profile passes the controls and14view check in lighting_review_05.
The entrance accents and its unchanged navigation/minimum-light authority remain.

## Evidence and remaining work

Private case root: C:/ov/reports/harukiya_overhaul_20261112/.
- lighting_audit_01: existing-image/source review, code review and exact geometry
  comparison. Only two/35 exported destination parts change (LightSupports brass
  and metal); all other33 mesh payloads and navigation/seating data are identical.
- lighting_native_01: CPU native build and sampled standing clearance pass.
- lighting_review_01: owned queue canceled before any GPU stage for rig-control
  forwarding repair; no engine test ran and no failure was erased.
- lighting_review_02: native pass then import180s ceiling; compile/visual NOT_RUN.
  Original logs/receipt retained. lighting_review_03 completes imports, compile
  and14captures with live controls/restoration/hours and actual wall contact.
  lighting_review_04 renews native/export/compile/14views for final stage key;
  all captured failures/errors empty and all14views reviewed.
- lighting_occupied_01: terminal FAIL,243s, all8samples retained. Compared with
  occupied_cost_02, all17settings fields and camera transforms match; observed
  medians improve2–19%. Two33.3ms failures remain (33.539 and35.154ms), down
  from three. Unexpected engine errors empty. Host load was not independently
  measured; this is sequential comparison, not a controlled A/B/A. Occupied
  images motivated the final well-key refinement; no failure is relabeled.
- lighting_review_05: compile/nearby13profile/nine-cone check PASS,14views
  reviewed with no captured errors/failures. Native/support projection exactly
  matches04; original native evidence is retained without repinning.
- lighting_occupied_02: terminal FAIL,254.552s. Two33.3ms budget assertions
  remain; captured unexpected engine errors empty. Construction/seating and
  source/preview cleanup pass. The continuous diagnostic observer is NOT_RUN
  during timing; these are boundary/transit checks, not full safety proof.

## Final measured comparison

Same17settings fields (hardware, executable, quality, clock and weather) and
identical eight camera transforms against occupied_cost_02. Same20people plus
player.60warm/180sample frames per view. Host load was not independently measured;
this is observed sequential comparison, not controlled A/B/A or game-wide FPS.

| View | Before median ms | Final median ms | Change |
|---|---:|---:|---:|
| Pool0 |35.830|36.997|+3.26%|
| Pool1 |18.552|17.759|-4.27%|
| Pool2 |24.320|21.981|-9.62%|
| Pool3 |38.928|39.164|+0.61%|
| Gallery0 |21.114|17.287|-18.13%|
| Gallery1 |25.190|24.285|-3.59%|
| Gallery2 |33.965|32.363|-4.72%|
| Gallery3 |20.117|18.705|-7.02%|

Mean of view medians27.252→26.068ms (observed4.35% reduction); this does not
clear the two pool-facing budget failures. Maximum sampled frame62.962ms, so
world stutter is not claimed fixed. Raw distributions/draws and all eight PNGs
remain in lighting_occupied_02, with COMPARISON.json. North-row faces are more
legible after the well key, but deep/uneven shadows remain for artistic review.
The bright camera-facing circle in occupied images is the unchanged player lamp.

Implemented and technically checked: local optics, native mounts, live tuning,
power/hour transitions and rendered room layout. Player play, Lily artistic
acceptance, full export and final combined candidate are not claimed.

PR291 remains draft. Main214 dream changes merged after the first bar runs and
are not integrated into this source. Full composed surface/candidate qualification
and residual cost remain open. Before the next combined runtime batch, adjust
LightRig.stats to count the active cone rather than its low-energy spill source;
this debug reporting limitation does not alter emitted light or the actual
RenderingServer measurements used above.
