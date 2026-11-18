extends "res://scripts/props/mail_chute_prop.gd"
## V2 presentation of the lobby mail chute, its choke and its collection box.
## V1 keeps the whole apparatus: its facts, the maintenance contract, the
## refusals, the service point, the sounds and the inspection card. Here the
## channel, glass, choke, letters, cover, key, tray, blade, lamp index and box
## are Blender stock on catalogue finishes, each moving part on the pivot V1's
## own _refresh_mechanism drives, and the box's marking is Label3D.
const Native := preload("res://scripts/building/orison_v2_native_lobby_set.gd")

var native: RefCounted
## The "chute" block of res://data/orison_v2/lobby_set_placements.json.
var plan: Dictionary = {}
var marking: Label3D
var box_door_glass: MeshInstance3D


func _build_visual() -> void:
	if native == null or plan.is_empty():
		push_error("V2 mail chute: native stock or plan not supplied")
		return
	native.mount_static(self, "Chute")
	_chute = get_node("Chute__Body_ON_iron_blackened") as MeshInstance3D
	# The choke cheeks and the box case are cast with the channel.
	_choke_w = _chute
	_choke_e = _chute
	_box = _chute
	_glass = _moving("Chute__Glass_ON_glass", "GlassFront")
	_arch_a = _moving("Chute__ArchWest_ON_paper", "ArchLetterWest")
	_arch_b = _moving("Chute__ArchEast_ON_paper", "ArchLetterEast")
	_load = _moving("Chute__Load_ON_paper", "LoadStack")
	_cover = _moving("Chute__Cover_ON_brass", "LockCover")
	_key = _moving("Chute__Key_ON_brass", "KeyBarrel")
	_tray = _moving("Chute__Tray_ON_metal", "CatchTray")
	_blade = _moving("Chute__Blade_ON_metal", "ClearingBlade")
	_box_door = _moving("Chute__BoxDoor_ON_brass", "BoxDoor")
	# The pane rides in the door, which is hinged at the box's west stile.
	box_door_glass = native.draw("Chute__BoxDoorGlass_ON_glass")
	box_door_glass.name = "BoxDoorGlass"
	box_door_glass.transform = Transform3D.IDENTITY
	_box_door.add_child(box_door_glass)
	_test_piece = _moving("Chute__TestPiece_ON_paper", "TestPiece")
	_test_piece.visible = false
	_lamp_index = _moving("Chute__LampIndex_ON_brass", "LampIndex")
	var row: Dictionary = plan.marking
	marking = Native.lettering(str(row.text), str(row.font), int(row.font_size),
			Native.fit(str(row.text), str(row.font), int(row.font_size), float(row.fit_width)),
			Color(float(row.ink[0]), float(row.ink[1]), float(row.ink[2])),
			Vector3(float(row.at[0]), float(row.at[1]), float(row.at[2])))
	marking.name = "BoxMarking"
	marking.visibility_range_end = float(plan.label_range)
	add_child(marking)
	# V1's own four voices and its service point.
	_slide = make_emitter("thud", -14.0)
	_knock = make_emitter("knock", -14.0)
	_draw = make_emitter("creak", -16.0)
	_snap = make_emitter("pop", -15.0)
	_build_chute_reach()
	_refresh_mechanism()


func _moving(part_name: String, node_name: String) -> MeshInstance3D:
	var node: MeshInstance3D = native.draw(part_name)
	node.name = node_name
	add_child(node)
	return node


## V1 lets the two letters of a fallen arch come to rest in mid-air under the
## throat. With a real box below they drop to its floor and lie there.
func _refresh_mechanism() -> void:
	super._refresh_mechanism()
	if _arch_a == null or arch_standing:
		return
	var floor_y := float(plan.box_floor_y)
	_arch_a.position.y = floor_y + 0.007
	_arch_b.position.y = floor_y + 0.021
