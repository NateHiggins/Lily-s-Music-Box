class_name HeightmapPass
extends Node
## Puts the height maps to work.
##
## Ingest derives a height map for every catalog material, ships it, and
## then nothing reads it. Not quite wasted — the tangent normal is derived
## FROM that height, so the information does reach the render — but the
## depth itself never does, and glTF has no channel to carry it, so the
## maps could not survive the export even if the exporter wanted them.
##
## So they are re-attached here, after the floors load, as parallax. The
## material resources come from the glTF import and are shared across every
## instance of a material, which makes this cheap: one assignment per
## material, not per surface.
##
## Only surfaces where relief actually reads are given a map — masonry,
## tile, stone, boards. Parallax on a flat painted wall costs a texture
## fetch per pixel and shows nothing, so plaster and paint are excluded on
## purpose.
##
## The scale is deliberately small. Parallax exaggerates fast, and a brick
## course that swims as you walk past is a worse artefact than one that
## sits flat.

const HEIGHT_DIR := "res://assets/building/textures/height/"

## Per-material depth. These are Godot's heightmap_scale units, whose
## default is 5.0 - not metres, and not the 0-1 the name suggests. The
## first pass used values around 0.02 on the assumption they were UV
## units; the pass ran, reported 98 materials, and moved almost nothing,
## because 0.02 of a scale that defaults to 5 is indistinguishable from
## off.
##
## Mortar joints are the deepest thing on the building. A floorboard seam
## is barely anything, and gets barely anything.
const SCALE := {
	"face_brick": 2.2, "brick": 2.2, "common_brick": 2.2,
	"brick_patched": 2.2, "subway_tile": 1.4, "ceramic": 1.2,
	"terrazzo": 0.5, "stair": 0.8, "landing": 0.6,
	"sidewalk_haunted": 1.0, "asphalt": 0.7, "wet_asphalt": 0.6,
	"concrete": 0.8, "slab": 0.8, "limestone": 0.9,
	"floor_oak": 0.4, "wainscot": 0.7, "tin_ceiling": 1.2,
	"cast_iron": 0.9,
}

var applied := 0
var skipped := 0


func build(floor_nodes: Dictionary) -> int:
	var seen := {}
	for fid in floor_nodes:
		_walk(floor_nodes[fid], seen)
	print("[HEIGHTMAP] %d materials given parallax, %d left flat"
			% [applied, skipped])
	return applied


func _walk(node: Node, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					_apply(mat as StandardMaterial3D, seen)
	for c in node.get_children():
		_walk(c, seen)


func _apply(mat: StandardMaterial3D, seen: Dictionary) -> void:
	# Materials are shared resources: touching one twice is wasted work and
	# double-counts the report.
	var id := mat.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	# The Blender exporter names materials M_<catalog key>, which is the
	# only link back to the ingest set once the glTF has been imported.
	var key := String(mat.resource_name)
	if key.begins_with("M_"):
		key = key.substr(2)
	if not SCALE.has(key):
		skipped += 1
		return
	var path := HEIGHT_DIR + key + ".png"
	if not ResourceLoader.exists(path):
		skipped += 1
		return
	mat.heightmap_enabled = true
	mat.heightmap_texture = load(path)
	mat.heightmap_scale = float(SCALE[key])
	# Deep parallax raymarches and is not worth its cost on a mobile
	# target; the cheap offset is enough to make a mortar joint read.
	mat.heightmap_deep_parallax = false
	mat.heightmap_flip_texture = false
	applied += 1
