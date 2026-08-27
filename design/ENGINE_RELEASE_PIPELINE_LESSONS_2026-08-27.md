# Engine knowledge — release artifacts are a provenance pipeline

**Status:** observed and implemented on Windows, 2026-08-27  
**Applies to:** Please Remain on the Line and any project built on its tooling  
**Evidence run:** detached checkout at `4e034086`, Godot 4.7.1, Windows x86-64

## The useful model

A build is not “the files Godot happened to emit.” It is a chain of custody:

```
source commit
  → bounded cold import
  → sealed generated identity
  → platform export + source manifest
  → tester payload + legal payload
  → archive hash
  → distribution event
```

Each arrow needs a refusal. If a tool cannot prove the previous state, it must
stop before producing evidence for the next one.

## What the real dry run taught us

### 1. Cold import is resumable work, not one command

The project no longer cold-imports inside the repository's 60-second engine
ceiling. The observed clean checkout needed three serialized passes: two were
terminated at the ceiling, and the third completed in 22.9 seconds. Treating a
timeout as corruption would make clean release builds impossible; removing the
ceiling would make engine ownership unverifiable.

The correct primitive is therefore a **commit-bound resumable import**:

- prove the checkout clean before the first pass;
- write an ignored “started for this SHA” marker;
- let each Godot process run for at most 60 seconds;
- on retry, admit only the exact generated classes the importer owns;
- write readiness only after a successful pass and a second source census.

This pattern generalizes to shader compilation, asset cooking, navigation
bakes and other caches whose first population can exceed a process budget.

### 2. Generated identity is still identity

Godot generated 190 untracked source UID sidecars for scripts and shaders:
`*.gd.uid`, `*.gdshader.uid`, and `*.gdshaderinc.uid`. Ignoring every `.uid`
would make the clean-checkout claim false. Requiring zero generated UIDs would
make a clean checkout unexportable.

The implemented middle path seals the exact sorted path/hash set under
`.godot`. Export refuses if one UID is added, removed or changed. Generated
metadata may be untracked, but it may not be unaccounted for.

General rule: **cache location does not decide evidentiary importance.** If a
generated value can change references or exported bytes, inventory it.

### 3. “No semantic diff” and “no diagnostic output” are different checks

Git correctly reported tracked `.import` sidecars as byte-equivalent under
`--ignore-cr-at-eol`, while also printing Windows checkout conversion
advisories. PowerShell can capture native diagnostic records alongside command
output; the warnings were counted as dirty filenames.

The fix suppresses only Git's safe-CRLF advisory for the census command. It
does not suppress errors and does not weaken staged, unstaged or untracked
checks. Similarly, `config/version` parsing must explicitly accept `\r?\n`;
an LF-only line anchor failed against the real Windows checkout.

General rule: test release tooling in the platform shell that will run it.
Source inspection does not prove stream semantics, path semantics or newline
semantics.

### 4. Export identity precedes packaging identity

The Windows exporter writes a manifest containing:

- exact 40-character source commit;
- preset name;
- export UTC time;
- SHA-256 of the EXE;
- SHA-256 of the PCK.

The packager refuses a stale preset, stale commit or changed binary. Its
`BUILD_ID.txt` repeats the version, commit, engine, preset and component hashes;
the archive receives a separate SHA-256 sidecar because a ZIP cannot contain
its own final hash without a self-reference problem.

The proof artifact contained exactly six top-level files:

1. `BUILD_ID.txt`
2. `LICENSE.txt`
3. executable
4. PCK
5. tester readme
6. third-party notices

This shape should become an engine template, with product-specific names and
legal payload injected as inputs rather than embedded in the packager.

### 5. Mechanical readiness is not authorization

The end-to-end dry run used a licence whose first line was `DRY RUN — NOT FOR
DISTRIBUTION`. The package passed, which proves the machinery. It cannot prove
the owner approved a legal name, licence grant, tester cohort or upload.

Keep these states separate in every future project:

| State | Meaning |
| --- | --- |
| exportable | engine can produce platform binaries |
| packageable | artifacts satisfy the mechanical payload contract |
| distributable | owner/legal/privacy decisions are resolved |
| released | a named artifact was uploaded, installed and exercised |

No green state implies the one below it.

## Reusable acceptance test

A future engine/tool release pipeline is not complete until a clean detached
checkout can demonstrate all of the following:

- first cold pass may time out without leaving an ambiguous state;
- retry cannot admit arbitrary untracked content;
- generated reference metadata is sealed by path and hash;
- export refuses a dirty checkout and a stale warm marker;
- package refuses an export from another commit;
- component hashes reproduce from the staged files;
- payload membership is an exact allowlist;
- third-party notices are generated from canonical sources;
- archive hash lives outside the archive;
- a conspicuous non-shipping licence can prove mechanics without being
  mistaken for authorization;
- install, launch, rollback and revocation are tested on a second machine
  before “released” is used.

## Current measured debt

- Cold import is at least 142.9 seconds across three bounded processes. That is
  release/operator cost and a signal to profile importer breadth later.
- The proved PCK is 1,183,547,200 bytes; the dry-run ZIP is 1,201,980,406
  bytes. Distribution cost is dominated by shipped content, not packaging.
- There is no owner-approved shipping licence yet.
- No second-machine install, launch, rollback or key-revocation rehearsal has
  occurred.

Those are gates, not reasons to blur the states above.
