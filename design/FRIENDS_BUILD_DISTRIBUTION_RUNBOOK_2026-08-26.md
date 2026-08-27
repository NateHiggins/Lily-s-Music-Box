# Friends-build distribution runbook — 2026-08-26

> **CURRENT BUILD PATH — 2026-08-26:** run
> `tools/export_friends_build.ps1` from a clean checkout, then
> `tools/package_friends_build.ps1`. The exporter enters the single Godot lane
> through `run_godot_serial.ps1` and writes a commit- and hash-bound
> `.orison_export.json`; the packager refuses an absent, stale or modified
> export. Historical direct `godot --export-release` commands below describe
> the original audit and are not the current operator command.
> The exporter checks source content both before and after Godot. A fresh
> detached checkout at `88a37a1` exhausted the 60-second lane at 98% reimport
> and produced no binary. Git initially reported 306 `.import` paths modified,
> but their blob hashes matched and `--ignore-cr-at-eol` proved this was CRLF
> worktree noise, not content mutation. The open blocker is cold-import time:
> run `tools/warm_release_checkout.ps1` on the exact release checkout before
> exporting. A cold run may hit exit 73; invoke it again manually after reading
> the filtered process result. It never retries itself. Only a completed clean
> import writes the commit-bound readiness marker the exporter requires. In the
> proof worktree, the continuation import completed in 23.6 s and the export in
> 15.3 s, producing a 109,071,360-byte EXE and 1,186,496,136-byte PCK. Do not
> relax the post-export content gate.
>
> **INTEGRATION NOTICE — `a8d8d0c`, 2026-08-26:** this runbook was integrated
> after the Windows export proof. Its historical acceptance table says clean
> export/templates were UNRUN; the canonical measured result is now the
> release evidence matrix G27 notice: Windows x86-64 export exit 0, 14.5 s,
> 109,071,360-byte EXE plus 1,250,936,396-byte PCK. `packageable`,
> `distributable`, second-machine `installable`, `playable` and `diagnosable`
> remain open exactly as ruled below.
>
> **IDENTITY NOTICE — `8d036fc`, 2026-08-26:** the product now reports
> `Please Remain on the Line`, version `0.1.0`, and opts into the stable ASCII
> custom user directory `PleaseRemainOnTheLine` (`ProjectIdentityTest` PASS
> 4/4). O1 and the code-side half of O8 are closed. The exact Windows-resolved
> path and uninstall/removal instructions still require one real exported run;
> no previous development save directory was deleted or silently migrated.
>
> **PACKAGING CONTRACT CORRECTION:** the earlier template required the final
> ZIP SHA-256 inside `BUILD_ID.txt`. That is self-referential: inserting a ZIP
> hash changes the ZIP and therefore changes its hash. The canonical contract
> is now EXE and PCK hashes inside `BUILD_ID.txt`, plus the final ZIP hash in a
> sibling `<archive>.zip.sha256` file. `tools/package_friends_build.ps1`
> enforces the exact six-file payload, refuses overwrite/reused build numbers,
> requires an owner-supplied license path, and writes the external sidecar.
>
> **THIRD-PARTY NOTICE UPDATE — 2026-08-26:** the payload contract is six files,
> not five. `tools/build_third_party_notices.ps1` assembles
> `THIRD_PARTY_NOTICES.txt` deterministically from the in-tree Courier Prime OFL
> and Freesound attribution records plus Godot's official licence link. The
> owner-supplied `LICENSE.txt` remains separate; this update chooses no licence
> for the game's original work.
>
> **END-TO-END DRY RUN — 2026-08-27:** cold import resumed safely across two
> 60-second terminations and completed on the third bounded pass, sealing 190
> generated UID sidecars. Windows export passed in 21.0 s. Mechanical build 999
> then produced the exact six-file payload and a 1,201,980,406-byte ZIP with
> SHA-256 `18c78a0cb0ad53ed4dd2bc6ff9b39db8a60cb14da5d05696dd07b486a364335d`.
> Its licence conspicuously said `DRY RUN — NOT FOR DISTRIBUTION`; packageability
> is proved, but owner authorization, upload, second-machine launch, rollback
> and key revocation remain open.

**Purpose:** the smallest honest distribution path for a private friends build,
beginning the moment Codex supplies a working Windows export preset. This
resolves **G23** from `EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`.

**Base:** `a7d6114` — the pushed `origin/main` tip at commit time. The audit
began at `95b7a83`; **origin advanced four commits during the work, and two of
them close the precondition this runbook was written to wait for**:
`2165c3c` "Add a Windows friends-build export", `d7530f1` "Close the desktop
export gate" and `a7d6114` "Keep source audio out of release builds". The branch
was moved to the new tip and every affected row re-verified — see §1.1.

**No Godot was launched. `export_presets.cfg`, `project.godot`, scripts,
scenes, tests and `TASKS.md` were not edited.** Every engine/export command in
§3 is marked **UNRUN** because I may not run it.

> **A folder containing an .exe is not a release process.** A release process
> has an identity you can quote back, a channel you can revoke, an artifact you
> can reproduce, and a defect report you can act on. This document is about
> those four things.

---

## 1. Audit before the recommendation

Everything below is read from tracked files and git metadata at this commit.
**Nothing is assumed to exist.**

| Question | Finding |
| --- | --- |
| Build/packaging infrastructure | **PRESENT.** Four checked PowerShell tools own warm import, export, packaging and third-party notices. Generated output remains ignored under `build/`. |
| CI | **NONE.** There is no `.github/` directory at all — no workflows, no Releases automation, no issue templates. |
| Git remote | `https://github.com/NateHiggins/Lily-s-Music-Box.git`. **The repository name does not match the game.** Whether it is private is **UNKNOWN** from tracked files. |
| Versioning | **PRESENT.** `application/config/version="0.1.0"`; the packager copies it into `BUILD_ID.txt`. |
| Naming | `application/config/name="Please Remain on the Line"`; the stable user directory is `PleaseRemainOnTheLine`. |
| Signing | **NONE, deliberately.** `.gitignore:95–99` excludes `*.keystore`, `*.jks`, `key.properties` and states *"None exist in the tree today and none ever should."* That covers **Android**; **no Windows code-signing certificate exists or is referenced anywhere.** |
| Crash reporting | **NONE.** No Sentry/Crashpad/Breakpad. `attention_ledger.gd` is playtest telemetry that writes nothing to disk and sends nothing. |
| LICENSE | **ABSENT.** No `LICENSE`, no `LICENSE.md`, no `COPYING`. |
| README | `README.md`, 131 lines — a developer readme, not a tester readme. |
| CHANGELOG | **ABSENT.** |
| Export presets | **G27 CLOSED MID-AUDIT.** A `Windows` preset now exists — `platform="Windows Desktop"`, `export_path="../build/windows/PleaseRemainOnTheLine.exe"`, `architecture="x86_64"`, **`embed_pck=false`**, with an `exclude_filter` covering `tests/*`, `docs/*`, source audio and source sky textures. See §1.1. |
| Steam state | **No AppID appears anywhere in tracked files.** No Steamworks SDK, no `steam_appid.txt`. Nothing indicates an account, app or store page exists. |
| Second project in-repo | `audio_virus_prototype/` is a separate Godot project with its own `project.godot`. It must not be swept into an artifact. |
| Odd tracked binary | `Godot_v4.7.1-stable_win64_console.exe`, 196 KB — the console wrapper stub, committed before `.gitignore:76` began excluding `Godot_v*.exe`. Harmless, but it must not ship. |

### 1.1 What landed mid-audit, and what it changes

`2165c3c` / `d7530f1` add a **Windows Desktop** preset and `a7d6114` extends the
exclude filter. Three consequences for this runbook:

1. **The precondition in §3 is satisfied.** The checklist can begin.
2. **`embed_pck=false`**, so the artifact is an **executable plus a separate
   `.pck`**. §4's "either/or" is now decided for us: they ship together, in the
   same zip, always. A stale `.pck` beside a fresh `.exe` is the failure mode to
   guard against.
3. **The export name is `PleaseRemainOnTheLine.exe`**, the window title is
   `Please Remain on the Line`, and version `0.1.0` is explicit.

**The engine-side exclude filter does part of §4's job**, covering `tests/*`,
`docs/*`, source audio and source sky textures. It does **not** replace the
operator check: the filter governs what enters the `.pck`, while §4 step 5
governs what a human puts in the **zip**, which is where `Godot_v*.exe`, a log
or a personal path would arrive.

**Still absent:** an owner-approved licence grant. Identity and mechanical
packaging are no longer the lowest rung; authorization and second-machine
rehearsal are.

### What a tester leaves on their machine

Every `user://` path written by production code:

```
user://orison_settings.cfg              settings, incl. weather consent
user://reality_maintenance_save.json    the save (SAVE_VERSION 4)
user://orison_lighting_settings.json    lighting prefs
user://photos/ + manifest.json          screenshots the PLAYER takes
user://songbook/ + songbook/vocals      MICROPHONE RECORDINGS
```

`use_custom_user_dir` is set and the stable folder name is
`PleaseRemainOnTheLine`. **UNKNOWN:** the complete Windows-resolved path has not
been read from a second-machine exported run. **An operator must read the
real path off a real machine before writing it into tester instructions.**

---

## 2. The ruling

### Recommended first channel: **itch.io — unlisted project, per-person download keys, uploaded with butler**

**Why this one:**

1. **Access is per-person and revocable.** itch.io download keys can be
   generated individually with a label and *"revoke it if necessary"*
   **[SOURCED S4]**. A cohort of six friends is six keys you can withdraw
   one at a time — the correct granularity for a build with known defects.
2. **No review, no approval, no lead time.** Nothing is submitted to anyone.
3. **butler gives real update mechanics**, not re-uploaded zips: it uploads
   builds and *"generate[s] patches and apply[s] them offline"* through the
   Wharf specification **[SOURCED S3]**. Numbered friends builds get diffs
   rather than full re-downloads.
4. **It costs nothing to stand up** and consumes nothing irreversible.
5. **It is not the eventual store.** Using itch for a private cohort spends no
   Steam asset, no Next Fest slot, and no store-page first impression.

### Fallback: **GitHub Releases on the existing repository, marked pre-release**

The remote already exists, so no new account is needed. A release asset may be
up to **2 GiB**, with up to 1000 assets per release, and releases support
**draft** (unpublished, assets attachable) and **pre-release** (*"not ready for
production and may be unstable"*) states **[SOURCED S1, S2]**.

**Why fallback and not first:** access control is repository-shaped, not
person-shaped — you cannot revoke one tester without changing repo access — and
**it is UNKNOWN from the official pages I could verify whether a private
repository's release asset can be downloaded without a GitHub account and repo
permission.** That must be tested with one real tester before relying on it.

### Refused: **Steam Playtest** — and not because Steam is the eventual target

Valve's own documentation disqualifies it for this cohort:

- **Participation is not confidential.** *"No — players signing up for a
  Playtest aren't under nondisclosure agreements with you, and there shouldn't
  be an expectation of secrecy."* **[SOURCED S5]**
- It requires **its own child AppID**, and the signup lives on the **main
  game's store page**, which does not exist.
- It requires **Valve review** (capsules and icons) **[SOURCED S5]**.

The current build still has no unaided human golden-shift evidence (G01/K2),
no eleven-boundary human save matrix (G15/K3), and no second-machine release
measurement (G20). Controller and debug-overlay code gates are now green, but
their required human route checks remain open. **A channel with no expectation
of secrecy is exactly the wrong place for that build**, regardless of where the
game eventually ships.

### Refused: **direct cloud links** (Drive/Dropbox/WeTransfer)

No revocation once forwarded, no build identity, no update path, no download
record, and the recipient still meets the SmartScreen warning with none of the
context a store page provides.

---

## 3. Operator checklist — clean checkout to uploaded artifact

The import/export/package commands have completed in an isolated proof checkout.
Only second-machine and distribution operations remain unrun.

**Precondition: SATISFIED** as of `2165c3c`/`d7530f1`. A `Windows Desktop`
preset exists; the 2026-08-27 detached-checkout run proves warm import, clean
export and mechanical packaging. Steps 2–7 remain the required operator route,
not unrun hypotheses.

```
 0. PRECONDITION   Windows preset + version + identity: DONE

 1. CLEAN CHECKOUT git clone <remote> --branch main <tmp>
                   verify: git rev-parse HEAD  == the SHA you intend to ship
                   verify: git status --porcelain is EMPTY
                   (do NOT build from the shared worktree; its dirty/untracked
                   development files do not belong in an artifact)

 2. IMPORT         tools/warm_release_checkout.ps1
                   repeat manually after a bounded timeout; only a complete
                   pass writes the commit-bound readiness/UID seal

 3. EXPORT         tools/export_friends_build.ps1
                   writes EXE/PCK + commit/hash manifest                 PROVED

 4. VERIFY EXE     the output directory contains exactly the executable and
                   its .pck (or a single embedded-PCK executable), and
                   nothing else                                        UNRUN

 5. STRIP          confirm NO: source, .gd, .import, .godot/, tests, tools/,
                   art/renders/, design/, audio_virus_prototype/,
                   Godot_v*.exe, logs, .git, personal paths in any string

 6. PACKAGE        tools/package_friends_build.ps1 -BuildNumber <NNN> \
                     -LicensePath <owner-approved-file>
                   adds README, BUILD_ID, licence and third-party notices

 7. VERIFY         exact six-file allowlist and component hashes          PROVED

 8. HASH           record SHA-256 of the zip; it goes in the release note and
                   in the feedback form

 9. SMOKE          on a SECOND machine, unzip and launch; reach the title
                   screen; start; quit cleanly                         UNRUN

10. UPLOAD         butler push <dir> <user>/<game>:windows-friends       UNRUN
                   (butler requires authentication — see §8)

11. KEYS           generate ONE individual download key per tester, labelled
                   with their name                                [OWNER]

12. RECORD         log build ID, SHA-256, SHA, date, and who got which key
```

---

## 4. Artifact contract

**Directory and zip name**

```
PleaseRemainOnTheLine_friends-<NNN>_win64_<shortsha>.zip
        └ PleaseRemainOnTheLine_friends-<NNN>_win64_<shortsha>/
             PleaseRemainOnTheLine.exe
             PleaseRemainOnTheLine.pck        (unless embedded)
             README_TESTER.txt
             BUILD_ID.txt
             LICENSE.txt                       (owner action, §8)
             THIRD_PARTY_NOTICES.txt
```

`<NNN>` is a monotonic friends-build number starting at `001`. It never resets
and never reuses a number, even for a rebuild of the same commit.

**Executable / PCK relationship.** Either a separate `.pck` beside the `.exe`,
or a single embedded-PCK executable. **Both are acceptable; mixing is not** —
a stale `.pck` beside a new `.exe` is a bug report you will not be able to
reproduce. If separate, they ship in the same zip and are never distributed
apart.

**Identity visible to the tester — mechanically proved.** Version `0.1.0` and
the exact source/export identity enter `BUILD_ID.txt`:

```
build      friends-001
version    0.1.0
commit     <full 40-char SHA>
built      <UTC ISO-8601>
preset     Windows Desktop
engine     Godot 4.7.1
exe_sha256 <of the executable>
pck_sha256 <of the PCK>
```

The final ZIP hash lives in the sibling `.zip.sha256` sidecar; placing it
inside the archive would be self-referential.

**Excluded, without exception:** repository source, `.gd`, `.import`,
`.godot/`, `game/tests/`, `tools/`, `art/renders/`, `design/`,
`audio_virus_prototype/`, `Godot_v*.exe`, any `.git` data, any log, any save,
and any absolute path containing a person's name. **The operator's own
`user://` data must never be packaged** — it is not in the export directory,
but a hand-assembled zip is exactly how it would get there.

---

## 5. Tester instructions (`README_TESTER.txt`, canonical source)

The only tester-facing authority is
`distribution/README_TESTER.txt`. `package_friends_build.ps1` substitutes its
build number, version and commit tokens and places that rendered copy in the
six-file payload. Do not paste a second template into this runbook: the old
duplicate outlived controller support, the production performance fix, the
microphone consent path and the default-off weather network gate.

Before every issue, the operator reads the rendered payload copy and confirms
it still covers installation, SmartScreen, current input status, the content
note, microphone consent, weather/network behavior, local files and reporting.
The release contract pins the three identity tokens and the content-note core;
human review owns the rest.

---

## 6. Update and rollback policy

1. **Numbers only ever go up.** `friends-002` never means "the same build,
   fixed".
2. **Every build ships a `BUILD_ID.txt`** and every report quotes it.
3. **Keep the previous build available** on the channel. itch/butler retain
   prior builds; do not delete the one people are using until the next is
   confirmed launchable by at least one tester.
4. **Rollback = tell people to re-download the previous number.** There is no
   automatic downgrade and none should be implied.
5. **Save compatibility is the rollback hazard**, not the binary.
   `SAVE_VERSION` is 4 with a `_migrate()` hook. A rolled-back build now refuses
   a newer save, preserves it byte-for-byte and presents a read-only warning;
   it does not silently overwrite it. If `SAVE_VERSION` changes, the older
   build must still be withdrawn rather than advertised as a usable rollback:
   refusal prevents data loss but does not make the old binary playable.
6. **Never ship two builds with the same number and different hashes.**

---

## 7. Feedback form schema

Minimum fields for an actionable report. Anything less produces "it crashed".

```
build_id            (from BUILD_ID.txt — REQUIRED)
os                  Windows version/build
cpu / gpu / ram
display             resolution + refresh + windowed/fullscreen
input_device        keyboard+mouse / controller model / touch
route_boundary      where in the shift: curb, lobby, clock-in, first report,
                    stair, 2A door, fault, repair, call, onset, dream, wake
expected            what you thought would happen
observed            what happened
reproducible        every time / sometimes / once  (+ steps)
severity            blocks me / annoying / cosmetic
screenshot_consent  may we keep and share this image internally?  Y/N
log_consent         may we ask for your log file?                  Y/N
accessibility_notes text size, captions, volume, motion comfort
audio_notes         could you tell where the fault sound came from?
time_to_fault       roughly how long from entering 2A to finding it
```

**`time_to_fault` is deliberately included**: it is the one number the sound-led
design claim rests on, and no human has ever produced it (matrix G02).

---

## 8. Security and privacy review

| Item | Finding |
| --- | --- |
| **Code signing** | **None exists.** No Windows certificate is referenced anywhere in the repository. |
| **SmartScreen** | A warning is **expected**. Microsoft documents that SmartScreen checks downloads against *"a list of files that are well known and downloaded frequently. If the file isn't on that list, [it] shows a warning"*, and that it *"provides reputation checks for apps, checking downloaded programs and the digital signature used to sign a file… If there's no reputation, the item is marked as a higher risk and presents a warning."* **[SOURCED S6]** **Buying a certificate does not remove this immediately** — reputation attaches to the certificate and must itself be established. Tell testers in advance (§5). |
| **Antivirus** | **UNKNOWN.** Third-party AV behaviour toward an unsigned Godot binary was not researched and must not be guessed. Ask the first tester. |
| **What leaves the machine** | **Only** the weather query, and **only** if the tester opts in. `live_local_weather` defaults to `false`; the in-code contract states off means fixed Queens coordinates and on means the player-authored text is geocoded, with *"No IP geolocation or device sensor"*. **No analytics, no crash reporting, no telemetry upload exists** — `attention_ledger.gd` writes nothing and sends nothing. |
| **Microphone** | **`AudioEffectRecord` and `mic_recorder.gd` capture from the microphone**, writing to `user://songbook/vocals`. Local only. **This must be disclosed to testers** — it is the single most surprising capability in the build. |
| **Player screenshots** | `user://photos/` — the player's own captures, local. |
| **Log redaction** | **UNKNOWN.** I did not audit what Godot's log contains for absolute paths or machine names. **Before asking any tester for a log, read one from a real build and check it.** Hence the explicit `log_consent` field. |
| **LICENSE** | **ABSENT.** A build handed to another person with no licence text says nothing about what they may do with it. **Owner action.** |
| **Third-party assets** | **UNKNOWN and out of scope here.** `game/assets/audio/freesound` exists; whatever attribution those licences require is an owner/legal question before any wider distribution. Flagged, not resolved. |

---

## 9. Owner-action ledger

Nothing in this column can be done by Claude or Codex.

| # | Action | Cost | Credential/secret | Blocking |
| --- | --- | --- | --- | --- |
| O1 | Decide the public product name and set `config/name` / `config/version` | — | — | artifact identity (§4) |
| O2 | Create or confirm an itch.io account and an **unlisted** project | free | account | recommended channel |
| O3 | Obtain a butler API key and store it outside the repository | free | **secret** | §3 step 10 |
| O4 | Generate and label one download key per tester | free | account | §3 step 11 |
| O5 | Supply a LICENSE or short tester EULA | — | — | §8 |
| O6 | Confirm whether the GitHub repo is private, and test one download as a non-collaborator | free | account | fallback channel |
| O7 | Decide whether to pursue Windows code signing **later** | **paid, UNKNOWN** | certificate | not blocking |
| O8 | Read the resolved `user://` path off a real machine | — | — | §5 tester readme |

> **Stop rule.** **No account is to be created, no key generated, no secret
> stored, no money spent and no agreement accepted by anyone but the owner.**
> If a step in §3 requires a credential that does not exist, the runbook stops
> at that step and says so. It does not improvise a channel.

---

## 10. Friends-build acceptance gate

Six rungs. **Each is a different claim and they are commonly conflated.**

| Rung | Means | Proved by | Today |
| --- | --- | --- | --- |
| **Exportable** | a Windows preset exists and templates are installed | export exits 0 | **YES** — isolated Windows export passed |
| **Packageable** | the output contains only what §4 permits | operator checklist 4–7 | **YES, MECHANICAL** — dry-run six-file artifact passed; shipping licence unresolved |
| **Distributable** | a channel exists with per-person access and revocation | a key issued and revoked in a test | NO |
| **Installable** | a *second* machine unzips and launches to the title screen | operator step 9 | NO |
| **Playable** | a tester reaches the first report unaided | one tester report | NO |
| **Diagnosable** | a report can be tied to an exact build and reproduced | `BUILD_ID.txt` + form + a reproduced defect | **CODE GREEN** — identity is present; real tester report/reproduction unrun |

**A build that is installable but not diagnosable wastes the cohort**, because
every report becomes unattributable. `BUILD_ID.txt` is now generated and
hash-bound. The next rung is an authorized licence plus a second-machine
install/launch rehearsal.

---

## 11. Canonical sources — reconciling G23 / G24 / G27

Named, not edited.

| Claim | Canonical source | Superseded elsewhere |
| --- | --- | --- |
| **G27** — desktop export preset | **CLOSED** by `2165c3c`/`d7530f1`. The matrix row that records it as ABSENT is **superseded**; this document §1.1 is canonical until the matrix is next revised |
| **G23** — friends channel design | **this document, §2** | the distribution plan §5 describes *Steam* channels for a later stage; it does not describe a friends build |
| **G24** — store assets and demo AppID | `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §6 | this document adds nothing to it and must not |
| **Build channels for Early Access** | distribution plan §5 (Steam branches) | **not** this runbook — §2's itch recommendation is for the friends cohort only and implies nothing about the launch channel |
| **Rollback** | distribution plan §15 for the store; **this document §6** for friends builds | the two are different mechanisms and neither replaces the other |
| **What blocks a friends build** | matrix "what can ship to friends today" | — |

**No contradiction was found between the distribution plan and this runbook.**
They address different stages; the risk is only that §2's "itch.io" is later
misread as a launch-platform decision. It is not.

---

## 12. What can be done today without owner credentials

**Ready now, no account, no secret, no spend:**

- render and inspect the canonical `distribution/README_TESTER.txt` through the
  packager; do not author a second copy here
- write the feedback form from §7
- write the packaging exclusion list from §4 as a checked script
- decide the build-number scheme and start the build log
- draft the LICENSE/EULA text for owner approval

**Blocked on Codex:** no remaining mechanical identity/export/package item.
The save-version guard from matrix G15 is implemented; its broader manual save
matrix remains separate release evidence.

**Blocked on the owner:** everything in §9.

**The honest sequence, updated:** ~~export preset → version → build identity →
mechanical package~~ **done** → owner-approved licence → one operator dry run
to the *installable* rung on a second machine → then, and only then, an owner
creating an itch project and issuing six keys.

---

## 13. Sources

All accessed **2026-08-26**. Official documentation only; no secondary articles.

| # | Page | Authority | URL | Supports |
| --- | --- | --- | --- | --- |
| S1 | About releases | GitHub | https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases | releases attach binaries; **2 GiB per asset**, up to 1000 assets |
| S2 | Managing releases in a repository | GitHub | https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository | **draft** and **pre-release** states and their meaning. **Private-repo download authentication is NOT stated on this page → UNKNOWN** |
| S3 | butler | itch.io | https://itch.io/docs/butler/ | command-line upload; *"Generate patches and apply them offline"* via Wharf; authentication section exists |
| S4 | Download keys | itch.io | https://itch.io/docs/creators/download-keys | a key is *"a special URL that gives someone access to a project's files"*; individual keys with labels; *"revoke it if necessary"* |
| S5 | Steam Playtest | Valve | https://partner.steamgames.com/doc/features/playtest | own **child AppID**; signup lives on the main game's store page; review limited to capsules and icons; **no NDA and no expectation of secrecy** |
| S6 | Microsoft Defender SmartScreen overview | Microsoft | https://learn.microsoft.com/en-us/windows/security/operating-system-security/virus-and-threat-protection/microsoft-defender-smartscreen/ | unknown files warn; reputation attaches to file/app/**certificate**; no reputation ⇒ warning |

**Repository, at `95b7a83`:** `.gitignore`; `game/export_presets.cfg`;
`game/project.godot`; `README.md`; `game/scripts/game_boot.gd`;
`game/scripts/game/reality_game_state.gd`;
`game/scripts/songbook/mic_recorder.gd`, `bar_pa.gd`;
`game/scripts/game/attention_ledger.gd`; git remote and tracked-file listing.

**Repository documents:** `EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`
(G15, G18, G23, G24, G27); `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md`
(§5, §6, §15); `CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md` (§1).

---

## What this document does not do

- It creates no account, generates no key, stores no secret, spends nothing and
  accepts no agreement.
- It runs no engine command; §3 is written to be executed, and every step that
  touches Godot is marked **UNRUN**.
- It edits no export preset, project setting or existing document.
- It does not choose the Early Access launch platform. §2 chooses a **friends
  cohort channel** and nothing more.
