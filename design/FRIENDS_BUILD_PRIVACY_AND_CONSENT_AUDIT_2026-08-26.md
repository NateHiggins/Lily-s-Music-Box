# Friends-build privacy and consent audit — 2026-08-26

**Purpose:** every capability in the friends build that reads from, writes to,
or communicates beyond the rendered game world, and the disclosure contract that
must exist before any tester receives a key.

**Base:** `d2b66f7` — the pushed `origin/main` tip at commit time. The audit
began at `d99e00b`; **origin advanced five commits during the work and one of
them changed `project.godot`**, the file two findings rest on. The branch was
moved to the new tip and both re-verified — see §0.1. **The microphone finding is
unchanged; the data-removal finding is now largely resolved.**

**No Godot was launched.** No script, scene, `project.godot`, export preset,
test, `TASKS.md` or existing document was edited.

> ## The stop rule, which governs every line below
>
> **No capability may be called absent, local, anonymous, deleted, encrypted or
> opt-in without tracing its complete production path.** Where a path ends at
> the operating system or at a third party, this document stops and says
> **UNKNOWN — MANUAL** rather than describing behaviour it has not proved.
> Two of the most important answers here are exactly that.

### 0.1 What landed mid-audit

`8d036fc` / `930e483` / `d2b66f7` gave the build a stable identity:

```diff
-config/name="Orison Apartments — Building"
+config/name="Please Remain on the Line"
+config/version="0.1.0"
+config/use_custom_user_dir=true
+config/custom_user_dir_name="PleaseRemainOnTheLine"
```

Three consequences, all in this document's favour:

1. **`config/version="0.1.0"` exists**, so a tester finally has a string to
   quote back — the identity gap this audit inherited is closed.
2. **`use_custom_user_dir=true` with an explicit `custom_user_dir_name` closes
   most of §7's UNKNOWN.** The folder is no longer derived from a name
   containing an em dash; it is the literal `PleaseRemainOnTheLine`.
3. The window title now matches what testers will be asked to test.

**`audio/driver/enable_input=true` is unchanged** (`project.godot:24,30`).
**Every microphone finding below stands exactly as written.**

**Two findings overturn the assumptions this audit began with.** They are stated
first because everything else is smaller.

1. **The build makes an outbound network request at startup and every fifteen
   minutes, whether or not the player opts in.** The "opt-in" governs *which
   coordinates are sent*, not *whether a connection happens*.
2. **Windows will not ask the tester for microphone permission, and cannot be
   asked to block us specifically.** Microsoft documents that desktop apps
   cannot be controlled per-app. **Our in-game disclosure is therefore the only
   consent mechanism that exists.**

---

## 1. The privacy ruling, in plain language

Suitable for the tester README, and true at this commit:

> **What this build does with your machine.**
>
> It fetches the weather. Every time you start it, and again every fifteen
> minutes, it asks a public weather service (Open-Meteo) what the sky is doing.
> By default it asks about a fixed spot in Queens, New York — not about you.
> **But the request still comes from your computer, so the weather service can
> see your IP address, the same as any website you visit.** If you switch on
> "live local weather" and type a place name, that place name is sent too.
>
> It can use your microphone. One optional thing in the game — a phonautograph
> in a bar, well off the main route — records singing. **Windows will not ask
> you first, because Windows does not ask desktop programs.** Nothing is
> uploaded; recordings are `.wav` files on your own disk, and you can delete
> them. If you would rather it never happened, do not use the phonautograph.
>
> It writes to your disk. Settings, one save file, screenshots you choose to
> take, and any recordings. All in this build's own folder, all yours.
>
> **It sends nothing else, anywhere, ever.** No analytics, no crash reports, no
> account, no identifier. There is no code in this build that uploads anything.

---

## 2. Capability matrix

Every capability traced to its owner and its full production path.

| Capability | Owner | Trigger | Default | Reads | Writes / sends | Destination | Persistence | Player sees | Consent | Friends ruling |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Weather fetch (fixed)** | `building/live_weather_service.gd:46,55,61` | `_ready()`, then every **900 s** via `_process` | **ON, unconditional** | fixed 40.75 / −73.92 | HTTPS GET, **plus the connection's own IP** | `api.open-meteo.com/v1/forecast` | none | **nothing** | **NONE** | **DISCLOSE + GATE** — §5 |
| **Weather fetch (player location)** | same, `:71–74,105` | as above **and** `live_local_weather` true **and** query non-empty | **OFF** | player-typed text | HTTPS GET with `?name=<uri-encoded text>` | `geocoding-api.open-meteo.com/v1/search` then the forecast endpoint | query text persists in settings | **nothing** | **opt-in toggle** | KEEP, disclose |
| **Microphone — clap calibration** | `songbook/mic_recorder.gd:70–79` | `begin_clap_check()` from `ui/songbook_panel.gd:268` | off until invoked | mic, **1.6 s** | in-memory `AudioStreamWAV`; result is one number | **stays local**; number → settings | `songbook_latency_ms` in `orison_settings.cfg` | a screen flash and "MIC CHECK" copy | **in-game only** | **GATE — §5** |
| **Microphone — performance capture** | `mic_recorder.gd:118–140` | `start_recording()` from `songbook_panel.gd:306` | off until invoked | mic, unbounded until stop | `AudioStreamWAV` | **stays local** | `user://songbook/vocals/<vid>.wav` | panel UI | **in-game only** | **GATE — §5** |
| **Songbook records** | `songbook/songbook_store.gd:36–72` | saving a version | — | player-typed lyrics, `author` (default `"you"`) | JSON | `user://songbook/<vid>.json` | permanent until deleted | panel UI | implicit | KEEP, disclose |
| **Player screenshots** | `ui/shot_capture.gd` | `shot_capture` (**F**) | off | framebuffer | PNG | `user://photos/` + `manifest.json` | permanent | the key they pressed | implicit | KEEP, disclose |
| **Save** | `game/reality_game_state.gd` | `commit()` | on | game state | JSON, `SAVE_VERSION 4` | `user://reality_maintenance_save.json` | permanent | no | n/a | KEEP |
| **Settings** | `game_boot.gd` | change + save | on | settings | cfg | `user://orison_settings.cfg` | permanent | yes | n/a | KEEP |
| **Clipboard write** | `building/light_rig.gd:295–302` | `export_tuning()` from `ui/building_debug.gd:582` | off | lighting tuning | **overwrites the system clipboard** | the OS clipboard | until overwritten | no | none | **DISABLE for friends — §5** |
| **Lighting export** | same | same | off | tuning | JSON | `user://orison_lighting_settings.json` | permanent | printed path | none | disable with the above |
| **Debug panel** | `ui/building_debug.gd:717` | **F1**, **no debug-build guard** | reachable | — | — | — | — | on screen | none | **DISABLE for friends — §5** |
| **Noclip** | `player_controller.gd:352` | **V** | reachable | — | — | — | — | movement changes | none | **DISABLE for friends** |
| **Environment reads** | 106 sites | env vars at boot | — | `DAYNIGHT`, `DREAM_*`, `ENCROACH*`, `WEATHER_SIMULATE`, … | **nothing** | — | — | no | n/a | KEEP — reads only |
| **Attention ledger** | `game/attention_ledger.gd` | play | on | play time | **nothing to disk, nothing sent** | — | none | no | n/a | KEEP |

### Capabilities searched for and **NOT FOUND** in production

Traced by whole-record search across `game/scripts`, not truncated output:

**No** `WebSocket`, `PacketPeer`, `StreamPeerTCP`, `UDPServer`, `TCPServer`.
**No** `OS.execute`, `OS.create_process`, `OS.shell_open` — nothing launches a
process or opens an external URL. **No** `OS.get_unique_id`. **No** camera.
**No** analytics, telemetry upload, crash reporter, Sentry/Crashpad/Breakpad.
**No** account, login or identifier of any kind.
**No** `res://` writes — `res://` is read-only in an exported build and every
`FileAccess.open("res://…")` in the tree is a data read.
**One** `HTTPRequest` in the whole codebase (§4). **One** clipboard write.
**One** microphone chain.

*(A grep for `IP.` returns eleven hits; **all eleven are the word `OWNERSHIP.`
in comments**. There is no use of Godot's `IP` class anywhere.)*

---

## 3. The microphone, end to end

**Can the build open the microphone?** **Yes.**
`game/project.godot:21,27` sets `[audio] driver/enable_input=true`, and
`mic_recorder.gd:52–54` reads exactly that setting to decide `available`.

**The complete chain:**

```
props/songbook_terminal_prop.gd      the phonautograph in the Harukiya
  :34  "Interact opens the Songbook panel"
  :145 load("res://scripts/ui/songbook_panel.gd")
        │
ui/songbook_panel.gd
  :265 _mic = MicRecorder.new()          ← constructed on panel open
  :268 _mic.begin_clap_check()           ← MIC CHECK calibration
  :306 _mic.start_recording()            ← performance capture
  :362 _take = _mic.stop_recording()
        │
songbook/mic_recorder.gd
  :52  available = ProjectSettings.get_setting("audio/driver/enable_input")
  :41  _mic_player.stream = AudioStreamMicrophone.new()
  :58  start_input()  →  _mic_player.play()      ← THE DEVICE OPENS HERE
  :70  begin_clap_check()  → set_recording_active(true), 1.6 s window
  :118 start_recording()   → set_recording_active(true), until stopped
  :129 stop_recording()    → get_recording(), stop_input(), trim head
        │
songbook/songbook_store.gd
  :43  vocal_path = "user://songbook/vocals/<version_id>.wav"
  :44  vocal.save_to_wav(vocal_path)
```

**Exactly when:** only after a player walks into the Harukiya, interacts with
the phonautograph, and then either runs the MIC CHECK or presses record. **It is
off the release route** — the Harukiya is an optional delight under the scope
audit's content ceiling. **It cannot begin at startup**: `start_input()` is the
only caller of `_mic_player.play()`, and nothing calls it before the panel is
opened.

**Visible indication:** in-game only — the MIC CHECK flash and the panel's own
recording UI. **There is no OS-level guarantee** (see below).

**Where audio stays:** in memory as `AudioStreamWAV`, then written as a **`.wav`
under `user://songbook/vocals/`** named by version id. **Nothing uploads it** —
there is no network code anywhere near this chain, and the build's only HTTP
client is the weather service.

**How the player deletes it:** by deleting the files. **There is no in-game
delete.** That is a gap, not a feature.

**Can recording begin accidentally or before disclosure?**
**Not by walking around** — the chain requires an explicit interact and an
explicit panel action. **But two hazards remain:**

1. **UNKNOWN — MANUAL:** whether `enable_input=true` causes Godot to open the
   input device at *engine startup* rather than at `play()`. Godot's
   `AudioStreamMicrophone` page says only that the setting "must be `true` for
   audio input to work" and notes "caveats related to permissions and operating
   system privacy settings" without stating when the device opens **[S1]**. If
   it opens at startup, a Windows in-use indicator could appear before the
   player has done anything. **This must be checked on a real Windows machine
   before a key is issued.**
2. **The MIC CHECK is the first thing the panel does**, so a curious tester who
   opens the phonautograph may be recorded 1.6 s later, having read nothing.

**And the consent backstop does not exist.** Microsoft documents that
**"Camera privacy settings for desktop apps can't be changed at an individual
desktop app level"** and that **"Desktop apps might not appear in the list of
apps"** **[S3]**. A Godot desktop build is a classic desktop app.
**Therefore Windows will not prompt the tester, and the tester cannot block this
build specifically without disabling microphone access for every desktop
program.** Our disclosure is not a courtesy on top of an OS prompt — **it is the
only consent that will happen.**

---

## 4. Weather and network, end to end

```
building/building_root.gd:741   live_weather = LiveWeatherServiceScript.new()
        │                        ← constructed in the PRODUCTION root
building/live_weather_service.gd
  :46  _ready():  … add_child(_request);  refresh()      ← FIRES AT STARTUP
  :55  _process(): _refresh_left -= delta; if <= 0 → refresh()
  :22  REFRESH_SECONDS = 15.0 * 60.0                     ← every 900 s
  :65  if WEATHER_SIMULATE matches a preset → no request at all
  :71  local_enabled = settings["live_local_weather"]     (default FALSE)
  :72  query         = settings["weather_location_query"] (default "")
  :73  if local_enabled and query:  _begin_request("geocode", geocode_url(query))
  :76  else:                        _begin_request("weather", weather_url(40.75, -73.92))
  :82  _request.request(url)
```

**Endpoints (constants at `:19–20`):**
`https://geocoding-api.open-meteo.com/v1/search`
`https://api.open-meteo.com/v1/forecast`

### The distinction the existing prose does not make

`game_boot.gd:40–44` states: *"off means only fixed Queens coordinates are sent
for weather… No IP geolocation or device sensor is used behind this choice."*
**Both halves are true**, and together they are easy to misread.

- **We do not perform IP geolocation.** True — no such code exists.
- **We do send fixed coordinates rather than the player's.** True.
- **But the request happens anyway**, at startup and every fifteen minutes, with
  the toggle off. **The default is not "no network". It is "a network request
  with somebody else's coordinates."**
- **And an HTTPS request necessarily exposes the client's IP address to the
  provider.** A player who leaves the toggle off *specifically to protect their
  location* still reveals coarse location to Open-Meteo — not because we send
  it, but because the connection is made from their machine.

**We may not write "nothing leaves your machine unless you opt in."** The honest
sentence is in §1: *the request still comes from your computer, so the weather
service can see your IP address, the same as any website you visit.*

**Caching, fallback, logs:** the snapshot is held in memory (`_snapshot`); on
failure `_fail()` is called and the game continues on simulated weather.
**Nothing about the request is written to `user://`.** The only persisted
weather data is the player's own `weather_location_query` text.

**UNKNOWN — MANUAL:** what a failed request prints to the Godot log, and whether
that text includes the URL (and therefore a player-typed place name). **Read a
real log before asking any tester to send one.**

---

## 5. Production reachability rulings

Recommendations. **Nothing is implemented here.**

| Capability | Ruling | Reason |
| --- | --- | --- |
| **Weather at startup, fixed coords** | **GATE + DISCLOSE** | Offer a genuine "no network at all" state. Simplest honest shape: a third setting value, or treat an empty consent as "use simulated weather". A tester who wants zero egress currently has no way to get it except unplugging. |
| Weather with player location | **KEEP, disclose** | Already opt-in and already default-off. Correct as built. |
| **Microphone** | **GATE for the friends build** | Either make the phonautograph refuse to record until the tester accepts a just-in-time notice (§6), **or** ship friends builds with the Songbook unreachable. **Owner decision — §10 O1.** |
| Songbook lyric/version records | KEEP, disclose | Player-authored text on the player's own disk. |
| Player screenshots | KEEP, disclose | Player-initiated. Note the debug-label hazard in §8. |
| Save, settings | KEEP | Ordinary. |
| **Clipboard write** | **DISABLE for friends** | `export_tuning()` silently overwrites the tester's clipboard. Reachable only via the debug panel — disabling that disables this. |
| **Debug panel (F1)** | **DISABLE for friends** | No `OS.is_debug_build()` guard exists. It exposes developer tooling and the clipboard write to a tester. |
| **Noclip (V)** | **DISABLE for friends** | A single keypress silently invalidates any bug report that follows it. |
| Environment reads | KEEP | Reads only; nothing egresses. Worth knowing that a friends build's behaviour can still be altered by env vars. |
| Attention ledger | KEEP | Writes nothing, sends nothing. |

---

## 6. Proposed disclosure copy

**First-launch notice** — shown once, before the title menu, dismissible with
one key. No legalese, no claim about OS behaviour we have not proved:

```
BEFORE YOU START

This is a test build. Two things about your computer:

THE WEATHER IS REAL.
When the game starts, and every fifteen minutes after, it asks a public
weather service what the weather is doing. By default it asks about a
fixed spot in Queens, New York — not about where you are. The request
comes from your computer, so that service can see your IP address, the
same as any website. You can turn on "live local weather" in Building
Services and type your own location if you'd rather the sky matched
yours.

THERE IS A MICROPHONE FEATURE.
One optional thing — a phonautograph in a bar — records singing. It
won't turn on by itself, and you have to go and use it. Recordings are
files on your own disk and are never uploaded. Windows may not ask you
about this, so we are asking instead.

Nothing else leaves your computer. No accounts, no analytics, no
crash reports.

                                            [ Enter ] I've read this
```

**Just-in-time microphone notice** — first time the phonautograph panel opens,
**before** the MIC CHECK runs:

```
THE PHONAUTOGRAPH LISTENS

To record you, this needs your microphone. It starts with a short
"clap when the screen flashes" check, about a second and a half.

Recordings are saved as .wav files in this build's own folder on your
disk. Nothing is uploaded. Nothing is sent anywhere.

To delete them later, delete the files — the path is in BUILD_ID.txt.
There is no in-game delete yet.

           [ Use the microphone ]      [ Not this time ]
```

**"Not this time" must be a real refusal** — the panel stays usable for playback
and the mic is never opened. `mic_recorder.gd:52–56` already models exactly this
shape for the case where the OS withholds input: *"An input device the OS will
not give us is a fact, not a failure: the Songbook stays usable, it just cannot
record you."* **The consent path should reuse that behaviour rather than invent
a new one.**

---

## 7. Tester data-removal guide

| What | Path | Status |
| --- | --- | --- |
| Settings (incl. weather consent and query) | `user://orison_settings.cfg` | **PROVED** from source |
| Save | `user://reality_maintenance_save.json` | **PROVED** |
| Lighting export | `user://orison_lighting_settings.json` | **PROVED** |
| Screenshots + manifest | `user://photos/` | **PROVED** |
| Songbook records | `user://songbook/*.json` | **PROVED** |
| **Voice recordings** | `user://songbook/vocals/*.wav` | **PROVED** |
| **The user-data folder name** | `PleaseRemainOnTheLine` | **PROVED** — `config/use_custom_user_dir=true`, `config/custom_user_dir_name` |
| **The absolute parent path on Windows** | — | **UNKNOWN — one lookup, not a guess** |
| Godot log location and contents | — | **UNKNOWN** |

**This improved mid-audit.** `use_custom_user_dir=true` and
`custom_user_dir_name="PleaseRemainOnTheLine"` are now set, so the folder name
is explicit rather than derived from a `config/name` containing an em dash.
**The name is proved; the absolute parent path is still an OS detail I have not
verified.**

> **An operator still needs one lookup:** launch the exported build once, read
> the absolute path, and paste the literal string into the tester README. That
> is now a confirmation rather than an investigation.

**Deleting the game folder does not delete any of the above.** The tester README
must say so plainly (it already does, in the distribution runbook §5).

---

## 8. Threat and trust review

| # | Risk | Assessment |
| --- | --- | --- |
| T1 | **Accidental recording** | Low by walking, real by curiosity: the MIC CHECK is the panel's opening move, so a tester who opens the phonautograph is recorded seconds later having read nothing. §6's just-in-time notice is the fix. |
| T2 | **Recording before disclosure at startup** | **UNKNOWN — MANUAL.** Depends on whether `enable_input=true` opens the device at engine start (§3, S1). Must be checked on Windows before any key is issued. |
| T3 | **Sensitive filenames** | Low. Recording names are generated version ids, not player text. Songbook JSON contains **player-authored lyrics** and an `author` field defaulting to `"you"` — if a tester types their name, it is on their own disk only. |
| T4 | **Logs** | **UNKNOWN.** Whether a failed weather request logs the URL — and therefore a player-typed place name — is unverified. **Read a log before requesting one.** The runbook's `log_consent` field exists for this reason. |
| T5 | **Screenshots with debug labels** | **REAL AND CURRENT.** 2A renders world-space case labels and seven interactive debug lights (evidence matrix G18). A tester screenshot attached to a bug report will contain them, and those reports may be forwarded. Not a privacy leak — a credibility one. |
| T6 | **Location query leakage** | The player's typed text goes to Open-Meteo by design and by consent. The unconsented part is the IP exposure that happens **anyway** with the toggle off (§4). |
| T7 | **Shared machines** | Saves, settings, screenshots and recordings sit in a per-user app-data folder with no in-game protection. On a shared login, a housemate can hear a tester's recordings. Worth one sentence in the README. |
| T8 | **Report attachments** | Screenshots (T5), logs (T4) and `.wav` recordings could all be attached to a report. The feedback form already asks for screenshot and log consent separately; **it should ask about recordings too, or say we will never request them.** |
| T9 | **Clipboard clobber** | Low but rude: F1 → export tuning silently replaces whatever the tester had copied. Disabling the debug panel removes it. |

---

## 9. Acceptance tests for Codex

**Automated — code assertions, no OS or human needed:**

| # | Assertion |
| --- | --- |
| A1 | `MicRecorder.available` is `false` when `audio/driver/enable_input` is false, and `start_recording()` returns `false` without opening a stream |
| A2 | No `AudioStreamPlayer` with an `AudioStreamMicrophone` stream is `playing` after a production-root boot with no Songbook interaction |
| A3 | With `live_local_weather=false`, the request URL equals `weather_url(40.75, -73.92)` exactly and contains no player-authored substring |
| A4 | With `live_local_weather=true` and a query, the first request is the **geocode** endpoint and the query is `uri_encode`d |
| A5 | A static scan asserts the production script set contains exactly **one** `HTTPRequest`, and **zero** `WebSocket`/`TCP`/`UDP`/`OS.execute`/`OS.create_process`/`OS.shell_open` |
| A6 | Declining the microphone notice leaves the Songbook panel functional and never calls `start_input()` |
| A7 | A "no network" weather state, if adopted (§5), issues **zero** requests across a boot plus one refresh interval |
| A8 | The debug panel and noclip are unreachable in an export-configured build, if that gating is adopted |

**Manual — a human on real Windows, because no assertion can prove these:**

| # | Check |
| --- | --- |
| M1 | **Launch the exported build and do nothing.** Does Windows show a microphone-in-use indicator? Does the build appear under microphone privacy settings at all? (T2, S3) |
| M2 | Open the phonautograph. Does an indicator appear *then*, and does the notice precede the MIC CHECK? |
| M3 | Confirm the absolute path of the `PleaseRemainOnTheLine` user-data folder and paste it verbatim into the tester README (§7) |
| M4 | Force a weather failure (network off) and **read the log**. Does it contain the URL or a typed place name? (T4) |
| M5 | Confirm the game is playable start to finish with the network unplugged |
| M6 | Delete every path in §7 and confirm the build starts clean |

---

## 10. Owner decisions required before the friends build

| # | Decision | Why it cannot wait |
| --- | --- | --- |
| **O1** | **Is the Songbook microphone reachable in the friends build at all?** Keep with a just-in-time notice, or make the phonautograph unreachable for this cohort. | It is the only capability that opens hardware, it sits off the release route, and Windows will not ask on our behalf (§3). |
| **O2** | **Do we offer a true "no network" state?** Today, opting out only changes the coordinates. | A tester who asks "can I stop it phoning out?" currently has no answer but "unplug" (§4, §5). |
| **O3** | Ship the first-launch notice (§6), or put the same text in the README only? | A notice inside the build reaches whoever runs it; a README reaches whoever reads it. |
| **O4** | Disable the debug panel, noclip and the clipboard write for friends builds? | Each silently invalidates or annoys (§5). |
| **O5** | Will we ever ask a tester for a `.wav`, a log or a screenshot? | Decide before asking, and say so in the form (T8). |

---

## 11. Canonical sources

Named, not edited.

| Claim | Canonical | Note |
| --- | --- | --- |
| **What leaves the machine** | **this document §2, §4** | Supersedes the shorter summaries. `game_boot.gd:40–44` remains correct as far as it goes; it does not mention the unconditional request or IP exposure. |
| **Microphone capability and chain** | **this document §3** | The distribution runbook §8 flagged it correctly but did not trace reachability or the Windows consent gap. |
| Tester-facing privacy copy | `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` §5 **as amended by §6 here** | The runbook's weather paragraph says "Nothing else leaves your machine", which is true of *content* but should carry the IP sentence. **Reported, not edited.** |
| Data-removal paths | **this document §7** | Runbook §5 points at BUILD_ID.txt; §7 supplies the list and marks the unproved part. |
| Channel and distribution | runbook §2 | Unchanged. |
| Store privacy/telemetry posture | `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §12 | Consistent: it recommends shipping with no telemetry, and §2 here confirms none exists. |
| Weather gate status | `EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md` G22 | This document supplies the detail G22 asked for and **sharpens it**: G22 said "privacy claim"; the claim needs the IP sentence to be true. |

**No contradiction was found.** The gap is one of emphasis: existing prose is
accurate about *what we send* and silent about *that we connect at all*.

---

## 12. Sources

Official documentation only, accessed **2026-08-26**.

| # | Page | Authority | URL | Supports |
| --- | --- | --- | --- | --- |
| S1 | `AudioStreamMicrophone` | Godot | https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html | plays microphone input in real time; `audio/driver/enable_input` "must be `true` for audio input to work"; notes "caveats related to permissions and operating system privacy settings" **without stating when the device opens → T2 UNKNOWN** |
| S2 | `ProjectSettings` | Godot | https://docs.godotengine.org/en/stable/classes/class_projectsettings.html | consulted for the full `audio/driver/enable_input` text; **the description was not retrievable from the page fetched — recorded as UNKNOWN rather than paraphrased** |
| S3 | Manage app permissions for your camera | Microsoft | https://support.microsoft.com/en-us/windows/manage-app-permissions-for-your-camera-in-windows-87ebc757-1f87-7bbf-84b5-0686afb6ca6b | **"Camera privacy settings for desktop apps can't be changed at an individual desktop app level"**; **"Desktop apps might not appear in the list of apps"**. The page covers camera; **whether microphone indicators behave identically is UNKNOWN → M1** |
| S4 | Privacy policy | itch.io | https://itch.io/docs/legal/privacy-policy | itch.io itself collects "traffic data, location data, logs… IP address, and browser type". **What a developer sees about a download-key user is NOT stated → UNKNOWN** |

**Repository at `d99e00b`:** `game/project.godot:21,27`;
`game/scripts/building/live_weather_service.gd:13–24,46–82,105–112`;
`game/scripts/building/building_root.gd:741`;
`game/scripts/songbook/mic_recorder.gd`; `songbook/bar_pa.gd:90–101`;
`songbook/songbook_store.gd:17–72`; `ui/songbook_panel.gd:265–362`;
`props/songbook_terminal_prop.gd:34,145`; `building/light_rig.gd:295–302`;
`ui/building_debug.gd:582,717`; `player/player_controller.gd:352`;
`ui/shot_capture.gd`; `game/reality_game_state.gd`;
`game/attention_ledger.gd`; `game_boot.gd:40–56`.

---

## What this document does not do

- It implements nothing, gates nothing and disables nothing. §5 recommends.
- It asserts no OS permission behaviour it did not verify — T2, M1 and the
  `enable_input` timing question are left **UNKNOWN — MANUAL** on purpose.
- It edits no existing document; §11 names canonical sources instead.
- It does not describe any capability as absent, local or opt-in without the
  path in §2 to back it.
