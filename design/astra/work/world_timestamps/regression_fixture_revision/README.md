Current status: root installed these two revised fixtures and preserved their final runtime results. `final_jobs_01` passed with native 0/gate 0; `final_register_01` passed 153/153 with native 0/gate 0 and empty stderr. Exact original/proposed bytes match the earlier red/final green runtime manifests respectively. See `design/astra/evidence/world_timestamps/validation.json` and `design/astra/reviews/world_timestamp_review.md`. The preparation-only account below remains historical; no prior red receipt was rewritten and no additional production change is claimed.

---

# Timestamp regression fixture revision

Prepared outside the game from exact live originals. No production changes or Godot execution occurred during preparation. The two proposed fixtures and patch are ready for the owning agent's runtime verification; `preparation_validation.json` records successful patch applicability and unchanged live originals, not runtime success.

`originals/game/tests/` retains the exact input bytes. `proposed/game/tests/` contains only the two revised fixtures. `regression_fixtures.patch` applies those changes, and `source_binding.json` records both versions' SHA-256 hashes. CRLF file endings are retained; string delimiters now contain explicit escaped newline characters.

## Maintenance job

The original failure is retained under `design/astra/evidence/world_timestamps/regression_jobs_01`: “migration never overwrites an existing authored job.” That assertion also demanded deletion of a newly reintroduced issued order after the authored job already archived the older closed order. The new source-preservation contract refuses that conflicting deletion.

The replacement establishes that the authored job is repairable and archives the prior closed source, captures its complete deep-copied job state, then captures the exact newly issued incoming order. It proves these are conflicting source records. After migration it compares the complete job dictionary, including progress, evidence, timestamps and archived history, and separately requires the exact incoming order to remain issued. This replaces one check with four; the preceding issued, active, closed, idempotence and ordinary legacy-order checks remain unchanged.

## Night Register

The three original failures are retained under `design/astra/evidence/world_timestamps/regression_register_01`: the unexpected `at_basis` field and two authority scans that falsely included comment text. The record whitelist adds only `at_basis`, with a separate assertion requiring its exact value `campaign_elapsed_minutes`. Existing claim, circumstances, lifecycle and authority assertions remain intact.

The original source scanner's delimiter was a literal CRLF embedded between quotes. It did not split LF production source into lines. `_without_comment_lines` normalizes CRLF to LF before splitting, and removes only whole lines whose trimmed text begins with `#`. It preserves inline comments and all executable lines, retaining the original conservative ownership scan.

Four inline controls exercise both LF and CRLF: comment-only forbidden names and foreign spine calls disappear while the legitimate call remains exactly; actual issue/close/case/lock-write lines, including an executable line with a trailing comment, remain exactly. Every original production-source ownership predicate and spine-method allowlist is unchanged. These four controls plus the timestamp-basis assertion should add five checks to the previous 148, pending actual execution.

## Verification boundary

`git apply --check --ignore-space-change design/astra/work/world_timestamps/regression_fixture_revision/regression_fixtures.patch` exited 0. No runtime result is claimed for the revised fixtures. Preserve the earlier red receipts when running the proposed fixtures in fresh profiles.

The separate `HAUNTS.transient_guests` F01 coordinate inside the lift shaft remains documented in `design/astra/reviews/resident_lift_waiting_review.md`. It is outside this two-fixture revision and is not fixed here.
