class_name OrisonV2CityEdgeMist
extends Node
## The edge of the walkable city (Lily's ruling barrier_distance, 2026-11-07):
## walking out from the Orison, a supernatural mist gathers from MIST_START_M,
## and at PASS_OUT_M the player passes out and wakes at the 4B bedside.
## "Reasons to explore, not a hike."
##
## Owns only this presentation and the pass-out. The bedside comes from
## CoreLoopDirector.return_player_to_safe_anchor(), the same movement the
## prologue and the debug dream preview use: it advances no loop boundary and
## writes no clock, save or narrative state. StreetBoundaries' physical wall,
## just beyond PASS_OUT_M, stays the backstop for a player something else holds
## (a call, a conversation, a text field), whom the mist never takes.

signal passed_out(radius_m: float)
signal woke(position: Vector3)

const MIST_START_M := 150.0
const PASS_OUT_M := 200.0
const FADE_TO_BLACK_S := 1.6
const HOLD_BLACK_S := 1.2
const FADE_IN_S := 2.4
const PHASES: Array[String] = ["clear", "fading", "black", "waking"]

## The threshold frame: StreetBoundaries, whose origin is the front door.
var frame: Node3D
## The runtime world, read for its player and core loop when needed.
var world: Node
## Deterministic harnesses advance the same production path explicitly.
var manual_clock := false

var _layer: CanvasLayer
var _overlay: ColorRect
var _material: ShaderMaterial
var _phase := "clear"
var _phase_s := 0.0
var _clock_s := 0.0
var _mist := 0.0
var _black := 0.0
var _radius_m := 0.0
var _held_player := false
var _last_wake_ok := false


static func mist_at(radius_m: float) -> float:
	return smoothstep(MIST_START_M, PASS_OUT_M, radius_m)


func configure(threshold_frame: Node3D, runtime_world: Node) -> void:
	frame = threshold_frame
	world = runtime_world


func _ready() -> void:
	_build_presentation()
	_apply_presentation()


func phase() -> String:
	return _phase


func mist() -> float:
	return _mist


func blackout() -> float:
	return _black


func radius_m() -> float:
	return _radius_m


func last_wake_ok() -> bool:
	return _last_wake_ok


func radius_of(position: Vector3) -> float:
	if frame == null or not is_instance_valid(frame):
		return 0.0
	var local: Vector3 = frame.to_local(position)
	return Vector2(local.x, local.z).length()


func advance_for_test(delta: float) -> bool:
	if not manual_clock:
		return false
	_advance(maxf(0.0, delta))
	return true


func _physics_process(delta: float) -> void:
	if not manual_clock:
		_advance(delta)


func _player() -> CharacterBody3D:
	if world == null or not is_instance_valid(world):
		return null
	var body: Variant = world.get("player")
	if body is CharacterBody3D and is_instance_valid(body) and (body as Node).is_inside_tree():
		return body as CharacterBody3D
	return null


func _advance(delta: float) -> void:
	_clock_s += delta
	var body: CharacterBody3D = _player()
	if body == null:
		_mist = 0.0
		_apply_presentation()
		return
	_radius_m = radius_of(body.global_position)
	match _phase:
		"clear":
			_mist = mist_at(_radius_m)
			_black = 0.0
			if _radius_m >= PASS_OUT_M and _may_take(body):
				_begin_pass_out(body)
		"fading":
			_phase_s += delta
			_mist = 1.0
			_black = clampf(_phase_s / FADE_TO_BLACK_S, 0.0, 1.0)
			body.velocity = Vector3.ZERO
			if _phase_s >= FADE_TO_BLACK_S:
				_wake_in_bed(body)
		"black":
			_phase_s += delta
			_black = 1.0
			_mist = 0.0
			body.velocity = Vector3.ZERO
			if _phase_s >= HOLD_BLACK_S:
				_set_phase("waking")
		"waking":
			_phase_s += delta
			_mist = 0.0
			_black = 1.0 - clampf(_phase_s / FADE_IN_S, 0.0, 1.0)
			if _phase_s >= FADE_IN_S:
				_release(body)
				_black = 0.0
				_set_phase("clear")
	_apply_presentation()


## The mist never takes a player another owner holds: a call, a resident
## conversation, a text field, noclip or an inspection. They stay in full mist
## until released; the physical wall keeps them from walking further.
func _may_take(body: CharacterBody3D) -> bool:
	if bool(body.get("call_locked")) or bool(body.get("noclip")):
		return false
	if body.has_method("inspecting") and bool(body.call("inspecting")):
		return false
	if is_instance_valid(body.get("seated_on")):
		return false
	return true


func _begin_pass_out(body: CharacterBody3D) -> void:
	if body.has_method("cancel_manipulation"):
		body.call("cancel_manipulation")
	# The controller's own lock: movement and look stop, nothing else changes.
	body.set("call_locked", true)
	_held_player = true
	body.velocity = Vector3.ZERO
	_set_phase("fading")
	passed_out.emit(_radius_m)


func _wake_in_bed(body: CharacterBody3D) -> void:
	_last_wake_ok = false
	var loop: Variant = world.get("core_loop") if world != null else null
	if loop != null and is_instance_valid(loop) and loop.has_method("return_player_to_safe_anchor"):
		_last_wake_ok = bool(loop.call("return_player_to_safe_anchor"))
	if not _last_wake_ok:
		push_error("City edge mist: the 4B bedside is unavailable; the player stays at the edge")
	body.velocity = Vector3.ZERO
	_radius_m = radius_of(body.global_position)
	_set_phase("black")
	woke.emit(body.global_position)


func _release(body: CharacterBody3D) -> void:
	if _held_player and is_instance_valid(body):
		body.set("call_locked", false)
	_held_player = false


func _set_phase(next: String) -> void:
	assert(next in PHASES)
	_phase = next
	_phase_s = 0.0


func _exit_tree() -> void:
	var body: CharacterBody3D = _player()
	if body != null:
		_release(body)


func _build_presentation() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CityEdgeMistLayer"
	_layer.layer = 90
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.name = "Mist"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/city_edge_mist.gdshader") as Shader
	_overlay.material = _material
	_layer.add_child(_overlay)


func _apply_presentation() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("mist", _mist)
	_material.set_shader_parameter("black", _black)
	_material.set_shader_parameter("time_s", _clock_s)
	_layer.visible = _mist > 0.001 or _black > 0.001
