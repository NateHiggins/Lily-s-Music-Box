"""Refine only the proposal and its controls; never invokes old prepare or Godot."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PROPOSED = HERE / 'proposed'
OWNER = 'game/scripts/reality/organism_incidents.gd'
TEST = 'game/tests/world_timestamp_test.gd'
sha = lambda data: hashlib.sha256(data).hexdigest()

TEST_INSERT = '''func _mid_report_latch() -> void:
	# Signal-induced protection, not a claimed disk fault: the real issue commit
	# succeeds, then its production order_issued signal raises the real save latch.
	# Activation/report publication continue in memory while later writes refuse.
	_check(clock.advance_to(7201.25) and RealityState.save_game(),
			"mid-report fixture begins at a saved exact campaign minute")
	var earlier: Dictionary = RealityState.data.organism_incidents["2C"].duplicate(true)
	var reports_before: int = incidents.reports_filed
	var latch := {"calls": 0, "primary_bytes": PackedByteArray(), "order_id": ""}
	var on_issue := func(order_id: String, _order: Dictionary) -> void:
		latch.calls += 1
		latch.order_id = order_id
		latch.primary_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
		RealityState.block_invalid_campaign_clock("Fixture signal-induced mid-report protection")
	work_orders.order_issued.connect(on_issue)
	incidents._report("2C", "mina_caption_crisis", {"at": Vector3.ZERO, "count": 6})
	work_orders.order_issued.disconnect(on_issue)
	var report: Dictionary = RealityState.data.organism_incidents.get("2C", {})
	_check(latch.calls == 1 and reports_before + 1 == incidents.reports_filed
			and int(report.get("count", -1)) == int(earlier.count) + 1,
			"real issue signal raises protection inside exactly one report callback")
	_stamp(report, "reported_at", 7201.25)
	_check(not clock.bind_state() and clock.elapsed_minutes() == 0.0 and samples == 1,
			"post-issue clock is unavailable; observed report time did not use its zero fallback")
	var outcome := RealityState.last_save_result()
	_check(RealityState.save_write_blocked and not bool(outcome.get("ok", true))
			and outcome.get("stage") == "write_latch" and outcome.get("protection_required") == true,
			"continued in-memory report does not claim successful persistence")
	_check(FileAccess.get_file_as_bytes(SAVE_PATH) == latch.primary_bytes,
			"activation and report leave the primary at its last successful issue commit")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(saved is Dictionary and _equal(saved.get("organism_incidents", {}).get("2C", {}), earlier)
			and saved.get("work_orders", {}).get(latch.order_id, {}).get("status") == "issued"
			and work_orders.is_active(str(latch.order_id)),
			"disk retains earlier incident plus issued order while runtime report is newer")
	RealityState.load_game()
	_check(RealityState.can_continue() and _equal(RealityState.data.organism_incidents.get("2C", {}), earlier)
			and work_orders.status(str(latch.order_id)) == "issued" and clock.elapsed_minutes() == 7201.25,
			"real reload adopts only completed saved facts and clears the injected latch")


'''


def main():
    prior_receipt_bytes = (HERE / 'preparation_receipt.json').read_bytes()
    prior = json.loads(prior_receipt_bytes)
    expected = {row['path']: row['sha256'] for row in prior['files']}
    owner_before = (PROPOSED / OWNER).read_bytes()
    test_before = (PROPOSED / TEST).read_bytes()
    assert sha(owner_before) == expected[OWNER]
    assert sha(test_before) == expected[TEST]
    original_hashes = {name: sha((HERE / 'originals' / name).read_bytes()) for name in prior['originals']}
    assert original_hashes == prior['originals']
    review = HERE / 'mid_report_revision'
    review.mkdir(exist_ok=False)
    (review / 'preparation_receipt.before.json').write_bytes(prior_receipt_bytes)
    (review / 'world_timestamps.before.patch').write_bytes((HERE / 'world_timestamps.patch').read_bytes())
    (review / 'world_timestamp_test.before.gd.txt').write_bytes(test_before)
    control = HERE / 'controls/mid_report_late_sample' / OWNER
    control.parent.mkdir(parents=True, exist_ok=False)
    control.write_bytes(owner_before)
    before_text = owner_before.decode().replace('\r\n', '\n')
    anchor = '\tif not _clock.bind_state():\n\t\treturn\n\tvar flat: Dictionary = flats[unit]'
    assert before_text.count(anchor) == 1
    after_text = before_text.replace(anchor,
        '\tif not _clock.bind_state():\n\t\treturn\n'
        '\t# Work-order commits/signals can protect the save before this report\n'
        '\t# finishes. Keep the validated event time; later write refusal remains\n'
        '\t# visible through RealityState and does not mean this report persisted.\n'
        '\tvar observed_minute := _clock.elapsed_minutes()\n'
        '\tvar flat: Dictionary = flats[unit]')
    stamp = '"reported_at": _clock.elapsed_minutes(), "reported_at_basis": TIMESTAMP_BASIS,'
    assert after_text.count(stamp) == 1
    after_text = after_text.replace(stamp, '"reported_at": observed_minute, "reported_at_basis": TIMESTAMP_BASIS,')
    (PROPOSED / OWNER).write_text(after_text, encoding='utf-8', newline='\n')
    test_text = test_before.decode().replace('\r\n', '\n')
    assert test_text.count('\t_legacy_events_and_adoption()\n\t_protected_clock()') == 1
    test_text = test_text.replace('\t_legacy_events_and_adoption()\n\t_protected_clock()',
                                  '\t_legacy_events_and_adoption()\n\t_mid_report_latch()\n\t_protected_clock()')
    assert test_text.count('func _protected_clock() -> void:') == 1
    test_text = test_text.replace('func _protected_clock() -> void:', TEST_INSERT + 'func _protected_clock() -> void:')
    (PROPOSED / TEST).write_text(test_text, encoding='utf-8', newline='\n')
    # The wrapped-minute control must retain the independent callback-window fix.
    (HERE / 'controls/wrapped_minute' / OWNER).write_text(after_text.replace('_clock.elapsed_minutes()', '_clock.minute_of_day()'), encoding='utf-8', newline='\n')
    patch, rows = [], []
    for target in sorted(PROPOSED.rglob('*')):
        if not target.is_file(): continue
        relative = target.relative_to(PROPOSED).as_posix()
        original = HERE / 'originals' / relative
        old = original.read_text(encoding='utf-8') if original.is_file() else ''
        text = target.read_text(encoding='utf-8')
        patch.extend(difflib.unified_diff(old.splitlines(True), text.splitlines(True),
            fromfile='a/' + relative if original.is_file() else '/dev/null', tofile='b/' + relative))
        rows.append({'path': relative, 'sha256': sha(target.read_bytes())})
    (HERE / 'world_timestamps.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
    receipt = dict(prior, files=rows, revision='mid_report_observed_minute_before_nested_commits',
        revised_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        originals_match_live=all((HERE / 'originals' / name).read_bytes() == (ROOT / name).read_bytes() for name in original_hashes),
        prior_receipt='mid_report_revision/preparation_receipt.before.json',
        selective_control={'path': control.relative_to(HERE).as_posix(), 'sha256': sha(control.read_bytes()),
            'scope': 'Exact old proposal for OrganismIncidents only, with all other candidate sources and the new common fixture. Restores only the late clock read window.'},
        fixture_scope='Signal-induced real protection latch inside real WorkOrders.order_issued; actual save/readback and reload distinguish runtime completion from persistence. Not a simulated or physical disk-fault claim.')
    receipt['checks'] = prior['checks'] + ['Original bytes preserved', 'Old-proposal callback-window omission retained', 'Wrapped-minute control retains callback-window fix']
    receipt['not_run'] = prior['not_run'] + ['mid-report late-sample omission red']
    (HERE / 'preparation_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    diff = ''.join(difflib.unified_diff(before_text.splitlines(True), after_text.splitlines(True), fromfile='old-proposal/' + OWNER, tofile='revised-proposal/' + OWNER))
    diff += ''.join(difflib.unified_diff(test_before.decode().replace('\r\n', '\n').splitlines(True), test_text.splitlines(True), fromfile='old-proposal/' + TEST, tofile='revised-proposal/' + TEST))
    (review / 'change.diff').write_text(diff, encoding='utf-8')
    assert {name: sha((HERE / 'originals' / name).read_bytes()) for name in original_hashes} == original_hashes
    print(json.dumps({'changed_proposed': [row for row in rows if row['path'] in [OWNER, TEST]],
                     'selective_control': receipt['selective_control'], 'originals_unchanged': True,
                     'runtime': 'not run', 'review_diff': str(review / 'change.diff')}, indent=2))


if __name__ == '__main__': main()
