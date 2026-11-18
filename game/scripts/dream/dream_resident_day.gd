extends RefCounted
## Read-only projection of the existing schedule owner's actual day into rooms.
## No actor, clock, random roll, save state or second timetable is created here.

func resolve(subject: String, info: Dictionary, catalog: Dictionary) -> Dictionary:
	var result := {"rooms": [], "stops": [], "errors": []}
	if subject.is_empty(): return result
	if not bool(info.get("valid", false)):
		result.errors.append("resident day needs a valid campaign date")
		return result
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(ScheduleDirector.SCHEDULE_PATH))
	if decoded is not Dictionary:
		result.errors.append("resident schedule data unavailable")
		return result
	var spec: Dictionary = decoded.get("residents", {}).get(subject, {})
	if spec.is_empty():
		result.errors.append("no resident schedule for " + subject)
		return result
	var weekday := str(info.get("day", ""))
	var places := DreamMazeBuilder.resident_day_places(subject, weekday, catalog)
	var boundaries := {0: true, 1440: true}
	var blocks: Array = spec.get("blocks", []).duplicate()
	for special: Dictionary in spec.get("special_days", []):
		if int(special.get("doy", -1)) == int(info.get("doy", 0)):
			blocks.append_array(special.get("blocks", []))
	for block: Dictionary in blocks:
		boundaries[clampi(int(block.get("start_min", 0)), 0, 1440)] = true
		boundaries[clampi(int(block.get("end_min", 0)), 0, 1440)] = true
	var minutes: Array = boundaries.keys()
	minutes.sort()
	# This detached instance only exposes the existing pure resolve query.
	# It never enters the tree, starts a clock, dispatches or moves residents.
	var owner := ScheduleDirector.new()
	owner.data = decoded
	var last_space := ""
	for index in range(minutes.size() - 1):
		var minute := int(minutes[index])
		var block: Dictionary = owner.resolve(subject, weekday, minute,
				int(info.get("doy", 0)), bool(info.get("first_sat", false)), info)
		var place := str(block.get("place", ""))
		if not places.has(place):
			# Outside places remain Past the Mist work; a return is a new visit.
			last_space = ""
			continue
		var row: Dictionary = places[place]
		var space := str(row.source.records[0].id)
		if space == last_space: continue
		result.rooms.append(str(row.id))
		result.stops.append({"minute": minute, "place": place, "space": space, "module": str(row.id)})
		last_space = space
	owner.free()
	# Evening joins morning; do not duplicate that same room across the fold.
	if result.stops.size() > 1 and result.stops[0].space == result.stops[-1].space:
		result.stops.pop_back()
		result.rooms.pop_back()
	return result
