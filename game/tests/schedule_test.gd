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
	fails += _flavour_days(director)
	print("[SCHED] RESULT: %s (%d failures)"
			% ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)


## The 4 Nov 2026 flavour special days (design/ORISON_MYSTERY_CONTINUITY_PASS_2026-11-04.md).
## self_test resolves at doy 0, so each record is checked here at its first and
## last covered minute and one minute past its end, and its place must give a
## legal directive. None may touch 19-22 July (doy 200-203).
func _flavour_days(director: ScheduleDirector) -> int:
	var fails := 0
	var cases := [
		["evelyn_marsh", 246, 510, 600, "lobby"],
		["evelyn_marsh", 285, 1290, 1440, "roof"],
		["evelyn_marsh", 286, 0, 75, "roof"],
		["evelyn_marsh", 286, 75, 120, "stairs"],
		["lena_ortiz", 285, 1320, 1440, "roof"],
		["lena_ortiz", 286, 0, 120, "roof"],
		["teresa_vale", 285, 1380, 1440, "roof"],
		["teresa_vale", 286, 0, 90, "roof"],
		["malcolm_reed", 302, 1170, 1230, "unit"]]
	for c in cases:
		var slug := str(c[0])
		var doy := int(c[1])
		for m in [int(c[2]), int(c[3]) - 1]:
			var block := director.resolve(slug, "sat", float(m), doy, false)
			var mode := str(director.directive_for(slug, block).get("mode", ""))
			if str(block.get("place", "")) != str(c[4]) or mode not in ["home", "place", "exterior", "offsite"]:
				print("[SCHED] FAIL: %s doy %d minute %d resolves to %s (%s)" % [slug, doy, m, block.get("place", "?"), mode])
				fails += 1
		if int(c[3]) < 1440:
			var after := director.resolve(slug, "sat", float(c[3]), doy, false)
			var later_special := false
			for other in cases:
				if str(other[0]) == slug and int(other[1]) == doy and int(other[2]) == int(c[3]):
					later_special = true
			if not later_special and after.get("detail", "") == director.resolve(slug, "sat", float(c[3]) - 1.0, doy, false).get("detail", ""):
				print("[SCHED] FAIL: %s doy %d still in its special block at minute %d" % [slug, doy, int(c[3])])
				fails += 1
	for slug in director.data.get("residents", {}):
		for sd in director.data.residents[slug].get("special_days", []):
			if int(sd.get("doy", 0)) in [200, 201, 202, 203]:
				print("[SCHED] FAIL: %s has a special day inside 19-22 July" % slug)
				fails += 1
	print("[SCHED] flavour special days: %d failures" % fails)
	return fails
