# Historical navigation source snapshots

Evidence class: **INERT**. Storage consolidation, not new runtime acceptance.

The 25,740 loose **before/source** and **after/source** files from the three
**nav_direct** batches are retained in each batch's **source_snapshots.tar.gz**.
Logs, results, aggregate verdicts, invocation records, runtime manifests and
original artifact hashes remain at their original loose paths.

Each archive contains **ARCHIVE_INDEX.json**, with every original relative path,
byte count and SHA256. Every member was compared byte-for-byte against the loose
original before removal. The preceding complete tree remains recoverable at
commit **7f301c66d9f6492ea336150cc624f0a3cfaf2441**. This preserves failed controls
and their source; it does not upgrade their verdicts.

For a historical offline validator, copy the selected batch's remaining files
to a disposable review directory and extract its archive there:

```powershell
tar -xzf C:/PleaseRemainOnTheLine/design/astra/evidence/resident_f01_haunt/nav_validation/nav_direct_03/source_snapshots.tar.gz -C C:/ov/nav-review
```

Run the existing validator against that reconstructed directory. Identical frozen
contents use tar hardlinks to avoid storing repeated copies. Treat extracted
snapshots as read-only; do not extract them over current gameplay or use them as
editable worktrees. The authoring harness can still write new loose snapshots
for a new run; no historical result or artifact map was rewritten.
