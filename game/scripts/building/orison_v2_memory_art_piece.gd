extends "res://scripts/props/character_memory_art.gd"
## One of the residents' memory-art pieces as V2 hangs it. V1's
## CharacterMemoryArt keeps the piece's identity (its id, medium, wall or
## tabletop placement, collection and group); what V1 drew is replaced: the
## BoxMesh bars by the Blender frame, and the picture, which was a quadrant of
## a generated image atlas, by a blank mount (RUL-007, RUL-008).

## [{mesh, finish, pose, part}] from the composer.
var stock: Array = []
var reach := 14.0
var draws: Array[MeshInstance3D] = []


func _ready() -> void:
	name = "MemoryArt_" + art_id
	add_to_group(collection)
	for part: Dictionary in stock:
		var draw := MeshInstance3D.new()
		draw.name = str(part.part)
		draw.mesh = part.mesh
		draw.material_override = part.finish
		draw.transform = part.pose
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visibility_range_end = reach
		add_child(draw)
		draws.append(draw)
