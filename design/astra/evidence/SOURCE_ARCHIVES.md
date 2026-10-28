# Historical source snapshot archives

Evidence class: **INERT**. Storage consolidation, not new runtime acceptance.

SOURCE_ARCHIVES.json indexes sixteen archives by location, checksum, source
commit, file count and byte count. They replace frozen copies, not active code.
Logs, results, aggregate verdicts, invocation records, runtime manifests and
original artifact maps remain at their original loose paths.

| Archive group | Original source files | Stored archive bytes |
|---|---:|---:|
| Three navigation batches | 25,740 | 9,934,873 |
| Thirteen other audit families | 4,878 | 3,522,100 |

Each archive contains ARCHIVE_INDEX.json with original relative paths and
checksums. Every member was compared byte-for-byte with its loose original
before removal. Navigation originals also remain at commit
**7f301c66d9f6492ea336150cc624f0a3cfaf2441**; the additional source trees remain
at **4440ec943d98b4e16443ce3149d5cc1447f8d9cd**. Source commits in the JSON index
identify each archive independently. Failed controls remain failed controls.

## Reconstruct an offline review

Create a disposable mirrored directory preserving repository-relative paths.
Copy the selected family's remaining files, its unchanged validator and any
live source inputs that validator reads. Extract into the family's copy, at
the same relative directory that contains its archive. For example:

```powershell
tar -xzf C:/PleaseRemainOnTheLine/design/astra/evidence/apartment_material_binding/source_snapshots.tar.gz -C C:/ov/review-root/design/astra/evidence/apartment_material_binding
```

Run the existing offline validator against that reconstructed tree. Validators
may write derived summaries, so never run them against canonical historical
records merely to inspect an archive. The material aggregate was replayed this
way before and after reconstruction: 1,087 artifact hashes checked, zero
mismatches, identical results apart from the review timestamp. This proves
storage continuity; historical assertion failures inside those runs do not
become passes.

Identical frozen contents use tar hardlinks. Treat extracted copies as read-only;
do not extract over current gameplay or use them as editable worktrees. New
runtime runs still require the canonical shared Godot lane, not a restored audit
tree. Authoring harnesses can write fresh loose snapshots for fresh run names.

The new archives distinguish stored-byte checksums from LF-normalized text
checksums. Original receipts and artifact hashes were not repinned or rewritten.
The earlier navigation archives retain their original raw-checksum index format.
All archive files and this JSON index have explicit binary-stable Git attributes.
