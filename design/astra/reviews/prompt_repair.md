# Prompt carrier repair: diagnosis and proof plan

Prepared against postmerge `cc95005d2c24b6be5cb04e728c5229c5d416954b` while the M11 runtime lane was active. Source edits were held until root released the freeze, then the bounded repair below was applied. No Godot process was launched, and nothing was staged or committed by this task.

## Executed result

The three proposed prompt strings and the Python test correction are applied. Evidence is in `design/astra/evidence/prompt_repair/receipt.json` with complete stdout/stderr pairs and the synthetic before/after fixture text.

| Check | Before | After |
| --- | --- | --- |
| Synthetic winding fixture, real audit CLI | Exit 1; two forbidden keyboard findings | Exit 0; no findings after semantic repair |
| Full production prompt audit | Exit 1; two forbidden keyboard findings and one new legacy occurrence | Exit 0; forbidden 0, new legacy 0, stale baseline 0 |
| Full Python prompt self-test | Exit 1; live production assertion rejects the uncovered counter carrier | Exit 0; all 28 tests pass |
| Scoped `git diff --check` | Not needed for red proof | Exit 0 |

The production scan still reports 184 covered legacy occurrences, two ambiguous dynamic prompts, and two baseline cleanup opportunities. Those are not claimed resolved. The baseline SHA256 is unchanged: `0270ebe734980234bd91fb32ee0a73cd9a0493727b68810a06c2a00a0e166569`. No production baseline update was run. Existing unrelated self-tests use temporary fixture baselines only.

This proves source classification and scanner behavior. It does not claim new runtime, visual, controller or human acceptance. The ordinary interaction functions and winding behavior were untouched; the product diff changes three returned strings only.

## Exact defect

`design/astra/evidence/m11b_audits/interaction_prompt_carriers.stdout.txt` reports two existing forbidden keyboard instructions in `game/scripts/props/clock_prop.gd:297,300` and one **new uncovered legacy carrier** in `game/scripts/game/maintenance_shop_counter.gd:29`.

The new fallback is `"[E]  Inspect %s" % surface_label`. Its dynamic physical label replaces the previously baselined fixed `"[E]  Inspect hardware counter"`, so the baseline correctly treats the literal as a new occurrence. This is not a scanner bug or a test-count mismatch. Preserve the physical label and remove its input-device prefix.

The clock contains `"Hold E — winding…"` and `"Hold E — wind the clock"`. These hardcode keyboard input in object-authored semantic text. The ordinary interaction player owns the input carrier. Winding input behavior, spring state, work-order completion and the Vantry cover behavior need no change for this bounded correction.

The existing self-test `ProductionSmokeTests.test_known_production_violation_is_reported_not_suppressed` requires the production clock to be broken and requires audit exit 1. It will fail when the real defect is repaired. Move that negative proof onto a synthetic fixture, and require the production audit to pass its actual contract.

## Proposed product patch

Only these three strings change:

| File/branch | Current | Proposed |
| --- | --- | --- |
| `props/clock_prop.gd`, winding | `Hold E — winding…` | `Winding the clock…` |
| `props/clock_prop.gd`, idle | `Hold E — wind the clock` | `Wind the clock` |
| `game/maintenance_shop_counter.gd`, empty transaction fallback | `[E]  Inspect %s` | `Inspect %s` |

The counter still returns `service.counter_prompt(shop_id)` when a transaction exists and still interpolates the shop's own surface label. No baseline update or baseline cleanup is required. Existing baseline cleanup opportunities may remain visible without failing.

## Meaningful negative proof without preserving a product bug

In the owned Python self-test file, replace the known-production-violation test with a temporary synthetic `clock_prop.gd` containing both keyboard instructions. Run the audit with an absent temporary baseline and require exit 1 plus both `FORBIDDEN_KEYBOARD` findings in `interact_prompt`. Rewrite only those fixture instructions to semantic text and require exit 0 with no forbidden findings. Assert no baseline was created. This proves the scanner detects the bad carrier and permits the repair, without relying on a live product defect or changing the production baseline.

Strengthen the existing read-only production smoke test with `forbidden == 0` and `code == 0`, retaining its zero-new-legacy and zero-stale-baseline assertions. Before changing the product, the strengthened test must fail against the two clock instructions and the newly uncovered counter literal. After the three-string change, it must pass. Keep fixture counts separate from production counts; do not use changing a count as a substitute for repairing the uncovered literal.

## Evidence sequence after lane release

1. Record exact HEAD, owned-file hashes and baseline SHA256.
2. Change the Python test only; capture the full self-test's real pre-fix failure and the fixture negative/positive proof.
3. Apply the three semantic string changes. Run the Python self-test and source audit `--json`, capturing exit codes, stdout and stderr in a distinct evidence directory.
4. Require production audit exit 0, forbidden 0, new legacy 0, stale baseline 0, and unchanged baseline SHA256. The expected historical covered count remains 184; ambiguous dynamic prompts remain separately reported and are not silently cleared.
5. Review the exact three owned-file diff and report proof limits: source classification and Python scanner behavior are demonstrated; no new Godot run or claim of visual/controller acceptance is made by this patch.

Owned implementation scope: `game/scripts/props/clock_prop.gd`, `game/scripts/game/maintenance_shop_counter.gd`, `tools/tests/test_interaction_prompt_carriers.py`. No master ledger edits, runtime-process changes or production-baseline edits.
