extends Node
## How the house is fitted for the day it is. Two things answer the calendar.
##
## The windows, in a visit: every blind and curtain in the building is set as
## that lead's day would have them (shades half drawn against a July sun, shut
## tight on the night after the storm), and put back exactly as the tenants
## had them when the player comes home. A visit borrows the windows; it never
## becomes a household setting.
##
## The occasion, always: whatever the house puts up for a holiday is shown for
## the date the clock reads, in a visit or in the present. The props are
## another family's (`occasion`, when one is given); this only tells it the day.

var world: Node3D
var loop: Node
var treatments: Array[Node] = []
## What the house would hang out for an occasion: any node with `dress(name)`.
var occasion: Node
var dressed_anchor := ""
var _baseline: Array = []
var _poll := 0.0
var _occasion_day := ""


func setup(root: Node3D, temporal_loop: Node) -> bool:
	world = root
	loop = temporal_loop
	for found: Node in world.find_children("WindowTreatment*", "", true, false):
		if found.has_method("restore_settings") and found.has_method("settings_snapshot"):
			treatments.append(found)
	loop.changed.connect(_sync)
	loop.stage_reset.connect(_redress)
	# A campaign loaded in the middle of a visit: the saved windows are the
	# visit's, and what the tenants had is in the visit's record.
	if loop.in_visit():
		var kept: Variant = (loop.ledger().visit as Dictionary).get("windows")
		if kept is Array and (kept as Array).size() == treatments.size():
			_baseline = (kept as Array).duplicate(true)
			dressed_anchor = str(loop.visit_anchor())
	_sync()
	return not treatments.is_empty()


func _sync() -> void:
	var anchor := str(loop.visit_anchor()) if loop.in_visit() else ""
	if anchor == dressed_anchor:
		return
	if anchor.is_empty():
		_put_back()
	else:
		if _baseline.is_empty():
			for treatment: Node in treatments:
				var had: Dictionary = treatment.settings_snapshot()
				_baseline.append([float(had.raise), float(had.tilt_degrees), float(had.curtain_open)])
			(loop.ledger().visit as Dictionary)["windows"] = _baseline.duplicate(true)
		_dress(anchor)
	dressed_anchor = anchor


## A rerun: the day begins again, so the windows are as that day has them
## whatever the player did to them in the last run.
func _redress() -> void:
	if loop.in_visit() and not _baseline.is_empty() and dressed_anchor == str(loop.visit_anchor()):
		_dress(dressed_anchor)


func _dress(anchor: String) -> void:
	var pose: Dictionary = loop.windows_of(anchor)
	for index in treatments.size():
		var was: Array = _baseline[index]
		# A tenant asleep behind shut blinds stays asleep behind them.
		if float(was[0]) <= 0.001 and float(was[2]) <= 0.001:
			continue
		(treatments[index] as Node).restore_settings({"raise": float(pose.raise), "tilt_degrees": float(pose.tilt_degrees),
				"curtain_open": float(pose.curtain_open)})


func _put_back() -> void:
	if _baseline.size() == treatments.size():
		for index in treatments.size():
			var was: Array = _baseline[index]
			(treatments[index] as Node).restore_settings({"raise": float(was[0]), "tilt_degrees": float(was[1]), "curtain_open": float(was[2])})
	_baseline = []


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 2.0 or world == null or occasion == null:
		return
	_poll = 0.0
	var now: Dictionary = world.campaign_clock.local_datetime()
	if now.is_empty():
		return
	var day := "%04d-%02d-%02d" % [int(now.year), int(now.month), int(now.day)]
	if day == _occasion_day:
		return
	_occasion_day = day
	occasion.dress(str(loop.dressed_for(day).occasion))
