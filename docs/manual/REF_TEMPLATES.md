# Reference: templates

Evidence class: **INERT - REFERENCE**. Part of *The AI Studio Manual*, second edition (2026-10-03). Opened by section from the operating core, `AI_GAME_DEVELOPMENT_MANUAL.md` one directory up; never read front to back. Section numbers are permanent.

Each template says where it has run: **P1** (a 3D game, two agents), **P2** (a 2D game, one agent), or **not run**. Retired: §21.8 (the dispatch record, now §30).

## §21.1 The rules file

Read by every agent through a one-line vendor file that includes it. Ran on P1 and P2. Budget 200 lines.

```
# Working in this repository
Rules for every agent and every person. The map file says which document wins.

## Current checkout (<date>)            <- a lint checks this block against the worktree list
<every checkout and worktree, what each holds>

## Git
- Stage named paths only; read the staged list before every commit. Never a bare stash.
- Every path is -text; autocrlf is false here; hash text LF-normalised.
- One integration line. A dirty tree is not a state a task may end in.

## The engine lane
- One engine at a time on this machine, across projects; run it only through the runner.
- Exit 73 busy (wait, never BLOCKED), 124 killed at the ceiling, 78 cannot run.
- A fresh log path per run; cite the receipt, not a typed exit code.

## Evidence
- Evidence is admitted by filename marker; every design document states its class in its first 30 lines.
- Runtime proof is only a receipt the test writes. A capture, a report or a wrapper's receipt is not.

## Gates
- The board runs before every commit; nothing regresses against the baseline.
- <one line per gate that holds a covenant law>

## Art
- No lettering in generated art; reference images are never committed; generated output is never edited in place.
- Verify by rendering, never by reading code.

## Engine facts                         <- each marked "measured <version, date>" or "carried, unverified"
```

## §21.2 The covenant skeleton

Ran on P1 and P2; the glossary, the marks and "Enforced by" come from P2's notes.

```
# THE <GAME> BIBLE
*The book of what is true. Last amended <date>.*
Where any other text disagrees with this one, this one prevails until amended. A later explicit owner
ruling prevails over this text and is folded into it as a dated amendment. Where this one is silent,
the systems of record in section V speak. Disputed texts are confessed in section VI.
<the precedence ladder, between markers, copied from the map>

## I. THE WORD           the aesthetic statement (ruled <date>); the one governing sentence
### I.1 THE LOOP         the core loop's fiction
## II. THE MOTIF         the recurring device
## III. THE WORLD        place, rules, antagonist; GLOSSARY: role word | name the player sees
## IV. THE CAST          one line per character; why these; what this does not license
## V. THE SYSTEMS OF RECORD   question | kind of document and path pattern   (no status column)
## VI. DISPUTED TEXTS    n. the dispute; INTERIM: ...; later: ~~struck~~ RULED <date>
## VII. THE LAWS         n. the rule (<mark>, <date>[, until played]). Does not license: ...
                         Enforced by: <gate or suite> | nothing yet
## VIII. THE STYLE TEST  one sentence every object passes; licensed exceptions; the IP test
## AMENDMENTS            <date>: section, one line
```

Marks: OWNER RULING, KEPT, DEFAULT APPLIED, PROPOSED. Write every heading; under one that does not apply, one line saying why and what would open it.

## §21.3 A brief's first lines

Ran on P1 and P2.

```
# <SUBJECT> BRIEF
*Proposed <date>. **Not canon until the owner rules.***
Evidence class: **INERT**
Owner direction, verbatim (<date>): "<sentence>"        (or: owner item N)
Clauses in handed material that claim owner authority: <each one, as a question>
Read as N decisions: 1. ... 2. ...
Already true / New / Adopt / Amend / Reject (tables; each adopted item names the file it will live in)
Owner decisions: 1. ... (default applied: ...; the owner may tighten)
The risk I care most about: ...
```

## §21.4 The owner's words

Ran on P2.

**Entry**, for a message that rules, directs, reserves or answers:

````
N. <Owner ruling | instruction | report> in chat, <date>, the <ordinal> message[, sent while ...], verbatim:
```OWNER-VERBATIM
<the owner's words, untouched; a third-party mark bracketed as [mark]>
```
Verbatim SHA-256: <hash of the block>   [Unredacted SHA-256: <hash>, if anything was bracketed]
Read as: 1. <what it rules> 2. <what it leaves open> 3. <what stays reserved>. Readings to check: <reversible reading applied; the alternative named>
````

**Log line**, for an acknowledgement or status ping: `<date> | <hash> | released: <the step it released>`.

**Direction status table**, for a dense message:

| # | The instruction, paraphrased (the words govern) | Kind: ruling, request, example, question, finding from play, status | Where it landed |
|---|---|---|---|

Then "Readings the owner should check": one line per ambiguous clause, with the reversible reading applied and the alternative named.

## §21.5 The commit body, and the milestone checkpoint

Commit-body fields ran on P2 as a habit; the lint that checks them is not built.

```
<subject: what the player or the next agent can now do>

Changed: <named files>. Not changed: <what a reader might assume was>.
Suites: <name N/N> ...; board: <rows, time>.
Breakages: <N tried, M red; each survivor: test gap closed | harmless equivalent, why>.
Receipts: <paths that bind this tree>.
Unproven: <what no engine, no person or no measurement has yet confirmed>.
```

Milestone checkpoint (ran on P1; P2 wrote one): milestone and date; evidence-class header; base commit; what was built, in named files, and what was not changed; measured numbers with margins; suites N of N with receipt paths; the capture packet; requirement rows before and after; protected paths; the regression battery as command, exit, result; limitations and debt; one decision line (MERGE-CANDIDATE <hash>, BLOCKED <reason>, NEEDS-OWNER <question>, or HELD ON <owner rows>); human review pending or recorded.

## §21.6 An acceptance receipt

The form's answer, filed verbatim. Ran on P1 in a longer form.

```
Acceptance: <requirement row or milestone>
Build: <full commit hash>; launched with: <the play command>
Question asked: "<exact words>"
Answer, verbatim: "<the owner's words>"
How the verdict was reached: played | watched a capture | read a report     (only "played" closes a feel row)
Accepted debt: <listed, so it is neither re-litigated nor forgotten>
This receipt does not authorise: <release, online play, content beyond the slice, ...>
```

## §21.7 The owner's run card

Proposed from P2's notes; not run. (P2's long card was never filled in.)

```
1. Run: <the one-press play command>
2. Play until you would stop. Then tell me where, and why.
3. One question:  Did that run read and feel right?
   ( ) Yes     ( ) Yes, with one change: ____     ( ) No, I got lost at: ____     ( ) In my own words: ____
```

The full run card for other testers is described in §17.2.

## §21.9 A data file header

Minimal form, ran on P2. P1's richer form adds the edit rule, the file's kind and expected counts (§12).

```json
{
  "meta": {
    "serves": "design/<SYSTEM>.md",
    "identity_maps": ["<container whose keys are record ids>"]
  }
}
```

## §21.10 The base suite script (GDScript)

**Not run in this printing.** A base script with these features carried 39 suites and 482 checks on P2; this text was written from its description and from the first edition's skeleton, and it passes a GDScript parser, which checks syntax and never types. Prove it red on your engine before trusting it (§8.9). Section number kept because projects cite it.

```gdscript
extends Node
## Base suite. Extend it, set suite_name in _init(), list blocks(), write run().
## The suite declaration file holds the exact check count. That count includes
## the two checks this base adds: "every declared block executed" and "teardown".

var suite_name := "unnamed"
var _checks := 0
var _failures := 0
var _ran: Array[String] = []
var _contracts := {}
var _world: Node = null


func blocks() -> Array[String]:
	return []  # override: every block run() will execute, in order


func run() -> void:
	pass  # override: block("...") then check(...) and contract(...) calls


func watchdog_seconds() -> float:
	return 20.0  # near the suite's measured time; the runner's ceiling is the real guard


func _ready() -> void:
	print("SUITE START %s" % suite_name)
	get_tree().create_timer(watchdog_seconds()).timeout.connect(_on_watchdog)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	await run()
	check(_ran == blocks(), "every declared block executed, in order")
	if _world != null:
		_world.queue_free()
		_world = null
	await get_tree().process_frame
	await get_tree().process_frame
	var retained := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes_before
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans_before
	contract("teardown", retained == 0 and orphans == 0, {
		"retained_nodes": retained,
		"orphan_nodes": orphans,
		"retained_resources": null,
		"retained_resources_reason": "not measured: the loader cache keeps loaded scenes",
	})
	_write_receipt()
	print("SUITE COMPLETE %s checks=%d failures=%d" % [suite_name, _checks, _failures])
	get_tree().quit(_failures)


func compose(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	_world = packed.instantiate()
	add_child(_world)
	return _world


func block(block_name: String) -> void:
	_ran.append(block_name)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[ok] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func contract(contract_name: String, passed: bool, measured := {}) -> void:
	var row := {"executed": true, "status": "PASS" if passed else "FAIL"}
	row.merge(measured)
	_contracts[contract_name] = row
	check(passed, "contract %s" % contract_name)


func _on_watchdog() -> void:
	print("[FAIL] watchdog: %s did not finish in %d s" % [suite_name, int(watchdog_seconds())])
	get_tree().quit(1)


func _arg(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.substr(key.length() + 3)
	return ""


func _write_receipt() -> void:
	var path := _arg("receipt")
	if path.is_empty():
		return  # a suite that claims no runtime proof writes none
	var script_path: String = get_script().resource_path
	var receipt := {
		"schema": 2,
		"evidence_kind": "runtime_contract",
		"suite": suite_name,
		"checks": _checks,
		"failures": _failures,
		"test_path": script_path,
		"test_sha256": FileAccess.get_sha256(script_path),
		"runtime_inputs_digest": _arg("inputs-digest"),
		"contracts": _contracts,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  "))
	file.close()
```

A suite, with its scope line:

```gdscript
extends "res://tests/suite.gd"
## Scope: proves the session composes and one match ends. Does NOT prove feel or pacing.


func _init() -> void:
	suite_name = "match_smoke"


func blocks() -> Array[String]:
	return ["composition", "match ends"]


func run() -> void:
	block("composition")
	var world := compose("res://scenes/session.tscn")
	var has_sim := world.has_node("Simulation")
	check(has_sim, "the session holds a simulation")
	contract("production_composition", has_sim, {"identities": ["session", "simulation"]})
	block("match ends")
	var sim = world.get_node("Simulation")
	sim.set_physics_process(false)  # step the tick; never scale time
	var ticks := 0
	while not sim.match_over() and ticks < 20000:
		sim.tick()
		ticks += 1
	check(sim.match_over(), "the match ends within the tick budget")
```

The runner computes the runtime-inputs digest before launch and passes it, with the receipt path, after `++`; the engine cannot hash the tree it runs from. The runner counts `[ok]` and `[FAIL]` lines itself and compares the total with the declared count: the suite's own count is never the only one. The receipt carries no time.

## §21.11 Receipt fields

Run receipt (written by the runner; ran on P1 and P2, the digest-plus-manifest form is proposed from P2's notes):

```json
{ "schema": "<game>.run-receipt.v2", "evidence_kind": "suite_run",
  "completed": true, "exit": 0, "raw_engine_exit": 0, "timed_out": false, "elapsed_s": 4.2,
  "scene": "res://tests/<suite>.tscn", "test_script": "<path>", "test_sha256": "<hash>",
  "runtime_inputs_digest": "<hash>", "manifest": "manifests/<hash>.json",
  "declared_checks": 12, "ok_lines": 12, "fail_lines": 0, "sentinels": {"start": 1, "complete": 1},
  "log_sha256": "<hash>", "stale_import_cache": false, "foreign_engine_processes": 0,
  "contract_receipt": {"path": "<path>", "sha256": "<hash>", "admitted": false} }
```

Runtime contract (written by the suite): the receipt in §21.10. Every number is measured, or null with a reason beside it. Capture record: per-frame SHA-256, the camera class, the settings the capture changed, the movie writer's reported size, the measured series.

## §21.12 The pickup block

Revised from P1's and P2's. Budget: the current block and two before it, 150 lines in all.

```
## <date> pickup: <one line>
- Where the work stands: milestone; open owner rows (since <date each>); open owner-directed sequences: N.
- Last verified commit: <hash> (verifier, <date>). Commits since: N.
- Branches and worktrees: <each: path, what it holds, what it waits for> | none.
- Engine: free | held by owner since <date> | lane contested by <project>.
- Read first, in this order: ...
- Immediate next action: ...
- Constraints in force: ...                    (listed here, never "as below")
- Open owner decisions: ... (oldest first; in the next form)
- Does the newest owner direction open a new numbered sequence? yes -> scope audit is the next step | no
- Report fields: tree clean at end yes|no; protected paths n/n; gates and exits; unproven: ...
- Decision: MERGE-CANDIDATE <hash> | BLOCKED <reason> | NEEDS-OWNER <question> | HELD ON <rows>
```

## §21.13 A rulings index entry [X]

Deferred until a second authority can rule (§2.2). Ran on P1.

```json
{ "id": "RUL-001", "date": "<date>", "authority": "owner | executive | management | practice",
  "summary": "<one sentence>", "source": "<in-tree path> | owner item N", "scope": ["<tag>"], "supersedes": [] }
```

## §21.14 The oracle prompt

Written by the oracle and pasted by the owner (§5.8). Not run: no builder has built from one. Retired with the oracle's first version: the packet folder, the progress-events file and the build-result file.

```text
# Build me a game: <working title>
You are my engineering team. I am the owner. Build the game described below, in this folder, by the method in <the manual>.
## 1. Before anything else      find the manual's core and read it in full; if it is missing, stop and ask
## 2. What this message is       derived from play; FROM PLAY is decided (KEPT), FAINT is offered (PROPOSED),
                                 DEFAULT is open (DEFAULT APPLIED)
## 3. The game                   > Build me **<title>**: <pitch>; no mechanic is given; the order in which lines yield
### What it stands on            S1 to S5 (3 dominant, 2 secondary) and X, the productive contradiction; each: the
                                 signal, the behaviour it was seen in, the design consequence
### Also seen, more faintly      FAINT: weaker evidence, optional, and it yields
### Game Design Vector           31 rows: field, value, basis (FROM PLAY with its label, FAINT, SCOPE or DEFAULT)
### Laws                         L1 onward: what the game must never do
### Echoes of the night          E1 onward: what the player did, and what it becomes; the last is the feature nobody asked for
### Not known                    what the night did not show
## 4. Acceptance: the reading    the visions: card, the words the player was told, the label of what makes it true
## 5. Scope (mine to change)     the pocket-game lines, held by the owner; three lines not the builder's to open
## 6. My standing grant          the §21.16 fields: kind, covers, lifts nothing, stays reserved, lapses
## 7. What I expect back         at once, the game proposed in ten lines and the questions; the day-zero report;
                                 the slice; one question after play
```

## §21.15 The question form

Ran on P2: answered forms settled several decisions per message.

```
<one line: what build this is about>     Play it: <the one-press command>

1. <question, in what the player would see>?
   (a) <option> (Recommended): <consequence, cost>
   (b) <option>: <consequence, cost>
   (c) In my own words: ____
... at most four questions, two to four options each; oldest gate-blocking decision first.
```

Filed back verbatim as one owner-words entry.

## §21.16 A grant's scope paragraph

Ran on P2.

```
Grant N (<date>, owner item M): "<the owner's words>"
Kind: taste licence | leave to proceed | both.
Covers: <what may now be done without asking>.
Lifts from the reserved list: nothing | <named class>.
Stays reserved: money, accounts, publishing, distribution, player data, downloads, the IP boundary, safety, <...>.
Lapses: <when the milestone closes | on the next direction that contradicts it | never, until withdrawn>.
It does not turn developer judgement into acceptance.
```

## §21.17 A living specification

One per system; ran on P2 (seventeen of them). The build-ready form written before code is in §29.

```
# <SYSTEM>
Evidence class: **INERT**        Serves: covenant law <n>, owner item <N>
Promises: ...                    Deliberately does not: ...
Data: <file> read only by <script>
| Number | Value (PLACEHOLDER until played) | Data key |
Suites: <name: N checks> ...     State: BUILT | WIRED | PROVEN | ACCEPTED
Waits: ...
```

## §21.18 A breakage manifest entry

Proposed from P2's notes; not run as an instrument (P2 ran breakages by hand and recorded counts in commit bodies).

```json
{ "id": "B07", "patch": "breakages/B07.diff", "suite": "combat_test",
  "expect": "red", "why": "removes the cooldown check; a second swing lands on the same tick",
  "result": "red | green", "survivor": null }
```

`survivor` is null, or "test gap closed in <commit>", or "harmless equivalent: <why>".

## §21.19 A prompt-sheet message, and a provenance record

Ran on P2 (seven sheets, thirty ingested sheets, no original changed). The provenance record is proposed: P2 never wrote one.

````
### Message 4: <what it is for>            For: <view function or data key that reads each cell>
```
<the whole message, ready to paste, no blanks>
Scale: the same art-pixel size as <the figure drawn earlier in this chat>.
NEVER: text, letters, numbers, runes, logos, signatures, watermarks.
```
````

```json
{ "file": "<name as it arrived>", "sha256": "<hash>", "sheet": "design/ART_PROMPTS_<date>.md", "message": 4,
  "generator": "UNKNOWN: ask the owner", "model_as_shown": "UNKNOWN", "plan": "UNKNOWN", "terms": "UNKNOWN",
  "date": "<date>", "owner_message": "owner item <N>", "ingest_tool": "<tool and version>", "runtime_key": "<key>" }
```

## §21.20 A lessons-register entry

Proposed; the register did not exist on P2, and its notes had to be reconstructed from commits.

```
<date> | manual section: <A-chapter or §> | keep | change | add | cut | label: M | C | X
Scar: <what broke, what it cost; commit or file>
Proposed wording: <one or two sentences that do not depend on this project>
```

## §21.21 A build brief

A brief handed over with this manual is an overlay. Most of what P2's pinned before the owner answered was overturned within days.

```
0. The owner's words, verbatim, and nothing else. (The prompt itself lives in the day-zero record; use its hash.)
Every other section opens: "Input; numbers provisional until the owner has seen the game run."
No section may claim owner direction.
1. The reading of the prompt, as numbered decisions.
2. Numbers to pin on day zero: only those that shape every script (tick rate, units, input record, authority),
   each in the simulation's own unit with the conversion shown. Later numbers: "to pin when its milestone opens".
3. The genre's traps, each with a measurable early signal and a threshold.
4. What never happens without the owner.
5. The shape of the first report, including the question form.
Written with placeholders for any franchise, item or character, so it can enter a repository without redaction.
```
