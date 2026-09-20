# V2 carried lamp: dust, thermal presentation and persistence

Canonical continuation of `63f89f3`. This is a scoped integration checkpoint, not full optical acceptance or V2 completion. V1 remains the selector default.

The existing 48x48x64 instantaneous field now drives both bounded air and 48 world-space dust particles. Dust receives native scene lighting and shadows, has no emissive glow, and stops rendering/emitting on logical off. Mesh occlusion remains native shadow-map injection; this is not arbitrary whole-building voxelization. DreamExposureField is untouched.

The electrical/thermal controller is copied byte-for-byte from optical source `4aa4585`, SHA256 `ffda7e1f985e72ceb18b62d2959a9cd13c743bfba653b31d2be74ab6e82e8604`. One optional V2 driver replaces the old player transient and supplies the real spotlight, field observation, volumetric multiplier and modeled lens. The logical switch remains immediate gameplay authority; its thermal afterglow does not reactivate air or dust. Radio changes preserve lens output. Production base energy remains 0.74.

Optional validated `lamp_optics` records capture controller state only at an allowed save boundary, including during a cutaway camera. Old saves initialize safely. Protected saves do not capture or write. Full-precision JSON preserves numeric values to the tested absolute tolerance of 1e-12; the engine parser can change a floating value by one ULP, so disk restoration is not claimed bit-exact. No GPU resources or particle positions are saved.

## Native evidence

All runs used the unchanged exclusive runner, Forward+ on RTX 4080, max 180 seconds.

| Run | Result | Scope |
| --- | --- | --- |
| `runtime.log` | 25/0, empty stderr | Dust integration before controller |
| `controller_05.log` | 22/0, empty stderr | Preserved algorithm, impacts, off tail, bounded validation, real disk restoration, protected save; warmed CPU median/p95/max 7/7/12 microseconds |
| `save_recovery.log` | 195/195, empty stderr | Existing save failure/recovery/New/Continue regressions |
| `save_matrix_02.log` | 42/0 | All four V1/V2 semantic/calendar/inventory/case/optical directions; before final modeled-lens edits |
| `composed_final.log` | 31/0, empty stderr | Final composed lens, shared air/dust field, entire off GPU volume zero, native blocker controls, twelve new owner/resource WeakRefs released |

Matrix stderr contains the deliberate invalid-selector control and existing V1 found-art placement warnings; no new script/runtime error. Failed controller runs are retained: exact JSON equality exposed the one-ULP roundtrip. Failed `save_matrix.log` exposed a fixture comparing a later legitimate autosave against the initial restoration boundary; the corrected fixture independently checks restoration and current live state.

## Visual and performance limits

`composed_final/` contains the actual composed captures and raw ABBA GPU samples. The dark-room view shows restrained warm dust in the beam, but remains dark and visually unfinished. The front lens is verified by its material values, not by a dedicated beauty view. Energy 1.5/4.2 captures are review variants only. Thermal state advances between captures, so these are not strict matched photometric comparisons. The GPU baseline varies between intervals; no whole-optics performance gate is accepted.

Remaining: frozen-state brightness/material comparison, additional material families, visual tuning and stable performance measurements, then the full V2 golden shift and outstanding completion/default gates.
