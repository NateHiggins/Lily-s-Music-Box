# Historical M11C1 runtime rehearsal inputs

Evidence class: **INERT — isolated test fixtures; grants no runtime acceptance**

`historical_inputs.zip` freezes the three source documents used by the eighth
M11C1 disposable export, run **M11C1-12b0189ee7fe5afb6190447a**. Its members retain
exact bytes. The source layout and seam manifest were copied from the unchanged
reconciliation checkout; regions are commit **acdb4be42e5d973df623c3545aacde95855a1d07**
with the historical CRLF checkout encoding. That exact regions hash is recorded
by the existing external export. The test asserts every archive member's SHA-256.

The fixture contains no modified receipts or protected geometry. Tests copy the
current checkout's two protected F01 assets into a temporary source tree and run
all existing export, texture, transaction and semantic checks against that tree.
The normal command still validates the current repository. Explicit controls
retain rejection of current mismatched regions, modified historical raw bytes,
and a source change between export validation and runtime-config creation.

The optional full transaction tests still require the original external export
at **C:/PleaseRemainOnTheLine-v2-m11c1-export-eighth-attempt**. They do not recreate
that historical export or authorize it as a current production export.

| Archive member | SHA-256 |
| --- | --- |
| game/data/building_layout.json | 68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d |
| game/data/orison_v2/exterior/regions.json | 1f128e4411e135acfc7e9046d5a2c3edf940d39adce54d336fbba8523f1a488a |
| design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json | cb388a535ef65e46c365667441a661bb3475ad7704c5ecac02c147487c593c45 |
