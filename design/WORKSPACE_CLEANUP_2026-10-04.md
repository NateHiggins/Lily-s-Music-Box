# Workspace cleanup — 2026-10-04

Evidence class: **INERT**

REPORT - WORKSPACE-CLEANUP - 2026-10-04

Branch / reviewed HEAD / origin/main / merge-base: **main** /
**c7b6f01cc670f2708b086816869df76fa0e14ebc** /
**98c57c10601ccbcc52b46b8369d07e4da3824c76** /
**98c57c10601ccbcc52b46b8369d07e4da3824c76**.
This report records local filesystem housekeeping; its later metadata commit
does not change runtime assets or confer acceptance.

Worktree clean at report: **yes**. Generated legacy import UIDs were removed
after the completed Godot run. Other agents' editable checkouts remain.

Protected 17/17: **yes, unchanged against the merge-base**. Selector: **v2**.
Ledger before -> after: **7 / 8 / 127 / 42 / 151 / 153** ->
**7 / 8 / 127 / 42 / 151 / 153**; requirements_changed: **none**.

## Removed redundant storage

The initial logical census measured **109.54 GiB**. The later census measured
**78.960 GiB**, including the newly retained audit manifests and test captures.
The net reduction is approximately **30.58 GiB**.

- Removed obsolete Windows and Android build products: **1,510,230,225 bytes**.
- Removed three copies of the same rescued worktree archive:
  **165,228 files**, **30,325,931,694 bytes** (**28.243 GiB**).
- Compacted Git without pruning objects or expiring reflogs. Loose objects
  dropped from **50,156** to **7**; the object store went from approximately
  **18.8 GiB** to **17.7 GiB**. Unreachable recovery objects remain in a cruft pack.

The three removed archive roots were **.claude/worktree-archive** and its
copies inside the **godot-dev-reference-manual-911b93** and
**interesting-booth-8088c2** checkouts. Their editable source checkouts and
branches remain. Every removed file's SHA-256 matched both the old rescue
manifest and its actual content-addressed backup object under
**C:/ov/worktree-rescue-20260921**. A second census checked sizes and modification
times before deletion. No unverified file was removed.

All **164 Git references** remain. All **4,040 earlier reflog entries** remain;
the authorized verifier commit added two entries. **git fsck --full
--no-dangling** completed successfully with no diagnostics. Art masters,
Blender sources, current imports, verification evidence, the live Godot cache
and the owner in-situ catalogue remain. The owner catalogue SHA-256 stays
**1c97d690fd73325b00ae1f7ae84311bddd42dbd25bc10ae417830c8e3ef03525**.

Local audit records are under **tmp/workspace-cleanup**: the before/after
censuses, SHA-bound removal plan, removal inventories, Git reference/reflog
snapshots, preservation comparison and integrity log. These are housekeeping
records, not runtime contracts.

## External folders shown by the owner

The twenty **C:/PleaseRemainOnTheLine-v2-*** output roots total **26.083 GiB**;
none is a registered Git checkout. They remain untouched in this cleanup.
Most can be retired after unique reports, captures and source snapshots are
consolidated. **C:/PleaseRemainOnTheLine-v2-m11c1-export-eighth-attempt** is a
specific exception: **tools/tests/test_m11c1_runtime_rehearsal.py** still reads
its original immutable transaction export. Removing it would silently skip
that optional historical test class. Preserve that dependency until an explicit
fixture relocation retains its bytes and test coverage. The live project is
**C:/PleaseRemainOnTheLine** and must remain.

## Verification and continuing work

The canonical candidate verifier at **tmp/roof-drain-discovery/verified-windowed-ui**
compared all **47 static/tool gates** with the complete clean merge-base board:
**zero regressions**, protected **17/17**, selector **v2**, reader **zero NEW**,
spatial **zero drift**, and unchanged ledger counts. Completeness exit **2** and
the M11C1 historical protected-floor-hash tools-test exit **1** remain baseline
findings. The connected-world windowed long-run receipt records exit **0**,
**42,260 checks**, **zero failures**, and a completed **448.76-second** run.
The first headless attempt remains recorded separately; headless mouse capture
cannot satisfy that test's prompt contract. The verified long-windowed runner
choice preserves its real interactions and rendered capture checks.

Changes outside the cleanup boundary: the independently verified roof
installation and necessary verifier renderer/ceiling support precede this
report. Housekeeping changes no physical or gameplay owner. Broader architecture,
materials, independent bar/arcade services and distant-city closure remain open
as recorded by the roof installation report. The mineral A/B study remains
scratch work and has not replaced production textures.

Decision needed from owner: **none for the completed cleanup**.

MERGE-CANDIDATE **c7b6f01cc670f2708b086816869df76fa0e14ebc**
