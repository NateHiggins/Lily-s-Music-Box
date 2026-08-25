extends Node
## SR6 focused proof: primary-attention ownership, rolling-window arithmetic
## and the 33/33/33 tolerance are telemetry only.

class Claim:
	extends Node
	var active := false

	func attention_active() -> bool:
		return active

class ShellStub:
	extends Node
	var active_kind := "waking"

var failures := 0
var ledger: AttentionLedger
var shell: ShellStub
var maintenance: Claim
var people: Claim
var dream: Claim


func _ready() -> void:
	shell = ShellStub.new()
	add_child(shell)
	ledger = AttentionLedger.new()
	ledger.setup(shell)
	add_child(ledger)
	ledger.set_process(false)
	maintenance = _claim("attention_maintenance")
	people = _claim("attention_people")
	dream = _claim("attention_dream")

	_check(ledger.classify_primary_attention() == AttentionLedger.Lane.PEOPLE,
			"unclaimed waking traversal belongs to people/search/travel")
	dream.active = true
	_check(ledger.classify_primary_attention() == AttentionLedger.Lane.DREAM,
			"meaningful whole-body attention claims a waking Dream beat")
	people.active = true
	_check(ledger.classify_primary_attention() == AttentionLedger.Lane.PEOPLE,
			"a resident conversation outranks organism activity behind it")
	maintenance.active = true
	_check(ledger.classify_primary_attention() == AttentionLedger.Lane.MAINTENANCE,
			"hands on a mechanism outrank every visible background event")
	shell.active_kind = "dream"
	_check(ledger.classify_primary_attention() == AttentionLedger.Lane.DREAM,
			"the sole active Dream world is relationship time")

	ledger.reset()
	_check(not ledger.record_sample(-1, 4.0)
			and not ledger.record_sample(AttentionLedger.Lane.PEOPLE, 0.0),
			"invalid lanes and empty spans cannot contaminate telemetry")
	ledger.record_sample(AttentionLedger.Lane.MAINTENANCE, 900.0)
	ledger.record_sample(AttentionLedger.Lane.PEOPLE, 900.0)
	ledger.record_sample(AttentionLedger.Lane.DREAM, 900.0)
	var balanced := ledger.census()
	_check(bool(balanced.balanced) and float(balanced.window_minutes) == 45.0,
			"a 45-minute 15/15/15 trace passes the ±5% balance gate")
	_check(int(balanced.segments) == 3
			and absf(float(balanced.shares.maintenance) - 1.0 / 3.0) < 0.001,
			"long uniform spans coalesce instead of storing frames")

	ledger.record_sample(AttentionLedger.Lane.PEOPLE, 300.0)
	var rolled := ledger.census()
	_check(float(rolled.window_minutes) == 45.0
			and float(rolled.seconds.maintenance) == 600.0
			and float(rolled.seconds.people_travel_search) == 1200.0
			and not bool(rolled.balanced),
			"minute 50 evicts the oldest five minutes and exposes imbalance")
	_check(float(rolled.session_seconds) == 3000.0,
			"rolling eviction does not erase full-session duration")
	_check(not RealityState.data.has("attention_ledger"),
			"telemetry creates no campaign or save fact")

	print("ATTENTION LEDGER TEST: %s" %
			("PASS (11/11)" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _claim(group_name: String) -> Claim:
	var claim := Claim.new()
	add_child(claim)
	claim.add_to_group(group_name)
	return claim


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [ledger ok] ", label)
	else:
		failures += 1
		printerr("  [LEDGER FAIL] ", label)
