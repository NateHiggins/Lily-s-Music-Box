extends Node
## K6 visual acceptance pair. The first frame is the resolved apartment before
## the wake boundary; the second carries the one persisted factual residue.
##
##   SHOT_DIR=<abs> godot --path game \
##       res://tests/MinaWakingResidueShot.tscn

const CASE_ID := MinaCaptionManifestation.CASE_ID
const RESIDUE_ID := MinaCaptionManifestation.RESIDUE_ID
const ANCHOR_ID := MinaCaptionManifestation.RESIDUE_ANCHOR_ID
const SOCKET_ID := MinaCaptionManifestation.RESIDUE_SOCKET_ID

var root: Node3D
var camera: Camera3D
var failures := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_canvas_ui(get_tree().root)
	root.player.set_physics_process(false)
	if root.resident_routines != null:
		root.resident_routines.set_process(false)
	if root.sanity != null:
		root.sanity.stand_down()
	if root.light_rig != null:
		root.light_rig.set_process(false)
	if root.day_night_director != null:
		root.day_night_director.set_process(false)

	camera = Camera3D.new()
	camera.fov = 65.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera

	var anchor := AcousticGraphData.node_pos(ANCHOR_ID)
	_check(AcousticGraphData.nodes.has(ANCHOR_ID) and anchor != Vector3.ZERO,
			"the residue uses Mina's generated refrigerator marker")
	var label := root.find_child("MinaWakingResidue", true, false) as Label3D
	var display := label.global_position if label != null else anchor
	var socket_position := Vector3.ZERO
	for floor: Dictionary in root.layout.get("floors", []):
		for socket: Dictionary in floor.get("sockets", []):
			if str(socket.get("id", "")) == SOCKET_ID:
				var at: Array = socket.get("at", [])
				if at.size() >= 2:
					socket_position = GameBoot.b2g([
							float(at[0]), float(at[1]),
							float(socket.get("z", floor.get("z", 0.0)))])
	_check(socket_position != Vector3.ZERO and label != null
			and display.distance_to(socket_position
					+ Vector3(0.0, 0.75, 0.015)) < 0.01,
			"the visible residue follows the generated refrigerator face socket")
	# The generated face socket is on the south-facing appliance front.
	camera.global_position = display + Vector3(-1.4, 0.80, 1.0)
	camera.look_at(display)
	root.player.global_position = camera.global_position
	await get_tree().create_timer(1.0).timeout

	# Construct the already-proven case endpoint without replaying K5's full
	# forty-five-second shift merely to photograph its one presentation fact.
	var case_state := RealityState.ensure_case(CASE_ID, "mina_vale")
	case_state.stage = "resolved"
	case_state.resolved = true
	RealityState.commit()
	await get_tree().process_frame
	_check(label != null and not label.visible,
			"resolved case alone leaves no waking residue")
	await _capture("00_resolved_control_a")
	await _capture("01_resolved_before_wake")

	RealityState.apply_waking_residue(RESIDUE_ID, {
		"case_id": CASE_ID,
		"source_job_id": "vantry_chirp_2a",
		"anchor_id": ANCHOR_ID,
		"display_socket_id": SOCKET_ID,
		"text": "REFRIGERATOR",
	})
	await get_tree().process_frame
	await get_tree().process_frame
	_check(label != null and label.visible and label.text == "REFRIGERATOR",
			"wake fact reveals the one factual refrigerator caption")
	await _capture("02_waking_residue")

	print("[K6 RESIDUE SHOT] %s; anchor=%s" % [
			"PASS" if failures == 0 else "FAIL", anchor])
	get_tree().quit(0 if failures == 0 else 1)


func _capture(stem: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(stem + ".png"))
	_check(error == OK, "%s frame saved" % stem)


func _hide_canvas_ui(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_ui(child)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [k6 shot ok] ", label)
	else:
		failures += 1
		push_error("[K6 RESIDUE SHOT] " + label)
