# Resident bookcases

Eight authored bookcases are installed in the developed V2 apartments: Mina and Malcolm's repaired shelves; Peter and Mae's glass-fronted sectionals; Nadia, Iris and Jonah's plain oak cases; Sacha's repaired case. The original libraries, sorting schemes and Mae's required prospectus are retained. No library was added to a household lacking an authored bookshelf.

Sixteen new semantic anchors provide installation and standing positions. Existing anchors, furniture, fixtures and resident programs are unchanged. Full native case/lift-door clearance is included in the shared placement census. Plain and repaired cases remain open; the two sectionals retain their lifting glass mechanisms.

The existing household save owner now stores eight book-ID permutations, for 124 household settings total. Sorting through the native panel commits the new order. Taking a book down leaves its ID in the saved sequence. Closing the panel puts it back; loading or retiring the world closes the external panel and releases its player lock. No held slot, panel, animation or coordinates are saved. Old saves default omitted libraries. Invalid permutations are rejected atomically.

## Verification

- Source reconstruction against `1ddf9d7`: eight solid wall positions, complete aperture avoidance, existing standing and route clearances, lower and upper door sweeps. This is sampled source clearance, not a continuous played-route claim.
- Household save suite: 100 checks, including real isolated disk save/reconstruction and malformed book arrays.
- Bookshelf suite: 118 checks, including actual player E rays, standing capsules, movement collision, UI book movement, two book meshes, native sectional motion, mid-session load and world retirement with a panel open.
- Apartment composition regression: 18,332 checks. Final total: 18,550, zero failures, empty final stderr.
- Eight original 1280×720 Forward+ captures in `shelves_01`; `comparison.png` is a resized contact sheet. Existing room lighting and the live carried voxel lamp are used. No temporary fill lights, material overrides or hidden architecture.

The retained earlier failed runs show a numeric JSON comparison repaired in the manifest validator and an explicit test variable type fix. Final runs are named in `receipt.json`.

## Visual limits and remaining work

All three native case styles and their sparse authored book collections are visible. Dark interiors and spines, particularly Sacha's repaired shelf, still need broader lighting review. Close views include the held lamp; they do not establish full-room composition or performance acceptance.

Remaining resident equipment/media, residential and shared/service programs, physical utilities, resident migration, played routes and performance still prevent V2 completion. V1 remains the default; S2J is open. This packet does not grant release or human art acceptance.
