extends RefCounted
## Source obligations for the current authored slice. Counts are a census,
## while deleted programmes, missing mechanisms and dangling links must fail.

static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var indices := {}
	for group: String in ["levels", "spaces", "doors", "openings", "windows", "envelopes",
			"fixtures", "platforms", "lift_landings", "stairs", "risers", "anchors", "capsule_stations"]:
		var rows := {}
		for row: Dictionary in layout.get(group, []):
			var id := str(row.get("id", ""))
			if id.is_empty() or rows.has(id): errors.append("duplicate/empty " + group + ": " + id)
			rows[id] = row
		indices[group] = rows
		if rows.is_empty(): errors.append("missing source group: " + group)
	for level: String in ["B1", "F01", "F02", "F03", "F04", "F05", "F06"]:
		_require(indices.levels, level, errors)
	for floor_number in range(1, 7):
		var level := "F%02d" % floor_number
		for suffix: String in ["PUBLIC_CORE", "SERVICE_CORE", "SERVICE_HALL"]:
			_require(indices.spaces, level + "_" + suffix, errors)
		for suffix: String in ["PUBLIC_LANDING_W", "PUBLIC_LANDING_S", "PUBLIC_LANDING_N",
				"SERVICE_LANDING", "SERVICE_RETURN"]:
			_require(indices.platforms, level + "_" + suffix, errors)
		for kind: String in ["PASSENGER", "SERVICE"]:
			_require(indices.lift_landings, level + "_" + kind + "_LIFT_LANDING", errors)
		if floor_number < 6:
			for kind: String in ["PRIMARY", "SERVICE"]:
				_require(indices.stairs, "%s_%s_F%02d" % [kind, level, floor_number + 1], errors)
	_require(indices.stairs, "PRIMARY_B1_F01", errors)
	var sleeping := {"F02_A": "BED", "F02_B": "BED", "F03_A": "BED", "F03_B": "ALCOVE",
		"F04_A": "BED", "F04_B": "ALCOVE", "F05_A": "BED", "F05_B": "ALCOVE",
		"F05_C": "BED1", "F06_A": "BED", "F06_B": "ALCOVE", "F06_C": "BED1"}
	for prefix: String in sleeping:
		for suffix: String in ["MAIN", "VESTIBULE", "PRIVATE_HALL", "BATH", "KITCHEN", sleeping[prefix]]:
			_require(indices.spaces, prefix + "_" + suffix, errors)
	for level: String in ["F05", "F06"]:
		_require(indices.spaces, level + "_C_BED2", errors)
		_require(indices.spaces, level + "_D_RESTRICTED", errors)
	# These are the real hosts' authored door rosters, not a copied count.
	var specs: Dictionary = preload("res://scripts/building/orison_v2_domestic_doors.gd").SPECS
	for identity: String in specs:
		_require(indices.doors, identity, errors)
	_validate_upper_program(layout, indices, errors)
	_validate_upper_daylight(indices, errors)
	for group: String in ["doors", "openings"]:
		for row: Dictionary in layout[group]:
			for endpoint: String in row.get("connects", []):
				_require(indices.spaces, endpoint, errors)
	for group: String in ["spaces", "doors", "openings", "windows", "anchors", "platforms", "lift_landings"]:
		for row: Dictionary in layout[group]:
			_require(indices.levels, str(row.get("level", "")), errors)
	# Actual installed furniture/fitting sources require their semantic anchors.
	for definition: Array in [["res://data/orison_v2/domestic_furniture.json", "furniture"],
			["res://data/orison_v2/domestic_fittings.json", "fittings"]]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(definition[0]))
		if not parsed is Dictionary:
			errors.append("missing installed source: " + str(definition[0]))
			continue
		for row: Dictionary in parsed.get(definition[1], []):
			_require(indices.anchors, str(row.id), errors)
	return errors

static func _validate_upper_program(layout: Dictionary, indices: Dictionary, errors: Array[String]) -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/upper_floor_programs.json"))
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("doors") is not Dictionary or source.doors.is_empty() \
			or source.get("programs") is not Array or source.programs.is_empty():
		errors.append("missing upper programme source")
		return
	# This manifest belongs to the actual native door host, independently of
	# the blockout records being checked; removing a blockout leaf cannot
	# remove the obligation to mount it.
	for identity: String in source.doors:
		_require(indices.doors, identity, errors)
	for record: Dictionary in layout.doors:
		if str(record.level) in ["F05", "F06"] and not source.doors.has(str(record.id)):
			errors.append("upper leaf has no native host: " + str(record.id))
	for program: Dictionary in source.programs:
		_require(indices.doors, str(program.entry), errors)
		for identity: String in program.rooms:
			_require(indices.spaces, identity, errors)

static func _validate_upper_daylight(indices: Dictionary, errors: Array[String]) -> void:
	# The fixture projects WINDOWS from the original upper-floor builder,
	# not the blockout under test. Its three room profiles expand on both
	# floors using the builder's original window identity rule. The Python
	# provenance test checks this fixture against that source literal.
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/data/v2_upper_daylight_contract.json"))
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("profiles") is not Dictionary:
		errors.append("missing upper daylight source")
		return
	for letter: String in ["A", "B", "C"]:
		var profile: Variant = source.profiles.get(letter)
		if profile is not Array or profile.is_empty():
			errors.append("missing upper daylight profile: " + letter)
			continue
		for level: String in ["F05", "F06"]:
			var prefix := level + "_" + letter + "_"
			for index in profile.size():
				var expected: Dictionary = profile[index]
				var identity := prefix + "WINDOW_" + str(index + 1)
				_require(indices.windows, identity, errors)
				if not indices.windows.has(identity): continue
				var window: Dictionary = indices.windows[identity]
				if window.get("space") != prefix + str(expected.room_suffix) \
						or window.get("level") != level or window.get("axis") != expected.axis:
					errors.append("upper daylight room/axis mismatch: " + identity)
				var center: Variant = window.get("center")
				if center is not Array or center.size() != 2:
					errors.append("invalid upper daylight center: " + identity)
				elif not is_equal_approx(float(center[0]), float(expected.center[0])) \
						or not is_equal_approx(float(center[1]), float(expected.center[1])):
					errors.append("upper daylight placement mismatch: " + identity)

static func _require(rows: Dictionary, identity: String, errors: Array[String]) -> void:
	if not rows.has(identity): errors.append("missing semantic record: " + identity)
