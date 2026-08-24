extends Node3D
## H1 — the deforming flesh samples the authored cage, not the room.

const HeroScript := preload("res://scripts/dream/entity/dream_hero_tentacle.gd")

var checks := 0
var failures := 0


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[H1] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _ready() -> void:
	var hero: DreamHeroTentacle = HeroScript.new()
	add_child(hero)
	hero.setup("h1_rest_space".hash(), Vector3.ZERO, Vector3.FORWARD)
	hero.grow = 1.0
	hero.state = hero.State.SEEKING
	hero.state_clock = 0.0
	await get_tree().process_frame

	var cage: MeshInstance3D = null
	for mi in hero.meshes:
		if mi.name == "TENTACLE_BODY_CAGE":
			cage = mi
			break
	_check("production hero has its flesh cage", cage != null)
	if cage == null:
		_finish()
		return

	var arrays: Array = cage.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	_check("rest channels survive on every imported vertex",
			verts.size() > 16000 and cols.size() == verts.size()
			and uvs.size() == verts.size() and uv2s.size() == verts.size())
	var max_error := 0.0
	for i in verts.size():
		var rest_y := (1.0 - uvs[i].y) + (cols[i].g - 0.5) * 0.024
		var stable := Vector3((uv2s[i].x - 0.5) * 0.32,
				(0.5 - uv2s[i].y) * 0.32, -rest_y * 1.60)
		max_error = maxf(max_error, stable.distance_to(verts[i]))
	print("[H1] %d flesh vertices; worst rest decode %.4f mm"
			% [verts.size(), max_error * 1000.0])
	_check("decoded surface is the authored cage (<0.5 mm)", max_error < 0.0005)

	var flesh_mat: ShaderMaterial = cage.material_override
	_check("production defaults to rest-space sampling",
			bool(flesh_mat.get_shader_parameter("flesh_rest_space")))
	var tip_bone: int = hero._bones[hero._bones.size() - 3]
	var origin: Vector3 = hero.skeleton.get_bone_global_pose(tip_bone).origin
	var travel := 0.0
	for _sample in 80:
		await get_tree().create_timer(0.05).timeout
		var here: Vector3 = hero.skeleton.get_bone_global_pose(tip_bone).origin
		travel = maxf(travel, origin.distance_to(here))
	print("[H1] deforming flesh bone travelled %.2f mm while rest decode stayed %.4f mm"
			% [travel * 1000.0, max_error * 1000.0])
	_check("flesh actually moved during the anti-swim proof", travel > 0.005)
	_finish()


func _finish() -> void:
	print("[H1] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
