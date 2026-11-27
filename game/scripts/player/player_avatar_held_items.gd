extends Node3D
## Shared presentation for an avatar's mirror hand and the first-person glove.

const PlayerOriginals := preload("res://scripts/songbook/player_original_custody.gd")
const TraceVisual := preload("res://scripts/songbook/found_trace_visual.gd")
const HoseArm := preload("res://scripts/player/first_person_hose_arm.gd")

var holder: PlayerController
var skeleton: Skeleton3D
var hand_slot: HeldHandSlot
var glove_slot: HeldHandSlot


func _bind_hand_slot(layers: int) -> void:
	hand_slot = HeldHandSlot.new()
	hand_slot.name = "HandSlot"
	hand_slot.layers = layers
	skeleton.add_child(hand_slot)
	if not hand_slot.bind_hand(skeleton):
		hand_slot.queue_free()
		hand_slot = null
		return
	if not RealityState.state_changed.is_connected(refresh_hand):
		RealityState.state_changed.connect(refresh_hand)
	refresh_hand()


## Both views read the same case item. The household state supplies its visual.
func refresh_hand() -> void:
	if not is_instance_valid(hand_slot):
		return
	var item := CarriedCase.hand()
	_bind_glove_slot()
	var has_glove := is_instance_valid(glove_slot)
	if item == hand_slot.worn and (not has_glove or item == glove_slot.worn):
		return
	var state := get_tree().get_first_node_in_group("v2_household_state") if is_inside_tree() else null
	var mirror := _held_part(state, item)
	hand_slot.wear(item if mirror != null else "", mirror)
	if has_glove:
		var drawn := _held_part(state, item)
		glove_slot.wear(item if drawn != null else "", drawn)
		glove_slot.get_meta("arm").set_holding(not glove_slot.worn.is_empty())


func _held_part(state: Node, item: String) -> Node3D:
	if item.begins_with(CarriedCase.FOUND_TRACE_PREFIX):
		return TraceVisual.make(item.trim_prefix(CarriedCase.FOUND_TRACE_PREFIX))
	if item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		var id := PlayerOriginals.id_from_item(item)
		return TraceVisual.make_player_original(id) if PlayerOriginals.is_packed(id) else null
	if item.is_empty() or state == null:
		return null
	if item.begins_with(CarriedCase.BOOK_PREFIX) and state.has_method("packed_book"):
		var copy: Node = state.packed_book(item)
		return copy.hand_visual() if is_instance_valid(copy) and copy.has_method("hand_visual") else null
	if not state.has_method("packed_kitchen_tool"):
		return null
	var packed: Dictionary = state.packed_kitchen_tool(item)
	return null if packed.is_empty() else packed.station.tool_visual(packed.assembly)


## The arm is bound after the avatar. Bind the glove at the first refresh that finds it.
func _bind_glove_slot() -> void:
	if is_instance_valid(glove_slot) or holder == null or holder.camera == null:
		return
	var arm := holder.camera.get_node_or_null("FirstPersonHoseArm")
	if arm == null or not arm.has_method("glove_socket"):
		return
	var socket: BoneAttachment3D = arm.glove_socket()
	if socket == null or not socket.get_parent() is Skeleton3D:
		return
	glove_slot = HeldHandSlot.new()
	glove_slot.name = "GloveHeld"
	glove_slot.layers = int(socket.get_meta("render_layers", HoseArm.LAYER))
	glove_slot.palm = arm.palm_offset()
	var grab: Object = holder.get("_grab")
	var reader := holder
	# The worn copy waits out of sight while the glove works or the player reads.
	glove_slot.busy = func() -> bool:
		return (grab != null and bool(grab.call("active"))) or reader.inspecting()
	glove_slot.bone_name = socket.bone_name
	glove_slot.set_meta("arm", arm)
	socket.get_parent().add_child(glove_slot)


func _exit_tree() -> void:
	if RealityState.state_changed.is_connected(refresh_hand):
		RealityState.state_changed.disconnect(refresh_hand)
