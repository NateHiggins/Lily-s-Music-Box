# Interaction prompt carrier audit — usage and interpretation

`tools/audit_interaction_prompt_carriers.py` implements **T2** of
`design/INTERACTION_CONTRACT_2026-08-27.md`: a source-only proof that
production `interact_prompt` and `control_prompt` methods supply **semantic
action text** and never author an input carrier.

## Why carriers belong to the player

The controller owns the device truth: `format_interaction_prompt`
(`player_controller.gd`) strips a legacy leading `[E]`/`[A]`/`[TAP]` and
prepends the *active input family's* own carrier.  A prop that writes
`"[A] Open"`, a glyph, or `"Hold E — wind the clock"` bakes one device into
every device's screen — the exact class of bug fixed by hand in `3fa6fb4`
for the repair panel.  Props say *what the action is*; the player's
controller says *how to invoke it*.

## Running it

```
python tools/audit_interaction_prompt_carriers.py
    [--root game/scripts] [--json] [--baseline <manifest>]
    [--update-baseline] [--include-debug] [--verbose]
```

Default scan: every `.gd` under `game/scripts`, every `interact_prompt` /
`control_prompt` definition (84 methods at the time of writing: 66 + 18,
matching the interaction contract's census).  Inherited implementations
need no special handling — prompt *content* lives at its defining method,
and every definition is visited.

## What it detects and how

The scan is **heuristic, not GDScript semantic analysis**, and says so:

- method bodies are recovered by indentation; every string literal inside
  a prompt method (direct returns, conditional/ternary branches, locals
  later returned, concatenations, format strings) counts as prompt content
  — a deliberate over-approximation applied *only inside prompt methods*;
- file-level constants referenced by a prompt method contribute their
  literals;
- comments are scanned separately (carrier *examples* in comments are
  `COMMENT_ONLY`, never failing);
- a literal-free return built by a helper call is `AMBIGUOUS_DYNAMIC`
  (never failing — review by hand; today production has exactly one, the
  pure delegation in `props/mail_box_zone.gd`);
- carrier-looking strings elsewhere in a file are `NOT_A_PROMPT_RETURN`
  (verbose output only — songbook panel UI copy, arcade HUD composition
  and the controller's own carrier table live here by design).

## Carrier vocabulary (testable)

- **Leading bracket** classifies strongly: `[E]` → `LEGACY_E`;
  `[A]`/`[B]`/`[X]`/`[Y]`/sticks/bumpers → `FORBIDDEN_CONTROLLER`;
  `[TAP]`/`[HOLD]`/`[SWIPE]` → `FORBIDDEN_TOUCH`; `[SPACE]`/`[ENTER]`/
  `[F]`/other key names → `FORBIDDEN_KEYBOARD`; `[LMB]`/`[RMB]` →
  `FORBIDDEN_MOUSE`; unknown bracket tokens → `FORBIDDEN_OTHER`.
- **Known pad glyph characters** anywhere in a string are controller
  carriers.
- **Instructional phrases** require an instruction verb *bound to a key or
  button name*: "Press Escape", "hold Shift", "Press E" (single letters
  must be uppercase in source), "left click", "use the left stick",
  "double-tap".  Ordinary prose is never flagged: "Enter the apartment",
  "Press the carriage lever", "Press a number", "Shift the crate",
  period-fiction labels and object names all stay `CLEAN`.

## The legacy `[E]` policy

Production carries substantial migration debt: **186 legacy `[E]` prompt
literals across the tree**, tolerated because the controller strips them at
presentation.  They are enumerated in the checked-in baseline
(`tools/interaction_prompt_carrier_baseline.json`) with a line-independent
identity — file, method, exact literal — and classified as **migration
debt, not approved new authoring**.  The audit fails when:

- a legacy `[E]` occurrence appears that the baseline does not cover
  (multiplication is locked);
- a baseline literal turns into any other device carrier (forbidden
  classes fail regardless);
- a baseline entry goes stale (its file or method no longer exists) — this
  fails distinctly so the baseline cannot rot silently.

A *cleanly removed* legacy occurrence (file and method still present, the
`[E]` literal gone) is a **baseline cleanup opportunity**: reported, exit
still 0.  `--update-baseline` regenerates the manifest and is the only way
it changes.  The baseline can never cover `[A]`, `[TAP]`, glyphs or named
keyboard/mouse instructions — a manifest attempting that is rejected as
malformed.

## Exit codes (stable, tested)

| Code | Meaning |
|---:|---|
| 0 | clean — covered legacy, ambiguous-dynamic, comments, debug-only and cleanup opportunities are reported without failing |
| 1 | forbidden carrier in a production prompt method, or uncovered legacy `[E]` |
| 4 | stale baseline entries |
| 5 | both 1 and 4 |
| 3 | malformed baseline or usage error |
| 70 | internal failure |

## Reviewing ambiguous results

`AMBIGUOUS_DYNAMIC` methods build their return through calls the scan
cannot resolve.  Check the helper by hand: if it composes from literals in
another prompt method (pure delegation), the delegate is already audited;
if it composes device text, that is a violation the scan cannot see —
which is exactly why the class exists and is listed every run.

## What a green audit does not prove

Source-level carrier neutrality only.  It does not prove the prompt is
reachable (ray, area shapes — contract §K), usable, well-worded, honest
about availability, or that its action exists (ADMIN-INT1's census covered
that); it does not audit `.tscn`-authored nodes, runtime-composed UI copy
outside prompt methods (the songbook panel's "ESC" status line is modal UI,
a different surface), or dynamically built prompts beyond flagging them.

## Current production status (2026-08-28)

`forbidden: 2` — **`props/clock_prop.gd:297,300`** return
`"Hold E — winding…"` and `"Hold E — wind the clock"`: keyboard carriers
inside `interact_prompt()` that the controller's leading-bracket strip
cannot repair, so a pad or touch player reads "Hold E".  Per T2, the audit
reports this and production is left unchanged until K2 supplies human
evidence.  Everything else: 186 covered legacy entries, 1 ambiguous
delegation, 2 debug-only files, 0 stale baseline entries.

## Tests

```
python tools/tests/test_interaction_prompt_carriers.py
```

28 tests over synthetic fixtures (`tools/tests/fixtures/prompt_carriers/`):
the whole vocabulary (clean prose vs bracket, glyph, keyboard, mouse, pad
and touch carriers), conditional/ternary/concatenated/constant/dynamic
construction, comment-only and out-of-method strings, debug-only
classification and `--include-debug`, baseline generation/coverage/new
occurrence/removal/staleness/malformation/never-covering-forbidden,
combined exit 5, deterministic JSON, usage errors, operation without Godot
or Git metadata, and two read-only production smoke checks (census count
84; the clock_prop violation stays reported, never suppressed).
