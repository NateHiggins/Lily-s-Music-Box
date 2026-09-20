class_name CampaignClockDriver
extends Node
## The only automatic campaign-time writer. Roots and presentation nodes read
## CampaignClock; overlapping waking roots never multiply elapsed time.

var _clock := CampaignClock.new()
var _frozen_for_tests := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -100
	var existing := get_tree().get_first_node_in_group("campaign_time_owner")
	if existing != null and existing != self:
		push_error("Only one CampaignClockDriver may advance campaign time")
		set_process(false)
		return
	add_to_group("campaign_time_owner")


func set_frozen_for_tests(frozen: bool) -> void:
	_frozen_for_tests = frozen


func _process(delta: float) -> void:
	if delta <= 0.0 or _frozen_for_tests \
			or OS.get_environment("CAMPAIGN_TIME_FREEZE") == "1" \
			or get_tree().paused:
		return
	# Waking simulation pauses in title/menu-only and Dream-only scenes.
	# One or several live roots authorize exactly one advance this frame.
	for world in get_tree().get_nodes_in_group("building_root"):
		if not world.is_inside_tree() or world.is_queued_for_deletion() \
				or world.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if world.get("startup_failed") == true:
			continue
		if _clock.bind_state():
			_clock.advance_seconds(delta)
		return
