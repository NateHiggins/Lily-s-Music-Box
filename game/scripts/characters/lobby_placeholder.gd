class_name LobbyPlaceholder
extends Node3D
## Evelyn Marsh, standing in the lobby while her animation set is judged.
##
## This is a test placement rather than her home — she lives in 1A — and it
## exists because the only way to know whether a clip works is to stand in
## front of it at eye height under the building's own lighting. A turntable
## in Blender will tell you the rig is intact and nothing else.
##
## The model is merged from Meshy's eleven separate exports by
## `art/blender/scripts/merge_meshy_animations.py`: ten clips onto one skin,
## 45k triangles, 11 MB, instead of eleven copies of the same character at
## 82 MB each.
##
## Deliberately non-colliding. The generator's movement audit authors every
## clearance in this building and cannot see actors added in Godot, so a
## solid figure is a route that passes on paper and fails underfoot.

const MODEL := "res://assets/characters/evelyn_marsh/evelyn_marsh.gltf"
## Meshy's *rigged* exports put the origin between the feet, unlike its
## static ones, which centre it on the mesh. Measured, not assumed: her hips
## sit at 0.99 above the origin, which is where hips belong on a standing
## adult.
const FOOT_OFFSET := 0.0
## What plays when nobody is driving her. Renamed to `idle` once the clips
## are identified on screen.
const DEFAULT_CLIP := "clip_01"

var figure: Node3D
var anim: AnimationPlayer
var clips: PackedStringArray = []


## `at` is Blender XY on the lobby floor; `facing` is degrees about up.
func setup(at: Vector2, floor_z: float, facing: float) -> void:
	position = GameBoot.b2g([at.x, at.y, floor_z])
	position.y += FOOT_OFFSET
	rotation.y = deg_to_rad(facing)


func _ready() -> void:
	add_to_group("character_placeholders")
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_warning("lobby character model missing: %s" % MODEL)
		return
	figure = scene.instantiate()
	add_child(figure)
	for node in _meshes(figure):
		# A 45k-triangle caster inside the lobby chandelier's cube shadow is
		# six more passes over her for somebody standing still.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anim = _find_player(figure)
	if anim == null:
		push_warning("lobby character has no AnimationPlayer")
		return
	clips = anim.get_animation_list()
	# Everything here is a loop except the one-shots, and a clip that plays
	# once and freezes reads as the character dying. Looping is the safe
	# default until each clip is identified and classified.
	for name in clips:
		var clip := anim.get_animation(name)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
	print("[EVELYN] %d clips: %s" % [clips.size(), clips])
	play_clip(DEFAULT_CLIP)


func play_clip(clip_name: String) -> bool:
	if anim == null or not anim.has_animation(clip_name):
		return false
	anim.play(clip_name)
	return true


## Test/debug: step to the next clip and report which one is now running.
func next_clip() -> String:
	if anim == null or clips.is_empty():
		return ""
	var here := clips.find(anim.current_animation)
	var next: String = clips[(here + 1) % clips.size()]
	play_clip(next)
	return next


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


## Triangles, for the perf census — a background character that costs more
## than a floor of the building is a thing worth knowing about.
func triangle_count() -> int:
	var total := 0
	for node in _meshes(figure if figure else self):
		if node.mesh:
			for surface in node.mesh.get_surface_count():
				total += node.mesh.surface_get_arrays(surface)[
						Mesh.ARRAY_INDEX].size() / 3
	return total
