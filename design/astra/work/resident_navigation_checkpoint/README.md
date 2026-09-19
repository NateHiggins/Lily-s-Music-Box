# Navigation checkpoint — prepared, not staged

Only root may execute preparation/staging after reviewing the frozen aggregate
and releasing the engine/source lane. This package does not launch an engine,
edit production, rewrite receipts, reset the index, or commit anything.

The fixed scope is two production owners and six Direct/Haunt/LiftWaiting
fixture files, with the four named resident evidence/work packages and the
waiting review. The final eight raw hashes and sealed aggregate SHA256 are in
scope.json. Every historical launch, parse, schema and semantic failure stays
in the named packages. Historical copied renderer/material sources are evidence
only; they are never installed as production. Profiles and caches are excluded.

package_seal.json binds the exact four instrument/configuration/document files
and records the offline control result. Preparation and staging refuse an
instrument changed after that seal. The seal is selected with the package.

After root review, first prepare a fresh named packet:

    python -B design/astra/work/resident_navigation_checkpoint/prepare_checkpoint.py reviewed_01

Inspect reviewed_01/selection.json and scope_proof.json before invoking the
separate mutation:

    python -B design/astra/work/resident_navigation_checkpoint/prepare_checkpoint.py reviewed_01 --stage

Both invocations require an index identical to HEAD, including modes and
intent-to-add. Staging rechecks package membership, every selected byte/blob,
all retained result artifact maps, the sealed aggregate links, final eight
tested owner hashes, and seventeen protected HEAD/index/current clean blobs
against final_batch.json. It refuses drift and never resets a partial failure.

Evidence/work have checked -text attributes. Python calculates raw SHA256 and
Git raw blob SHA1 together in one streaming read per file. The lone normal
review must contain plain LF and no filters/encoding/ident transformations.
Only eight owned normal game files use Git's actual clean hashing, plus one
fixed seventeen-file protected check. There is no Git subprocess per evidence
file. The protected binaries are read only for this required bounded check.

One explicit literal NUL payload is passed to git add. One post-stage
git ls-files -s -z map checks every selected blob/mode and every unselected
index entry. Files already committed unchanged remain selected/verifiable but
are not incorrectly expected in git diff --cached. Whitespace checking applies
only to the eight live game files; raw historical evidence/patch CRLF is never
submitted to a giant diff --check.

selection.json and scope_proof.json are themselves explicitly selected.
paths.nul and the later staging_manifest.json stay local execution receipts;
they are not recursively added to their own payload. A failed add/check writes
FAILED_REVIEW_REQUIRED and leaves the actual index available for inspection.
Root owns any subsequent correction, commit and canonical ledger amendment.

Bounded offline controls (no staging, engine or repository writes):

    python -B design/astra/work/resident_navigation_checkpoint/test_prepare_checkpoint.py

These cover the real Git blob oracle for mixed bytes, literal paths, cache/path
refusal, unmerged/intent-to-add indexes, unchanged selected entries, foreign
adoption, blob drift, mode changes and missing selected files. They do not claim
that the full selection or staging has already executed.
