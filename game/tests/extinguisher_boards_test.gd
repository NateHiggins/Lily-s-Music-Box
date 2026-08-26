extends Node
## SR7-P focused proof: seven empty boards are a story.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/ExtinguisherBoardsTest.tscn `
##         -ProjectPath <checkout>/game
##
## What this holds down, none of which needs the building:
##
##   * there is still exactly ONE functional extinguisher family, and the table
##     names exactly one board as its own;
##   * the passive vocabulary is small, deliberate and unevenly distributed;
##   * and the passive builder owns nothing — no node, no area, no collision,
##     no light, no process, no signal, no persistence, no snapshot, and above
##     all no tag, because a tag is the one thing that would make an intact
##     silhouette look like readiness.

const DetailPass := preload("res://scripts/building/orison_detail_pass.gd")
const DETAIL_PATH := "res://scripts/building/orison_detail_pass.gd"
const SR7O_PATH := "res://scripts/props/soda_acid_extinguisher_prop.gd"
const FLOORS := ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
const PASSIVE := ["hung", "empty_bracket", "stripped"]

var passed := 0
var failed := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	_the_table_covers_the_building()
	_exactly_one_working_board()
	_the_vocabulary_is_small_and_uneven()
	_the_passive_builder_owns_nothing()
	_no_passive_condition_carries_a_tag()
	_sr7o_is_untouched_by_this()
	print("[BOARDS TEST] PASS %d/%d" % [passed, passed + failed])
	if failed > 0:
		print("[BOARDS TEST] FAIL %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("[BOARDS TEST] FAILED: %s" % label)


## The body of `_build_board_condition`, read out of the source file WITH ITS
## COMMENTS STRIPPED, so every claim below is about the code and not about the
## prose describing it. The comment is allowed to say "no tag"; the code is not
## allowed to draw one.
func _builder_source() -> String:
	var source := FileAccess.get_file_as_string(DETAIL_PATH)
	var body := source.substr(source.find("func _build_board_condition"))
	body = body.substr(0, body.find("func _build_resident_details"))
	var code := ""
	for line in body.split("\n"):
		var hash_at := str(line).find("#")
		code += (str(line) if hash_at < 0 else str(line).substr(0, hash_at))
		code += "\n"
	return code


func _the_table_covers_the_building() -> void:
	var table: Dictionary = DetailPass.BOARD_CONDITIONS
	_check("the table names eight boards", table.size() == 8)
	for floor_id in FLOORS:
		_check("%s has an authored condition" % floor_id, table.has(floor_id))
	for floor_id in table.keys():
		_check("%s is a floor this building has" % floor_id,
				str(floor_id) in FLOORS)
		_check("%s's condition is one this file can draw" % floor_id,
				str(table[floor_id]) in PASSIVE + ["working"])


func _exactly_one_working_board() -> void:
	var table: Dictionary = DetailPass.BOARD_CONDITIONS
	var working: Array[String] = []
	for floor_id in table.keys():
		if str(table[floor_id]) == "working":
			working.append(str(floor_id))
	_check("EXACTLY ONE board is the working one", working.size() == 1)
	_check("and it is F03, which is SR7-O's", working == ["F03"])
	# The builder returns before drawing anything on that board, so a passive
	# vessel can never appear behind the apparatus.
	var body := _builder_source()
	_check("the builder refuses to draw on the working board",
			body.contains('condition == "working"'))
	_check("and it does so by returning, not by hiding",
			body.contains("return"))


func _the_vocabulary_is_small_and_uneven() -> void:
	var table: Dictionary = DetailPass.BOARD_CONDITIONS
	var used: Dictionary = {}
	for floor_id in table.keys():
		var condition := str(table[floor_id])
		if condition == "working":
			continue
		used[condition] = int(used.get(condition, 0)) + 1
	_check("the passive vocabulary is at least two conditions",
			used.size() >= 2)
	_check("and at most four, which is the brief's ceiling", used.size() <= 4)
	_check("it is three (%d)" % used.size(), used.size() == 3)
	for condition in PASSIVE:
		_check("%s is actually used" % condition, used.has(condition))
	# Seven boards over three conditions cannot be an even split, and this
	# asserts it is not: an even split is the thing that reads as a rule, and a
	# rule is what made the boards look procedural in the first place.
	var counts: Array = used.values()
	counts.sort()
	_check("the distribution is uneven (%s)" % str(counts),
			counts[0] != counts[counts.size() - 1])
	var total := 0
	for count in counts:
		total += int(count)
	_check("and it covers all seven non-working boards", total == 7)


func _the_passive_builder_owns_nothing() -> void:
	var body := _builder_source()
	_check("the builder exists at all", body.length() > 400)
	# It cannot create a node of any kind, which is what makes "no Area3D, no
	# collision, no light, no physics, no process" true by construction rather
	# than by inspection.
	for forbidden in ["Node3D", "MeshInstance3D", "Area3D", "CollisionShape",
			"StaticBody", "RigidBody", "Light3D", "OmniLight", "SpotLight",
			".new(", "add_child", "set_process", "_process", "RayCast",
			"PhysicsServer"]:
		_check("the builder never uses %s" % forbidden,
				not body.contains(forbidden))
	# Nor reach any owner, lifecycle or persistence.
	for owner_name in ["WorkOrders", "RealityCases", "RealityState",
			"MaintenanceInventory", "MaintenanceActivityLibrary",
			"FirstShiftDirector", "CoreLoopDirector", "ObjectiveTracker",
			"WatchStationNetwork", "SodaAcidExtinguisherProp",
			"FireLineCabinetProp", "maintenance_items", "signal", "emit",
			"snapshot", "restore", "interact", "control_prompt"]:
		_check("the builder never touches %s" % owner_name,
				not body.contains(owner_name))
	# Everything it draws goes through the two batch helpers that already draw
	# the board itself, so it adds no draw call and no material.
	_check("it draws through _box", body.contains("_box(batch"))
	_check("it draws through _cylinder", body.contains("_cylinder(batch"))
	var calls := body.count("_box(batch") + body.count("_cylinder(batch")
	_check("and through nothing else (%d batch calls)" % calls, calls >= 8)


func _no_passive_condition_carries_a_tag() -> void:
	var body := _builder_source()
	# THE ONE THING THAT WOULD BREAK THE LESSON. SR7-O's board carries an
	# inspection tag and a charge plate; a passive board that carried either
	# would be claiming an inspection nobody performed, and an intact
	# silhouette would start reading as readiness.
	for tell in ["Label3D", "_letter", "TAG", "tag", "INSPECT", "inspect",
			"CHARGE", "IN ORDER", "MADE UP", "seal", "certif"]:
		_check("no passive condition carries %s" % tell,
				not body.contains(tell))


func _sr7o_is_untouched_by_this() -> void:
	var theirs := FileAccess.get_file_as_string(SR7O_PATH)
	_check("SR7-O's prop is still there to read", theirs.length() > 10000)
	# It knows nothing about this increment, in either direction.
	for symbol in ["BOARD_CONDITIONS", "_build_board_condition",
			"empty_bracket", "stripped"]:
		_check("SR7-O never references SR7-P's %s" % symbol,
				not theirs.contains(symbol))
	# And SR7-O is still the only script in the props folder that answers to an
	# extinguisher: the passive boards are not a second family.
	var dir := DirAccess.open("res://scripts/props")
	var families: Array[String] = []
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".gd") and file_name.contains("extinguish"):
				families.append(file_name)
	_check("exactly one extinguisher script exists (%s)" % ", ".join(families),
			families == ["soda_acid_extinguisher_prop.gd"])
