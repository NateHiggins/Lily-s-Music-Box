# V2 continuous wall trim and NYC seasonal weather

Evidence class: **INERT**. Implementation report, not a building-completion receipt.

REPORT - V2-MILLWORK-WEATHER - 2026-10-11

Branch / HEAD / origin/main / merge-base: main; candidate recorded in verification JSON; base **8b070404**.
Worktree clean at end: no; pre-existing owner renders, PDFs, UIDs and line-ending noise remain unstaged.
Protected 17/17: verification pending. Selector: V2; explicit V1 rollback preserved.
Ledger before -> after: 7/8/127/42/151/153 -> unchanged; requirements_changed: [].

The standardized native Blender stock now finishes actual wall fragments on both
sides of shared partitions, cut service walls and exposed returns. Door and
window joinery clips the finish. Raised roof-door casing clearance follows its
existing drainage fitting. Public panel cap is a distinct molded wood object
with longitudinal UV grain; panel backing, stiles and rails have separate stock
charts. Shop and passage finishes mount from retained source floor/wall records
and repeat on residency reload without changing collisions.

The weather manager polls every ten minutes when existing network weather is
enabled, using OpenWeatherMap with an environment credential or the existing
keyless provider. It blends observations for five minutes and falls back to
idealized seasonal conditions using verified NYC temperature normals. Saved
1928 campaign dates retain celestial and calendar authority. Forward+ now has
a half-resolution raymarched seasonal sky, full-mip authored Perlin-Worley 3D
noise, cheap cirrus, artistic twilight, rare noise-edged cloud shapes and outdoor
fog. Actual upward collision queries suppress weather under cover. Existing
precipitation, daylight and carried-lamp owners remain authoritative.

Assembly, API, node tree, rendering costs and compatibility limits are in
**game/docs/V2_MILLWORK_AND_WEATHER.md**. No API key is shipped; live HTTP was
not exercised with a credential. Engine TAA supplies temporal history; this
pass does not claim a dedicated cloud velocity/history buffer or measured FPS.

Gates and runtime receipts: pending final archive and candidate verification.
Numbers: 200 composed spaces; 19,599 sampled actual wall faces, zero trim gaps;
20,971 surface draws, 16,025 unique meshes, 5,339 materials and 413 textures;
zero loaded UV/PBR/mipmap/filter defects. The lightweight suite passes 37
checks, including every shop cell and the full 127-slice 3D mip pyramid. The
existing weather-provider suite passes. Native stock and four seasonal skies,
three shape variants and twilight were rendered and visually reviewed.

Changes outside expected boundary: surface discovery includes CPU precipitation
optics with narrowly named/script-bound exemptions; physical storm leaves still
require custom PBR. The import rule covers the cirrus mask, and the period gate
classifies the manager's campaign-date use. Spatial manifest additions are
limited to reviewed new production/test consumers.

Open findings not fixed: broader V2 completion blockers and historical texture
RID shutdown warnings remain. Existing canonical CRLF rehearsal fixture failure
is not part of this pass; fresh candidate verification checks its clean form.
Decision needed from owner: none.

MERGE-CANDIDATE pending
