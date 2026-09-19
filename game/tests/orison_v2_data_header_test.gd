extends Node
## Data headers are tested without constructing or mutating a composed world.
const CasePlacement := preload("res://scripts/building/orison_v2_case_one_placement.gd")
const MinaRoutine := preload("res://scripts/characters/orison_v2_mina_routine.gd")
const Boundaries := preload("res://scripts/building/orison_v2_street_boundaries.gd")
const StreetFrame := preload("res://scripts/building/orison_v2_street_frame.gd")
const HistoricalNotice := preload("res://scripts/game/historical_radio_notice.gd")
const Blockout := preload("res://scripts/building/orison_v2_blockout.gd")

class BrokenStreetRuntime extends OrisonV2RuntimeRoot:
	var supplied: Dictionary = {}
	func _read_street_frame() -> Dictionary:
		return supplied

var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _ready() -> void:
	var case_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CasePlacement.PATH))
	var mina_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MinaRoutine.SOURCE))
	var shed_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Boundaries.SOURCE))
	_check(Boundaries.valid_source_header(shed_source), "authored shed uses the supported threshold frame")
	_check(CasePlacement.valid_source_header(case_source), "authored case placement header is supported")
	_check(MinaRoutine.valid_source_header(mina_source), "authored Mina route header matches its owner and frame")
	for invalid_version: Variant in [null, true, "1", 0, 2, 1.5]:
		var bad_shed := shed_source.duplicate(true)
		bad_shed.schema_version = invalid_version
		_check(not Boundaries.valid_source_header(bad_shed), "shed rejects schema %s" % str(invalid_version))
		var bad_case := case_source.duplicate(true)
		bad_case.schema_version = invalid_version
		_check(not CasePlacement.valid_source_header(bad_case), "case rejects schema %s" % str(invalid_version))
		var bad_mina := mina_source.duplicate(true)
		bad_mina.schema_version = invalid_version
		_check(not MinaRoutine.valid_source_header(bad_mina), "Mina rejects schema %s" % str(invalid_version))
	for key: String in ["resident", "frame", "paths", "places"]:
		var missing := mina_source.duplicate(true)
		missing.erase(key)
		_check(not MinaRoutine.valid_source_header(missing), "Mina rejects missing " + key)
	var wrong_resident := mina_source.duplicate(true)
	wrong_resident.resident = "juno_kells"
	_check(not MinaRoutine.valid_source_header(wrong_resident), "another resident cannot reuse Mina's route")
	var wrong_frame := mina_source.duplicate(true)
	wrong_frame.frame = "world"
	_check(not MinaRoutine.valid_source_header(wrong_frame), "world coordinates cannot be interpreted in the adapter frame")
	for key: String in ["objects", "tables"]:
		var missing := case_source.duplicate(true)
		missing.erase(key)
		_check(not CasePlacement.valid_source_header(missing), "case rejects missing " + key)
	for key: String in ["frame", "boxes", "lights"]:
		var missing := shed_source.duplicate(true)
		missing.erase(key)
		_check(not Boundaries.valid_source_header(missing), "shed rejects missing " + key)
	var wrong_shed := shed_source.duplicate(true)
	wrong_shed.frame = "world"
	_check(not Boundaries.valid_source_header(wrong_shed), "shed rejects world coordinates in its threshold frame")
	_check(not Boundaries.valid_source_header(null), "shed rejects malformed JSON root")
	_check(not CasePlacement.valid_source_header([]), "case rejects non-object root")
	_check(not MinaRoutine.valid_source_header(null), "Mina rejects malformed JSON root")
	var frame_source := StreetFrame.load_default()
	_check(not frame_source.is_empty(), "generated street frame is supported")
	for key: String in ["schema", "frame", "source_threshold_z", "arcade_building_line_z"]:
		var missing := frame_source.duplicate(true)
		missing.erase(key)
		_check(not StreetFrame.valid_source_header(missing), "street frame rejects missing " + key)
	for invalid: Variant in [null, true, "9.795", INF, NAN]:
		var wrong := frame_source.duplicate(true)
		wrong.source_threshold_z = invalid
		_check(not StreetFrame.valid_source_header(wrong), "street frame rejects non-finite or non-numeric coordinate")
	var wrong_frame_data := frame_source.duplicate(true)
	wrong_frame_data.frame = "world"
	_check(not StreetFrame.valid_source_header(wrong_frame_data), "street frame rejects foreign coordinate owner")
	_check(StreetFrame.load_from("res://tests/no_such_street_frame.json").is_empty(), "missing street frame returns refusal")
	for invalid: Dictionary in [{}, wrong_frame_data]:
		var refused := BrokenStreetRuntime.new()
		refused.supplied = invalid
		add_child(refused)
		_check(refused.startup_failed and not refused.startup_failure_reason.is_empty(), "composed root reports invalid street input")
		_check(refused.get_child_count() == 0 and refused.campaign_clock == null and refused._blockout == null,
				"composed refusal precedes services and world geometry")
		refused.free()
	var historical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HistoricalNotice.DATA_PATH))
	_check(HistoricalNotice.valid_source_header(historical), "generated historical notice schema is supported")
	for invalid: Variant in [null, true, "1", 2]:
		var wrong := historical.duplicate(true)
		wrong.schema_version = invalid
		_check(not HistoricalNotice.valid_source_header(wrong), "historical notice rejects unsupported schema")
	var layout_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var unit_room: Dictionary = {}
	for room: Dictionary in layout_source.spaces:
		if room.has("unit"):
			_check(Blockout.valid_space_unit(room), "authored apartment owner matches " + str(room.id))
			if unit_room.is_empty(): unit_room = room
	_check(not unit_room.is_empty(), "fixture includes authored apartment ownership")
	for invalid: Variant in [null, true, 5, "", "foreign", "99A"]:
		var wrong := unit_room.duplicate(true)
		wrong.unit = invalid
		_check(not Blockout.valid_space_unit(wrong), "room rejects malformed or foreign-floor apartment identity")
	var blockout := Blockout.new()
	blockout.layout = layout_source.duplicate(true)
	for room: Dictionary in blockout.layout.spaces:
		if room.id == unit_room.id: room.unit = "99A"
	blockout._validate_layout()
	_check(blockout.failures.any(func(value: String) -> bool: return value.begins_with("invalid apartment unit")),
			"production layout validation refuses foreign apartment ownership")
	blockout.free()
	print("V2 DATA HEADERS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
