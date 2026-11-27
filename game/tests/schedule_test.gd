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
	fails += _adela_lives_until(director)
	fails += _radio_appointment(director)
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
			# The guarded window opens on the evening of 19 July: a day that ends before
			# seven that Friday (Cam's envelope, B08, at ten past six) stands clear of it.
			var before_evening := int(sd.get("doy", 0)) == 200 \
					and (sd.get("blocks", []) as Array).all(func(b): return int(b.end_min) <= 19 * 60)
			if int(sd.get("doy", 0)) in [200, 201, 202, 203] and not before_evening:
				print("[SCHED] FAIL: %s has a special day inside 19-22 July" % slug)
				fails += 1
	print("[SCHED] flavour special days: %d failures" % fails)
	return fails


## Only the existing Saturday tape-trading appointment uses the listening mark.
## This checks actual schedule resolution, not native movement or clearance.
func _radio_appointment(director: ScheduleDirector) -> int:
	var fails := 0
	var cases := [
		["sat", 899.0, "unit:workshop"],
		["sat", 900.0, "unit:radio_listening"],
		["sat", 1019.0, "unit:radio_listening"],
		["sat", 1020.0, "unit:workshop"],
		["fri", 951.0, "unit:workshop"],
		["tue", 1290.0, "unit:workshop"]]
	for c: Array in cases:
		var block := director.resolve("cal_dwyer", str(c[0]), float(c[1]), 166, false)
		if block.get("place") != c[2]:
			print("[SCHED] FAIL: Cal radio appointment %s/%s: %s" % [c[0], c[1], block])
			fails += 1
	for minute: float in [900.0, 1019.0]:
		var guest := director.resolve("juno_kells", "sat", minute, 166, false)
		if guest.get("place") != "visit:5B:listening" or guest.get("with") != ["cal_dwyer"]:
			print("[SCHED] FAIL: Juno's existing tape-trading visit changed")
			fails += 1
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/cal_dwyer_routine.json"))
	if route.places.get("unit:radio_listening") != "radio_host" or route.places.get("unit:workshop") != "main":
		print("[SCHED] FAIL: appointment mark must not replace the workshop")
		fails += 1
	print("[SCHED] radio appointment: %d failures" % fails)
	return fails


## Adela lives until 21:03 on Friday 19 July 1929 (ruling cast3_adela_scope_20261114): her roof block holds to the
## minute before, she is gone from that minute and on every later date, and a day with no civil date leaves her alone.
func _adela_lives_until(director: ScheduleDirector) -> int:
	var fails := 0
	var friday := {"civil_date_valid": true, "year": 1929, "month": 7, "day_of_month": 19}
	var saturday := {"civil_date_valid": true, "year": 1929, "month": 7, "day_of_month": 20}
	var earlier := {"civil_date_valid": true, "year": 1929, "month": 7, "day_of_month": 12}
	var cases := [
		[friday, 1262.0, "roof", "on the roof the minute before"],
		[friday, 1263.0, "out", "gone from 21:03"],
		[saturday, 600.0, "out", "gone the next morning"],
		[earlier, 600.0, "photo_supplies", "at the shop on an ordinary Friday"],
	]
	for c: Array in cases:
		var date: Dictionary = c[0]
		var doy := ScheduleDirector.doy_of(int(date.month), int(date.day_of_month))
		var block := director.resolve("adela_voss", "fri" if int(date.day_of_month) != 20 else "sat", float(c[1]), doy, false, date)
		if str(block.get("place", "")) != str(c[2]):
			print("[SCHED] FAIL: Adela %s: got %s" % [c[3], block.get("place", "?")])
			fails += 1
	var gone := director.resolve("adela_voss", "sat", 600.0, 201, false, {})
	if str(gone.get("place", "")) == "" or bool(director.is_gone(director.data.staff.adela_voss, {}, 600)):
		print("[SCHED] FAIL: a day without a civil date must not end anyone")
		fails += 1
	if fails == 0:
		print("[SCHED] Adela lives until 21:03 on 19 July 1929")
	return fails

