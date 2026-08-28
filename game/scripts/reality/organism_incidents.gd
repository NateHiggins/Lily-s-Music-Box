extends Node
## LF-3 — the organism in someone else's flat (owner ruling 2026-08-22:
## "Juno will report it and it has the chance of making a fixable condition
## happen in the area").
##
## The living field goes anywhere on its storey. When a case's organism is
## inside a flat that is not its case's, that flat's resident notices and
## REPORTS it — a simple work order through WorkOrders, in their own voice —
## and the report has a chance of bringing a FIXABLE CONDITION with it: a
## domestic appliance in the flat stops working (FunctionalProp FAULT, the
## same fault Omar's intrusions throw) with a service point on it. Fixing it
## restores the appliance, closes the order, and drives the organism out of
## that flat: its body is scrubbed and its stain raised, so the slime it
## avoids keeps it out until the stain fades.
##
## Ownership: this node owns the survey, the ledger (`organism_incidents` in
## RealityState), the condition points and the voices. WorkOrders owns the
## order lifecycle; the props own their mechanisms; ApartmentEncroachment
## owns the fields. A resident never reports their own organism.

const EncroachmentScript := preload("res://scripts/reality/apartment_encroachment.gd")

const SURVEY_S := 0.5
## Live voxels (0.5 m) of a foreign body inside the flat before it counts.
const REPORT_VOXELS := 6
## How long it has to be there before the resident picks up the phone.
const REPORT_DWELL_S := 20.0
## The chance, rolled on the report and again while the trespass persists.
const CONDITION_CHANCE := 0.55
const CONDITION_RETRY_S := 45.0
## A report with no condition closes itself once the flat has been clear.
const CLEAR_S := 30.0
## After a fix or a clearance the same flat is not re-reported at once.
const COOLDOWN_S := 120.0
const STAIN_ON_FIX := 0.9
## Appliances that can develop the condition. Fixtures, doors, lifts and the
## Vantry points keep their own contracts.
const EXCLUDED_PROPS := ["LightFixtureProp", "CeilingLightProp", "DoorProp",
		"CaseDoorProp", "DoorAnomalyProp", "OtisProp", "VantryPointProp",
		"SignalTerminalProp", "SongbookTerminalProp", "PorchDeckProp",
		"BodegaSignageProp", "HarukiyaSignageProp", "ShopSignProp", "NeonSignProp",
		"MailBankProp", "DeadLettersProp", "PointBallProp", "DomesticWitnessClock",
		"PossessedDomesticProp", "FlueBreastProp", "BoilerProp", "ArcadeCabinetProp",
		"DartsProp"]

## The voices: what each resident says when it is not their organism.
const VOICES := {
	"juno_kells": [
		"2C, Juno Kells. Something's coming in under the door from the corridor — dark, wet, and it hums on the patch cables when the room's quiet. It isn't mine. Come before it reaches the desk.",
		"Juno again, 2C. It's up the wall behind the recorder now and the monitors pick it up as a low feedback. I've labelled everything it's touched. Please.",
	],
	"mina_vale": [
		"2A, Mina Vale. There is a growth on the west wall that I did not put there and cannot caption. It moves when I look away. Logged at %s.",
		"Mina Vale, 2A. The growth is on the floor now and under the sofa. I have timed it. It is faster than the Handbook allows for damp.",
	],
	"lena_ortiz": [
		"2B — Lena. There's a dark thread coming in along the skirting and it pulls when I touch it. I've mended worse. This one mends back.",
	],
	"peter_wren": [
		"4A, Wren. I am filing this in writing as well. An unauthorised substance has entered the flat along the corridor wall. Form enclosed. Please attend.",
	],
	"cal_dwyer": [
		"5B, Cal. Something's come in on the wall by the radio — the set picks it up between stations. It's warm. Can you come and look at it?",
	],
	"mae_kessler": [
		"6C, Mae Kessler. There is a growth on a piece that was not growing this morning, and the piece insists it always has. Come and settle it.",
	],
	"omar_bell": [
		"3B, Omar. There's something on the wall that works. I'd like it not to.",
	],
}
const DEFAULT_VOICE := "%s, %s. There is something growing in here that isn't damp, and it came in from the corridor. Please come and look."

var encroachment: Node
var work_orders: WorkOrders
var root: Node
var enabled := true
## unit -> {"rect": Vector4, "floor_id": String, "floor_y": float,
##          "resident_id": String, "resident": String, "case_id": String}
var flats: Dictionary = {}
## unit -> Array of FunctionalProp inside the flat (built once props exist).
var flat_props: Dictionary = {}
var props_indexed := false
## "unit|case_id" -> seconds of continuous presence
var _dwell: Dictionary = {}
## unit -> seconds of continuous absence of the reported organism
var _clear: Dictionary = {}
## unit -> seconds since the last condition attempt
var _since_roll: Dictionary = {}
var _cooldown: Dictionary = {}
var _accum := 0.0
var _forced_roll := ""
var reports_filed := 0
var conditions_made := 0
var conditions_fixed := 0


func build(layout: Dictionary, enc: Node, spine: WorkOrders, building: Node) -> int:
	name = "OrganismIncidents"
	encroachment = enc
	work_orders = spine
	root = building
	enabled = enc != null and OS.get_environment("LIVING") != "0" \
			and OS.get_environment("ORGANISM_INCIDENTS") != "0"
	_forced_roll = OS.get_environment("ORGANISM_CONDITION")
	if not enabled:
		return 0
	if not RealityState.data.has("organism_incidents"):
		RealityState.data.organism_incidents = {}
	# Every occupied flat on a storey that has a field can be trespassed.
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definitions[case_id]
		var unit := str(definition.get("unit", ""))
		if unit.is_empty() or flats.has(unit):
			continue
		var rooms: Array = EncroachmentScript._unit_rooms(layout, unit)
		if rooms.is_empty():
			continue
		var floor_id := str(rooms[0].floor)
		if not enc.fields.has(floor_id):
			continue
		flats[unit] = {
			"unit": unit,
			"rect": EncroachmentScript._union_rect(rooms), "floor_id": floor_id,
			"floor_y": float(rooms[0].z), "resident_id": str(definition.get("resident_id", "")),
			"resident": str(definition.get("resident", unit)), "case_id": case_id,
		}
	print("[INCIDENTS] %d flats on %d living storeys can report" % [flats.size(), enc.fields.size()])
	return flats.size()


## The appliances exist a second after the building: index them when the
## prop sweep says they are there, and re-arm any condition a save carries.
func attach_props() -> void:
	if not enabled or root == null:
		return
	flat_props.clear()
	var all: Array = []
	_collect_props(root, all)
	for unit in flats:
		var flat: Dictionary = flats[unit]
		var rect: Vector4 = flat.rect
		var fy: float = flat.floor_y
		var rows: Array = []
		for prop in all:
			var p: Vector3 = (prop as Node3D).global_position
			if p.y < fy - 0.2 or p.y > fy + 3.4:
				continue
			if p.x < rect.x or p.x > rect.z or p.z < rect.y or p.z > rect.w:
				continue
			rows.append(prop)
		flat_props[unit] = rows
	props_indexed = true
	_rearm_from_ledger()
	if OS.get_environment("ENCROACH_DEBUG") == "1":
		for unit in flat_props:
			print("[INCIDENTS]   %s: %d appliances" % [unit, (flat_props[unit] as Array).size()])


func _collect_props(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is FunctionalProp:
			if not _excluded(child):
				out.append(child)
		elif child.get_child_count() > 0:
			_collect_props(child, out)


func _excluded(prop: Node) -> bool:
	var script: Script = prop.get_script()
	while script != null:
		var cname: String = script.get_global_name()
		if cname in EXCLUDED_PROPS:
			return true
		script = script.get_base_script()
	return false


func _physics_process(delta: float) -> void:
	if not enabled or encroachment == null or work_orders == null:
		return
	_accum += delta
	if _accum < SURVEY_S:
		return
	var dt := _accum
	_accum = 0.0
	for unit in flats:
		_survey_flat(str(unit), dt)


func _survey_flat(unit: String, dt: float) -> void:
	var flat: Dictionary = flats[unit]
	var field = encroachment.fields.get(flat.floor_id)
	if field == null:
		return
	if _cooldown.has(unit):
		_cooldown[unit] = float(_cooldown[unit]) - dt
		if float(_cooldown[unit]) <= 0.0:
			_cooldown.erase(unit)
	var found: Array = field.survey(flat.rect)
	var record := _record(unit)
	var open_case := ""
	if not record.is_empty() and not bool(record.get("closed", false)):
		open_case = str(record.get("case_id", ""))
	var present_open := false
	for case_id in encroachment.field_source:
		if encroachment._floor_of(case_id) != str(flat.floor_id):
			continue
		var src := int(encroachment.field_source[case_id])
		if src >= found.size():
			continue
		var count := int(found[src].count)
		var key := "%s|%s" % [unit, case_id]
		if case_id == open_case and count >= REPORT_VOXELS:
			present_open = true
		# A resident never reports their own organism.
		if str(flat.case_id) == case_id or count < REPORT_VOXELS:
			_dwell[key] = 0.0
			continue
		_dwell[key] = float(_dwell.get(key, 0.0)) + dt
		if open_case.is_empty() and not _cooldown.has(unit) \
				and float(_dwell[key]) >= _dwell_needed():
			_report(unit, case_id, found[src])
			open_case = case_id
			present_open = true
	if open_case.is_empty():
		return
	record = _record(unit)
	var has_condition := not str(record.get("condition", "")).is_empty()
	if present_open:
		_clear[unit] = 0.0
		if not has_condition:
			_since_roll[unit] = float(_since_roll.get(unit, 0.0)) + dt
			if float(_since_roll[unit]) >= CONDITION_RETRY_S:
				_since_roll[unit] = 0.0
				_try_condition(unit)
	else:
		_clear[unit] = float(_clear.get(unit, 0.0)) + dt
		if not has_condition and float(_clear[unit]) >= CLEAR_S:
			_close(unit, "WORK ORDER CLOSED — %s quiet on the visit; nothing to fix" % unit)


func _dwell_needed() -> float:
	return 2.0 if OS.get_environment("ORGANISM_FAST") == "1" else REPORT_DWELL_S


## --- the report -------------------------------------------------------------


func _report(unit: String, case_id: String, presence: Dictionary) -> void:
	var flat: Dictionary = flats[unit]
	var ledger: Dictionary = RealityState.data.organism_incidents
	var n := int(ledger.get(unit, {}).get("count", 0)) + 1
	var order_id := "ORG-%s-%03d" % [unit, n]
	var owner := str(RealityCases.definitions.get(case_id, {}).get("resident", case_id))
	var text := _voice(flat, n)
	var title := "%s — %s REPORTS" % [unit, str(flat.resident).to_upper()]
	if not work_orders.issue(order_id, title, text, "%s, %s" % [flat.resident, unit]):
		return
	work_orders.activate(order_id)
	var at: Vector3 = presence.at
	ledger[unit] = {
		"count": n, "order_id": order_id, "case_id": case_id, "owner": owner,
		"reported_at": Time.get_unix_time_from_system(), "condition": "", "prop": "",
		"rolls": 0, "fixed": false, "closed": false, "at": [at.x, at.y, at.z],
	}
	RealityState.data.organism_incidents = ledger
	RealityState.commit()
	reports_filed += 1
	_since_roll[unit] = 0.0
	_clear[unit] = 0.0
	print("[INCIDENTS] %s reports %s's organism in %s (%d voxels): %s"
			% [flat.resident, owner, unit, int(presence.count), order_id])
	_try_condition(unit)


func _voice(flat: Dictionary, n: int) -> String:
	var lines: Array = VOICES.get(str(flat.resident_id), [])
	if lines.is_empty():
		return DEFAULT_VOICE % [str(flat.unit), str(flat.resident)]
	var line := str(lines[mini(n - 1, lines.size() - 1)])
	if line.contains("%s"):
		line = line % Time.get_time_string_from_system().substr(0, 5)
	return line


## --- the condition ----------------------------------------------------------


## "It has the chance": a seeded roll, so a campaign rolls the same way on a
## reload, and so the contract can force it (ORGANISM_CONDITION=1|0).
func _roll(unit: String, n: int) -> bool:
	if _forced_roll == "1":
		return true
	if _forced_roll == "0":
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [str(RealityState.data.get("dream_seed", "")), unit, n])
	return rng.randf() < CONDITION_CHANCE


func _try_condition(unit: String) -> bool:
	var record := _record(unit)
	if record.is_empty() or not str(record.get("condition", "")).is_empty():
		return false
	if not props_indexed:
		return false
	var rolls := int(record.get("rolls", 0)) + 1
	record.rolls = rolls
	if not _roll(unit, int(record.count) * 16 + rolls):
		RealityState.commit()
		return false
	var prop := _pick_prop(unit, record)
	if prop == null:
		RealityState.commit()
		return false
	_arm_condition(unit, record, prop)
	var flat: Dictionary = flats[unit]
	if work_orders.tracker:
		work_orders.tracker.show_objective(
				"%s — %s REPORTS" % [unit, str(flat.resident).to_upper()],
				"The %s in %s has stopped — held by the growth. Clear it and restore service."
				% [_prop_label(prop), unit])
	conditions_made += 1
	print("[INCIDENTS] condition in %s: %s (%s) held" % [unit, _prop_label(prop), prop.get_path()])
	return true


func _pick_prop(unit: String, record: Dictionary) -> Node:
	var rows: Array = flat_props.get(unit, [])
	if rows.is_empty():
		return null
	var at_list: Array = record.get("at", [0.0, 0.0, 0.0])
	var at := Vector3(float(at_list[0]), float(at_list[1]), float(at_list[2]))
	var best: Node = null
	var best_d := INF
	for prop in rows:
		if not is_instance_valid(prop):
			continue
		if (prop as FunctionalProp).state == FunctionalProp.PState.FAULT:
			continue
		var d: float = (prop as Node3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = prop
	return best


func _arm_condition(unit: String, record: Dictionary, prop: Node) -> void:
	(prop as FunctionalProp).state = FunctionalProp.PState.FAULT
	record.condition = str((prop as FunctionalProp).prop_type)
	record.prop = str(root.get_path_to(prop))
	record.fixed = false
	RealityState.commit()
	var point := OrganismConditionPoint.new()
	point.setup(self, unit, prop)
	prop.add_child(point)


func _prop_label(prop: Node) -> String:
	return str((prop as FunctionalProp).prop_type).replace("_", " ")


## The fix (the condition point's E): the appliance runs again, the order
## closes, and the organism is driven out of the flat.
func fix(unit: String, prop: Node) -> bool:
	var record := _record(unit)
	if record.is_empty() or bool(record.get("fixed", false)) \
			or str(record.get("condition", "")).is_empty():
		return false
	if is_instance_valid(prop):
		(prop as FunctionalProp).state = FunctionalProp.PState.IDLE
	record.fixed = true
	var flat: Dictionary = flats[unit]
	var field = encroachment.fields.get(flat.floor_id)
	var cleared := 0
	if field != null:
		# Maintenance remains the disturbance authority. The ecology director
		# receives a transient alarm/recall fact before LivingField performs its
		# existing physical repel and stain operation.
		if encroachment.ecology != null:
			var at := Vector3((flat.rect.x + flat.rect.z) * 0.5,
					float(flat.floor_y) + 0.15, (flat.rect.y + flat.rect.w) * 0.5)
			for case_id in encroachment.field_source:
				if encroachment._floor_of(case_id) == str(flat.floor_id):
					var colony_id := int(encroachment.ecology_source.get(case_id, case_id.hash()))
					encroachment.ecology.disturb_colony(colony_id, 1.0,
							"authorized maintenance repulsion", at)
		cleared = field.repel(flat.rect, STAIN_ON_FIX)
	conditions_fixed += 1
	var label := "service"
	if is_instance_valid(prop):
		label = _prop_label(prop)
	_close(unit, "WORK ORDER CLOSED — %s restored in %s; the growth withdrew" % [label, unit])
	print("[INCIDENTS] %s fixed in %s; organism repelled from %d voxels"
			% [str(record.condition), unit, cleared])
	return true


func _close(unit: String, note: String) -> void:
	var record := _record(unit)
	if record.is_empty() or bool(record.get("closed", false)):
		return
	work_orders.close(str(record.order_id), note)
	record.closed = true
	RealityState.commit()
	_cooldown[unit] = COOLDOWN_S
	_clear.erase(unit)
	_since_roll.erase(unit)
	for key in _dwell:
		if str(key).begins_with(unit + "|"):
			_dwell[key] = 0.0


## A save with an unfixed condition: the appliance is still held and the
## point is still on it.
func _rearm_from_ledger() -> void:
	var ledger: Dictionary = RealityState.data.get("organism_incidents", {})
	for unit in ledger:
		var record: Dictionary = ledger[unit]
		if bool(record.get("fixed", false)) or str(record.get("condition", "")).is_empty():
			continue
		var prop := root.get_node_or_null(str(record.get("prop", "")))
		if prop == null or not (prop is FunctionalProp):
			continue
		if prop.get_node_or_null("OrganismConditionPoint") != null:
			continue
		(prop as FunctionalProp).state = FunctionalProp.PState.FAULT
		var point := OrganismConditionPoint.new()
		point.setup(self, str(unit), prop)
		prop.add_child(point)


func _record(unit: String) -> Dictionary:
	var ledger: Dictionary = RealityState.data.get("organism_incidents", {})
	return ledger.get(unit, {})


## Facts for the contract.
func census() -> Dictionary:
	var open := 0
	var held := 0
	for unit in RealityState.data.get("organism_incidents", {}):
		var record: Dictionary = RealityState.data.organism_incidents[unit]
		if not bool(record.get("closed", false)):
			open += 1
		if not str(record.get("condition", "")).is_empty() and not bool(record.get("fixed", false)):
			held += 1
	return {"flats": flats.size(), "reports": reports_filed, "open": open,
			"conditions": conditions_made, "held": held, "fixed": conditions_fixed}


## The service point the condition puts on the appliance: the player's E.
class OrganismConditionPoint:
	extends Area3D
	var incidents: Node
	var unit := ""
	var prop: Node

	func setup(owner_node: Node, flat_unit: String, appliance: Node) -> void:
		incidents = owner_node
		unit = flat_unit
		prop = appliance
		name = "OrganismConditionPoint"
		collision_layer = 1
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var bounds := AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.8, 0.6))
		if appliance.has_method("_visual_bounds"):
			var seen: AABB = appliance._visual_bounds()
			if seen.size.length() >= 0.05:
				bounds = seen
		box.size = bounds.size + Vector3(0.12, 0.12, 0.12)
		shape.shape = box
		shape.position = bounds.get_center()
		add_child(shape)

	func interact_prompt() -> String:
		return "[E]  Clear the growth from the %s — restore service" \
				% str(prop.prop_type).replace("_", " ")

	func interact(_player: Node = null) -> void:
		if incidents != null and incidents.fix(unit, prop):
			queue_free()
