# Sky sampling and day/night film — November 12, 2026

Evidence class: **INERT**

REPORT — sky sampling / film — 2026-11-12

Branch: **codex/sky-sampling-film-20261112**, based on **17b979dc8551e66f1559c7452263bc93e80012a2**. Root Codex is the integration owner. Qualification and merge custody are recorded externally at **C:/ov/reports/sky_sampling_film_20261112/**. This report does not promote completeness-ledger requirements.

## Implemented

Ordinary low/mid clouds now integrate two deterministic Gauss samples per interval, sharing midpoint lighting. A finite footprint filters each sample while an explicit primary-sample flag retains its billow detail. This removes the visible pixel-hashed crosshatch without increasing shadow samples or changing rare-formation sampling.

The high plane supplies projected pixel derivatives to its noise/fibre mip selection. Cirrus stretches its fine fibres while keeping broad packets isotropic. Cirrocumulus retains fine cells grouped into broader families rather than replacing them with elongated distant masses. The broad field now uses its separately transported phase and integer coordinate transform; fractional scaling of an already-wrapped phase could jump at wrap boundaries. Coverage, wind publication, calendar, astronomy, save and prologue owners remain unchanged.

**V2DayNightFilm.tscn** captures the existing detached rooftop preview to a bounded CPU encoder, **tools/encode_sky_film.py**. It records no startup frames, preserves native samples and per-frame clock/source metadata, and streams RGB through a pipe instead of writing a multi-gigabyte frame dump. The helper preserves failed partial output, refuses overwrite, bounds encoder drain and kills only its own child on deadline. Tested-byte paths are protected from checkout line-ending conversion.

## Verification and delivered film

Patched Godot 4.7.1, Forward+ / Vulkan, shared FIFO, hidden desktop:

- **sampling04.log.receipt.json**: 12 dated all/low-mid/high views, zero failures, 3440×1440. Independent native-frame review confirms removal of the obvious grain and reduced long connected high-cloud streaks.
- **contracts04.log.receipt.json**: nine optical/temporal checks pass, including bound mipmapped textures, fractional motion, pause and return-to-time consistency.
- **events04.log.receipt.json**: mammatus, tornado and aurora controls, three frames, zero failures.
- **compile02.log.receipt.json**: autoload-aware film script compilation passes.
- **film_full02.log.receipt.json**: actual occupied city capture completes. **film_full02/VIDEO_RESULT.json** verifies 576 decoded H.264 frames, 1920×1080, 24 fps, exactly 24 seconds, two rendered steps per output, actual 1/48-second process delta, unchanged recorded sources and restored original campaign/settings.

Film: **C:/ov/reports/sky_sampling_film_20261112/film_full02/sky_day_night.mp4** (31,140,794 bytes; SHA-256 **47e1255d88597b5c3fe558ba88a403a2cedc912ae68fc3605aeba20f116f129d**). February 23–24, 1929, 08:00–08:00; 24-degree pan. The camera alone is elevated four metres. The inherited preview freezes the resident agenda and hides HUD/companion; residents/buildings remain present. This is an offline optical film, not real-time performance, human play or save/reload qualification. No music or audio was requested for this sky review.

The first film attempt **film_full01** stopped before recording because Godot removes recognized engine flags from its exposed command-line array. The fix asserts the actual timestep instead; original failure and restoration evidence are retained. Existing resident texture-UID fallback warnings remain, with text paths resolving; no missing-city geometry error occurred. CPU relay smoke covers normal completion, premature EOF and stalled-input cleanup; its receipts remain in **film_draft/RELAY_CPU_SMOKE.json**.

## Cost, boundaries and remaining work

Paired source-bound performance results are recorded in **paired05/**, using a recursively expanded seven-input shader from the exact base commit and identical dates, views, textures and settled sample counts. This isolates the additional density cost; offline film encoding is not a frame-rate benchmark. Clean baseline/candidate board comparison and protected-path results belong to **verification01/**; do not infer a green main from this scoped change.

Faint grazing horizontal striations and perspective-aligned wisps remain. Fine Cc can look busy/repetitive. Magnified telescope presentation, the complete annual artistic survey, special-event art, activation stalls and precipitation seen through openings remain separate debt. Lily's artistic acceptance and human play are still open. Existing calendar/save and precipitation evidence is unchanged; those suites were not repeated or relabelled as proof of this shader change.

Named source boundaries: two sky shader files; film scene/script; CPU encoder; checkout attributes; weather verification guidance; this report and the two continuity trackers. No gameplay data or canon changes. Original failure/candidate images and the finished film remain on retention hold; no purge authorization is implied. Unrelated generated UIDs are preserved. Reuse the existing verification checkout, then return it to its compact sparse state.

Decision needed from owner: none for technical integration; artistic review remains hers.
