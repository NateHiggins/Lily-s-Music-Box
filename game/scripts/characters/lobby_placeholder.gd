class_name LobbyPlaceholder
extends Node3D
## The first real character mesh in the building, standing in the lobby.
##
## This is a placeholder in the honest sense: it is one static posed mesh out
## of Meshy with no armature and no actions, so it cannot walk, idle, or be
## spoken to. It is here to answer the questions you can only answer by
## standing in front of something — does the scale read, does the lighting
## sit on it, does a real character make this room feel different — and to
## give the character pipeline a target to replace.
##
## Deliberately non-colliding. The generator's movement audit authors every
## clearance in this building and cannot see actors added in Godot, so a
## solid figure dropped into a room is a route the audit believes is clear
## and the player finds blocked. The eighteen resident placeholders already
## follow this rule; so does this.

## Meshy exports with the origin at the mesh's CENTRE, not between the feet,
## so a character placed at floor height stands buried to the waist. Measured
## off the source blend rather than eyeballed: the bounding box runs
## -0.951..+0.948 about the origin.
const FOOT_OFFSET := 0.951
const MODEL := "res://assets/characters/lobby_placeholder/lobby_placeholder.gltf"

var figure: Node3D


## `at` is Blender XY on the lobby floor; `facing` is degrees about up.
func setup(at: Vector2, floor_z: float, facing: float) -> void:
	position = GameBoot.b2g([at.x, at.y, floor_z])
	position.y += FOOT_OFFSET
	rotation.y = deg_to_rad(facing)


func _ready() -> void:
	add_to_group("character_placeholders")
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_warning("lobby placeholder model missing: %s" % MODEL)
		return
	figure = scene.instantiate()
	add_child(figure)
	# One dense static mesh: shadow-casting it would put a 43k-triangle
	# caster inside the lobby chandelier's cube shadow, which is six extra
	# passes over it for a figure standing still against a wall.
	for node in _meshes(figure):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
