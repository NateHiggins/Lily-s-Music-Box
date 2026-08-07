extends Node
## Does the schedule data survive contact with the director?
##
## No building: this loads resident_schedules.json and building_layout.json
## the way the ScheduleDirector does, then proves (a) every resident
## resolves to a legal directive at every ten-minute mark of every day
## shape, (b) every place string maps to a finite point or an honest
## despawn, and (c) a hand-picked set of canon moments land where the
## design doc says they land — Iris at the Harukiya on a Friday night,
## the Vales' laundry hours, Omar's Tuesday chassis night at 5B, the
## first-Saturday tenant meeting. Exit code is the failure count.

func _ready() -> void:
	var file := FileAccess.open("res://data/building_layout.json",
			FileAccess.READ)
	if file == null:
		print("[SCHED] FAIL: no building layout")
		get_tree().quit(1)
		return
	var layout: Dictionary = JSON.parse_string(file.get_as_text())
	var director := ScheduleDirector.new()
	add_child(director)
	director.setup(null, layout)
	if director.data.is_empty():
		print("[SCHED] FAIL: schedule data missing or unparseable")
		get_tree().quit(1)
		return
	var fails := director.self_test()
	print("[SCHED] RESULT: %s (%d failures)"
			% ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
