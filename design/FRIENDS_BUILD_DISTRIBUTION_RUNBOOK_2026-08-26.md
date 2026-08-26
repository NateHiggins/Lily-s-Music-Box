# Friends-build distribution runbook — 2026-08-26

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
| Build/packaging infrastructure | **NONE.** `build/` is gitignored (`.gitignore:35`) and does not exist. No packaging script, no `Makefile`, no `justfile`. |
| CI | **NONE.** There is no `.github/` directory at all — no workflows, no Releases automation, no issue templates. |
| Git remote | `https://github.com/NateHiggins/Lily-s-Music-Box.git`. **The repository name does not match the game.** Whether it is private is **UNKNOWN** from tracked files. |
| Versioning | **ABSENT.** `game/project.godot` sets `config/name="Orison Apartments — Building"` and **no `config/version`**. A tester today has no string to quote back. |
| Naming | `config/name` is neither "Please Remain on the Line" nor "Orison". Whatever the window title is, it will not match what you asked people to test. |
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
3. **The export name is already `PleaseRemainOnTheLine.exe`**, which settles the
   executable half of §4 and makes O1 narrower — the *window title* still comes
   from `config/name`, which is still `"Orison Apartments — Building"`.

**The engine-side exclude filter does part of §4's job**, covering `tests/*`,
`docs/*`, source audio and source sky textures. It does **not** replace the
operator check: the filter governs what enters the `.pck`, while §4 step 5
governs what a human puts in the **zip**, which is where `Godot_v*.exe`, a log
or a personal path would arrive.

**Still absent:** `config/version`. **The identity problem is unchanged and it
remains the lowest rung of §10.**

### What a tester leaves on their machine

Every `user://` path written by production code:

```
user://orison_settings.cfg              settings, incl. weather consent
user://reality_maintenance_save.json    the save (SAVE_VERSION 4)
user://orison_lighting_settings.json    lighting prefs
user://photos/ + manifest.json          screenshots the PLAYER takes
user://songbook/ + songbook/vocals      MICROPHONE RECORDINGS
```

`use_custom_user_dir` is **not** set, so `user://` resolves to Godot's default
per-project location under the user's app data. **UNKNOWN:** the exact resolved
folder name on Windows — it derives from `config/name`, which contains an em
dash, and I did not verify how Godot sanitises that. **An operator must read the
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

The current build renders debug nameplates and seven interactive debug lights
inside 2A (matrix G18), cannot be played with a controller (G07), and has a
route no human has walked unaided (G01). **A channel with no expectation of
secrecy is exactly the wrong place for that build**, regardless of where the
game eventually ships.

### Refused: **direct cloud links** (Drive/Dropbox/WeTransfer)

No revocation once forwarded, no build identity, no update path, no download
record, and the recipient still meets the SmartScreen warning with none of the
context a store page provides.

---

## 3. Operator checklist — clean checkout to uploaded artifact

**Every engine/export command below is UNRUN.** I may not launch Godot, so
each is written to be executed and verified by the operator, not quoted as done.

**Precondition: SATISFIED** as of `2165c3c`/`d7530f1`. A `Windows Desktop`
preset exists. What remains unproven is that it *exports cleanly on a clean
checkout with templates installed* — step 2 and step 3 below, both **UNRUN**.

```
 0. PRECONDITION   Windows preset: DONE (a7d6114)
                   config/version: STILL ABSENT                  [OWNER/CODEX]

 1. CLEAN CHECKOUT git clone <remote> --branch main <tmp>
                   verify: git rev-parse HEAD  == the SHA you intend to ship
                   verify: git status --porcelain is EMPTY
                   (do NOT build from the shared worktree; 251 dirty files
                   live there and none of them belong in an artifact)

 2. TEMPLATES      confirm Godot 4.7.1 export templates are installed   UNRUN
                   (an export silently fails or produces a broken binary
                   without them)

 3. EXPORT         godot --headless --path game --export-release \
                     "Windows Desktop" ../build/windows/<artifact>/<exe>  UNRUN

 4. VERIFY EXE     the output directory contains exactly the executable and
                   its .pck (or a single embedded-PCK executable), and
                   nothing else                                        UNRUN

 5. STRIP          confirm NO: source, .gd, .import, .godot/, tests, tools/,
                   art/renders/, design/, audio_virus_prototype/,
                   Godot_v*.exe, logs, .git, personal paths in any string

 6. ADD            README_TESTER.txt (§4), LICENSE-or-EULA (§8 owner action),
                   BUILD_ID.txt containing: version, git SHA, UTC build time,
                   preset name, Godot version

 7. PACKAGE        zip the directory (§4 naming). Do not ship a bare .exe:
                   a zip preserves the folder and makes the readme unavoidable

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
```

`<NNN>` is a monotonic friends-build number starting at `001`. It never resets
and never reuses a number, even for a rebuild of the same commit.

**Executable / PCK relationship.** Either a separate `.pck` beside the `.exe`,
or a single embedded-PCK executable. **Both are acceptable; mixing is not** —
a stale `.pck` beside a new `.exe` is a bug report you will not be able to
reproduce. If separate, they ship in the same zip and are never distributed
apart.

**Identity visible to the tester — currently impossible.** `config/version` is
absent, so there is **no version string in the build today**. Until Codex sets
one, `BUILD_ID.txt` is the only identity, and it must contain:

```
build      friends-001
version    <config/version once it exists>
commit     <full 40-char SHA>
built      <UTC ISO-8601>
preset     Windows Desktop
engine     Godot 4.7.1
sha256     <of the zip>
```

**Excluded, without exception:** repository source, `.gd`, `.import`,
`.godot/`, `game/tests/`, `tools/`, `art/renders/`, `design/`,
`audio_virus_prototype/`, `Godot_v*.exe`, any `.git` data, any log, any save,
and any absolute path containing a person's name. **The operator's own
`user://` data must never be packaged** — it is not in the export directory,
but a hand-assembled zip is exactly how it would get there.

---

## 5. Tester instructions (`README_TESTER.txt`, verbatim template)

```
PLEASE REMAIN ON THE LINE — friends build <NNN>
Commit <shortsha>.  Not for redistribution.

INSTALL
  Unzip the whole folder somewhere you can find again.
  Run PleaseRemainOnTheLine.exe from inside that folder.
  Do not move the .exe out on its own.

FIRST LAUNCH — WINDOWS WILL WARN YOU
  This build is NOT code-signed. Windows SmartScreen will likely show
  "Windows protected your PC" because the file has no established
  reputation. That warning is expected for a build like this one.
  Only continue because you trust where you got it from.
  If you are not comfortable, tell us and we will not think less of you.

WHAT WORKS
  Keyboard and mouse.  WASD move, mouse look, E interact, L lamp,
  R radio, Shift run, C crouch, Esc opens Building Services.

WHAT DOES NOT WORK
  CONTROLLERS ARE NOT SUPPORTED. Only two shoulder buttons are bound;
  you cannot move or look with a gamepad. Please do not report this.
  Touch is untested.

KNOWN AND ALREADY REPORTED — please do not file these
  - floating labels and small light handles inside apartment 2A
  - performance dips in the lobby and on the second-floor landing
  - no subtitle size or controller options

MICROPHONE
  One optional feature can record from your microphone. Recordings stay
  on your machine. If you would rather not, decline the OS prompt or
  avoid that activity, and it will not be used.

WEATHER AND THE INTERNET
  Live local weather is OFF by default. If you turn it on, the location
  text YOU type is sent to a weather service. Nothing else leaves your
  machine. No IP geolocation, no device sensors, no analytics.

WHERE YOUR FILES LIVE
  Settings, save, screenshots and any recordings are stored in this
  build's own app-data folder. The exact path is printed in
  BUILD_ID.txt.

REPORTING A PROBLEM
  Use the form in the message we sent you. The build number and your
  hardware are the two fields we most need.

REMOVING IT
  Delete the folder you unzipped. That removes the game.
  It does NOT remove your settings, save, screenshots or recordings —
  those live in the app-data folder above and must be deleted
  separately if you want them gone.
```

*(The tester-facing readme must state the resolved app-data path literally.
Read it off a real machine first — see §1 UNKNOWN.)*

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
   `SAVE_VERSION` is 4 with a `_migrate()` hook, and **there is no guard
   preventing an older build from loading a newer save**
   (matrix G15). **Therefore: if `SAVE_VERSION` changes between two friends
   builds, the older one must be withdrawn, not offered as a rollback**, and
   testers told to keep a copy of their save before updating.
6. **Never ship two builds with the same number and different hashes.**

---

## 7. Feedback form schema

Minimum fields for an actionable report. Anything less produces "it crashed".

```
build_id            (from BUILD_ID.txt — REQUIRED)
os                  Windows version/build
cpu / gpu / ram
display             resolution + refresh + windowed/fullscreen
input_device        keyboard+mouse / other (note: controller unsupported)
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
| **Exportable** | a Windows preset exists and templates are installed | export exits 0 | **PRESET YES** (`a7d6114`); templates and a clean export **UNRUN** |
| **Packageable** | the output contains only what §4 permits | operator checklist 4–7 | NO |
| **Distributable** | a channel exists with per-person access and revocation | a key issued and revoked in a test | NO |
| **Installable** | a *second* machine unzips and launches to the title screen | operator step 9 | NO |
| **Playable** | a tester reaches the first report unaided | one tester report | NO |
| **Diagnosable** | a report can be tied to an exact build and reproduced | `BUILD_ID.txt` + form + a reproduced defect | **NO — no version string exists** |

**A build that is installable but not diagnosable wastes the cohort**, because
every report becomes unattributable. `BUILD_ID.txt` is the cheapest rung on this
ladder and it is currently the missing one.

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

- write `README_TESTER.txt` from §5 (the copy is drafted; only the resolved
  app-data path is missing)
- write the feedback form from §7
- write the packaging exclusion list from §4 as a checked script
- decide the build-number scheme and start the build log
- draft the LICENSE/EULA text for owner approval

**Blocked on Codex:** `config/version` (the Windows preset landed mid-audit),
and — before any *second* build — the save-version guard from matrix G15.

**Blocked on the owner:** everything in §9.

**The honest sequence, updated:** ~~export preset~~ **done** → `config/version`
and `BUILD_ID.txt` → one operator dry run to the *installable* rung on a second
machine → then, and only then, an owner creating an itch project and issuing six
keys.

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
