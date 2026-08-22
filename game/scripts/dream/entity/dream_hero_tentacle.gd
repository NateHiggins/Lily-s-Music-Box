class_name DreamHeroTentacle
extends Node3D
## THE MODELLED HERO, IN THE GAME.
##
## The Blender creature existed as an asset and nothing instantiated it: a
## grep for `dream_tentacle.glb` found exactly one reference, in the test that
## probes it. A hero nobody spawns is a file, not a character.
##
## This puts it in the world and dresses it. Every mesh in the glTF keeps the
## geometry Blender authored and the skin the armature drives, and takes the
## shared Dream material stack through `dream_hero_skin.gdshader`, which reads
## the anatomy from the masks the model carries rather than rediscovering it.
##
## The procedural limb is NOT replaced here: it is shelved (owner ruling
## 2026-08-22) and its grist lives on in DreamSurfaceTendrils. This is the
## thing that ruling made the hero.

const HERO_SCENE := preload("res://assets/dream/tentacle/dream_tentacle.glb")
const SKIN := preload("res://shaders/dream_hero_skin.gdshader")

## Name prefix -> the `system_kind` the skin dresses it as.
const SYSTEMS := {
	"GOLD": 1, "DENDRITE": 1,
	"CRYSTAL": 2,
	"MEMBRANE": 3,
	"SUCKER": 4,
	"CILIUM": 5,
}

var rig: Node3D = null
var meshes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var field = null
var grow := 1.0

var _clock := 0.0
var _seeded := 0.0


func setup(seed_v: int, at: Vector3, aim: Vector3 = Vector3.FORWARD) -> void:
	name = "DreamHeroTentacle"
	_seeded = float(seed_v % 617) * 0.031
	var inst := HERO_SCENE.instantiate()
	add_child(inst)
	rig = inst
	global_position = at
	# THE CREATURE COMES OUT OF A SURFACE. The model is built along +Y with
	# the membrane at the origin, so "emerging" means aligning +Y with the
	# surface normal — not standing it up and letting it lie on the floor
	# like a prop, which is how the first frame in a real room came out.
	if aim.length_squared() > 0.001:
		# The model is built along +Y in Blender, but the glTF axis conversion
		# lands its long axis on -Z in Godot — which is exactly what look_at
		# points at a target. Aligning +Y by hand instead stood the creature
		# bolt upright out of the floor, which the first frame showed plainly.
		var target := at + aim.normalized()
		var up_hint := Vector3.UP if absf(aim.normalized().y) < 0.9 else Vector3.RIGHT
		look_at_from_position(at, target, up_hint)
	_collect(inst)
	_dress()


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child)


func _dress() -> void:
	for mi in meshes:
		var kind := _kind_of(mi.name)
		var mat := ShaderMaterial.new()
		mat.shader = SKIN
		mat.set_shader_parameter("system_kind", kind)
		mat.set_shader_parameter("hero_seed", _seeded)
		# The mineral systems carry the light; the flesh receives it.
		mat.set_shader_parameter("emission_gain", 1.8 if kind == 1 else
				(1.4 if kind == 2 else 1.0))
		mat.set_shader_parameter("grow", grow)
		mi.material_override = mat
		# The creature is placed in a room and must never be culled by a
		# bounding box computed for its rest pose.
		mi.extra_cull_margin = 4.0
		materials.append(mat)


func _kind_of(mesh_name: String) -> int:
	var upper := mesh_name.to_upper()
	for prefix in SYSTEMS:
		if upper.begins_with(prefix) or upper.contains(prefix):
			return int(SYSTEMS[prefix])
	return 0


func _process(delta: float) -> void:
	_clock += delta
	for mat in materials:
		mat.set_shader_parameter("grow", grow)
		if field != null and field.state != null:
			field.apply_to(mat)


## Facts for the contract.
func census() -> Dictionary:
	var skinned := 0
	for mi in meshes:
		if mi.skin != null:
			skinned += 1
	return {"meshes": meshes.size(), "skinned": skinned,
			"materials": materials.size(), "grow": grow}
