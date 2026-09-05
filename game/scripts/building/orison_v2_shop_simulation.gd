extends Node
## Waking-world consumer of campaign time and authored resident visits.
## No second clock, wall-clock catch-up, restock timer or item authority.
const MAX_SLICE_MINUTES := 1440.0
const POLL_SECONDS := 1.0

var failed := false
var failure_reason := ""
var _clock: CampaignClock
var _schedules: ScheduleDirector
var _registry: OrisonV2ShopBucketRegistry
var _present: Callable
var _accumulator := 0.0

func setup(clock: CampaignClock, schedules: ScheduleDirector,
		registry: OrisonV2ShopBucketRegistry, present: Callable) -> bool:
	_clock = clock
	_schedules = schedules
	_registry = registry
	_present = present
	failed = false
	failure_reason = ""
	if _clock == null or _schedules == null or _schedules.data.is_empty() \
			or _registry == null or _registry.source_ids().is_empty() or not _present.is_valid():
		return _fail("shop simulation dependencies are incomplete")
	return advance_current()

func _process(delta: float) -> void:
	if failed or _clock == null:
		return
	_accumulator += delta
	if _accumulator < POLL_SECONDS:
		return
	_accumulator = 0.0
	advance_current()

func advance_current() -> bool:
	if failed or _clock == null or not _clock.bind_state():
		return _fail("shop simulation has no valid campaign clock")
	# Whole elapsed minutes avoid saving on every rendered frame. Event starts
	# are authored in whole minutes, so no visit is lost at this boundary.
	var target := floorf(_clock.elapsed_minutes())
	var packets: Dictionary = {}
	for shop_id: String in _registry.source_ids():
		var state := _registry.snapshot(shop_id)
		var previous := float(state.get("last_advanced_minute", -1.0))
		if previous < 0.0 or previous > _clock.elapsed_minutes():
			return _fail("shop simulation interval is outside campaign time: " + shop_id)
		if previous >= target:
			continue
		var source := _registry.source_record(shop_id)
		# Large save catch-up is bounded to one authored day per poll, per shop.
		# The durable cursor makes subsequent slices and reloads idempotent.
		var until := minf(target, previous + MAX_SLICE_MINUTES)
		var facts := _schedules.place_activity_facts(str(source.schedule_place),
				previous, until, _clock)
		if facts.is_empty():
			return _fail("shop simulation could not resolve resident visits: " + shop_id)
		packets[shop_id] = facts
	if packets.is_empty():
		return true
	if not _registry.advance_batch(packets):
		return _fail("shop simulation refused its state update: %s" % [_registry.errors])
	var presentation: Dictionary = _present.call()
	if not bool(presentation.get("ok", false)):
		return _fail("shop simulation presentation refresh failed")
	return true

func shutdown() -> void:
	set_process(false)
	_clock = null
	_schedules = null
	_registry = null
	_present = Callable()

func _exit_tree() -> void:
	shutdown()

func _fail(reason: String) -> bool:
	if not failed:
		failure_reason = reason
		push_error("ORISON V2: " + reason)
	failed = true
	set_process(false)
	return false
