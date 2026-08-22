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
## The armature, and its deform bones in order from root to tip.
var skeleton: Skeleton3D = null
var _bones: PackedInt32Array = PackedInt32Array()
var _rest: Array[Quaternion] = []
## Where the creature is currently attending. Its own, not the player's.
var _attend := Vector3.ZERO
var _attend_clock := 0.0
var _settle := 0.0


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
	_find_skeleton(inst)


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


## THE RIG, FOUND AND ORDERED.
##
## The creature shipped with twenty-eight deform bones, nine secondary
## controls and rotation limits on the root -- and nothing driving any of
## them. It stood in the room at rest pose, which the owner spotted
## immediately: "the new tentacle is not animated at all".
func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node as Skeleton3D
	else:
		for child in node.get_children():
			_find_skeleton(child)
			if skeleton != null:
				return
		return
	# Deform bones in order along the limb. The glTF keeps Blender's names.
	var named: Array = []
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		if n.begins_with("DEF_"):
			named.append([n, i])
	named.sort_custom(func(a, b): return _bone_order(a[0]) < _bone_order(b[0]))
	for pair in named:
		_bones.append(int(pair[1]))
		_rest.append(skeleton.get_bone_pose_rotation(int(pair[1])))


## DEF_<label>_<index>: the labels run root to tip in BONE_PLAN order.
func _bone_order(bone_name: String) -> float:
	const ORDER := ["ROOT", "PROX", "OCULAR", "MID", "DISTAL", "TIP"]
	var parts := bone_name.split("_")
	var label := parts[1] if parts.size() > 2 else ""
	var idx := float(parts[parts.size() - 1].to_int())
	var band := float(ORDER.find(label.to_upper()))
	if band < 0.0:
		band = 9.0
	return band * 100.0 + idx


## The motion language (§13): THIS ORGANISM IS CONTINUOUSLY SAMPLING.
##
## Not idle noise. It holds a search posture, commits to a direction, reaches,
## settles, and picks somewhere new — and a peristaltic wave runs out along
## it the whole time, because that is how the length of a limb like this
## actually carries force. The root barely moves: the membrane grips it.
func _animate(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	var n := _bones.size()
	_attend_clock -= delta
	if _attend_clock <= 0.0:
		# Choose somewhere new to attend to, and take a moment over it.
		_attend_clock = 2.6 + fmod(absf(sin(_clock * 12.7 + _seeded)) * 3.4, 3.4)
		_attend = Vector3(sin(_clock * 1.7 + _seeded * 3.1),
				sin(_clock * 0.9 + _seeded), cos(_clock * 1.3 + _seeded * 2.2))
		_settle = 0.0
	_settle = minf(1.0, _settle + delta * 0.85)
	# The reach eases in, then holds: committed, not oscillating.
	var reach: float = smoothstep(0.0, 1.0, _settle)
	for i in n:
		var t := float(i) / float(maxi(1, n - 1))
		# The collar grips the root. This is the rotation limit Blender
		# carries as a constraint, which glTF does not export -- so it lives
		# here too, or the limb tears through its own membrane.
		var grip: float = smoothstep(0.0, 0.16, t)
		# A peristaltic wave travelling OUT along the limb.
		var wave: float = sin(t * 9.0 - _clock * 2.1 + _seeded) * 0.034
		# The search: the distal third does the fine work, the shaft carries it.
		var fine: float = smoothstep(0.55, 1.0, t)
		var bend_x: float = (_attend.x * 0.115 * reach * (0.35 + fine)
				+ wave) * grip
		var bend_z: float = (_attend.z * 0.115 * reach * (0.35 + fine)
				+ wave * 0.7) * grip
		# Breathing: the whole body swells and settles under the search.
		var breathe: float = sin(_clock * 0.8 + t * 2.0) * 0.006 * grip
		var q := Quaternion(Vector3.RIGHT, bend_x + breathe) 				* Quaternion(Vector3.FORWARD, bend_z) 				* Quaternion(Vector3.UP, _attend.y * 0.02 * reach * fine * grip)
		skeleton.set_bone_pose_rotation(_bones[i], _rest[i] * q)


func _process(delta: float) -> void:
	_clock += delta
	_animate(delta)
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
			"materials": materials.size(), "grow": grow,
			"deform_bones": _bones.size(),
			"skeleton": skeleton != null}
