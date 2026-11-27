extends AnimatedResident
## Presentation adapter only. Original V1 rigs, personal moves and interaction
## authorities remain owners; each actor receives a local V2 atlas material.
var _local_libraries: Dictionary = {}
var _local_loops: Dictionary = {}
var _loop_activity := ""
var _loop_activity_clip := ""
var _loop_sewing := false
const SewingHands := preload("res://scripts/characters/sewing_hand_contact.gd")
var _sewing_hands: RefCounted
const SewingSeatPose := preload("res://scripts/characters/sewing_seat_pose.gd")
const SewingSeatFeet := preload("res://scripts/characters/sewing_seat_feet.gd")
var _sewing_seat_blend: RefCounted
var _sewing_seat_feet: RefCounted
var _sewing_seat_contact: RefCounted
var _sewing_seat_machine: Node3D
var _sewing_seat_chair: Node3D
var _sewing_seat_working := false
var _sewing_seat_previous_idle := ""
var _sewing_seat_recovery_only := false
var _sewing_seat_phase_locked := false
var _sewing_seat_playback_scale := 1.0

## The route owns the actual chair lease, actor root and collision sweeps.
## This pure preflight rejects bad geometry/leg reach without posing a bone.
## Initialize the lease at amount0 before querying positive candidate amounts.
func can_set_sewing_seat_pose(machine: Node3D, chair: Node3D, candidate: Transform3D, amount: float) -> bool:
	if not _sewing_seat_inputs(machine,chair,amount) or not candidate.is_finite():return false
	if not candidate.basis.is_finite() or candidate.basis.determinant()<.99 or candidate.basis.determinant()>1.01:return false
	var local:=machine.to_local(candidate.origin)
	if local.x<-.1 or local.x>.65 or local.z<-.85 or local.z>-.30 or absf(local.y)>.02:return false
	if amount>=1.0:
		var end:=chair.global_position-machine.global_basis.y*.0075
		if candidate.origin.distance_to(end)>.002:return false
	if _sewing_seat_blend==null:return amount==0.0
	if machine!=_sewing_seat_machine or chair!=_sewing_seat_chair:return false
	if _sewing_seat_recovery_only and amount>float(_sewing_seat_blend.amount):return false
	if not _sewing_seat_feet.source_valid():return false
	var standing: Animation=_animation_player.get_animation("clip_03")
	var seconds:=_animation_player.current_animation_position if str(_animation_player.current_animation)=="clip_03" else 0.0
	var body: Skeleton3D=cast_body.skeleton
	var poses: Array[Transform3D]=_sewing_seat_blend.predicted_globals(body,standing,seconds,amount)
	var relative:=global_transform.affine_inverse()*body.global_transform
	return _sewing_seat_feet.can_reach(poses,candidate*relative,amount)

func _sewing_seat_inputs(machine: Node3D, chair: Node3D, amount: float) -> bool:
	if resident_id!="lena_ortiz" or not is_finite(amount) or amount<0.0 or amount>1.0:return false
	if not is_instance_valid(machine) or not is_instance_valid(chair) or machine==chair:return false
	if not machine.is_inside_tree() or not chair.is_inside_tree() or not is_inside_tree():return false
	if _walking or cast_body==null or attention==null or attention.pipeline==null or _animation_player==null:return false
	if not _animation_player.has_animation("clip_03") or not _animation_player.has_animation("clip_06"):return false
	var relative:=machine.global_transform.affine_inverse()*chair.global_transform
	if relative.origin.distance_to(Vector3(0,0,-.6759))>.02:return false
	if relative.basis.y.normalized().dot(Vector3.UP)<.999 or relative.basis.z.normalized().dot(Vector3.BACK)>-.999:return false
	if machine.global_basis.y.normalized().dot(Vector3.UP)<.999:return false
	var pipeline=attention.pipeline
	if pipeline.sewing_seat!=null and pipeline.sewing_seat!=_sewing_seat_blend:return false
	if pipeline.seated_feet!=null and pipeline.seated_feet!=_sewing_seat_feet:return false
	if pipeline.work_hands!=null and pipeline.work_hands!=_sewing_seat_contact and pipeline.work_hands!=_sewing_hands:return false
	return true

## Amount is continuous, including exact0/1. This adapter never changes root.
## False is atomic: no pose, animation, existing lease or helper installation.
func set_sewing_seat_pose(machine: Node3D, chair: Node3D, amount: float, working: bool) -> bool:
	if _sewing_seat_recovery_only and working:return false
	if not can_set_sewing_seat_pose(machine,chair,global_transform,amount):return false
	if _sewing_seat_blend==null:
		var blend:=SewingSeatPose.new()
		var feet:=SewingSeatFeet.new()
		feet.pose_owner=blend
		var contact:=SewingHands.new();contact.seated=true
		contact.seated_pose_allowed=_sewing_seat_live
		contact.posture_allowed=_sewing_seat_live
		if not blend.bind(cast_body.skeleton,_animation_player.get_animation("clip_06"),_sewing_seat_live):return false
		if not feet.bind(cast_body,machine,_sewing_seat_live):return false
		if not contact.bind(cast_body.skeleton,machine,_sewing_seat_work_allowed,cast_body.model):return false
		var relative:=global_transform.affine_inverse()*cast_body.skeleton.global_transform
		var endpoint:=Transform3D(chair.global_basis*Basis(Vector3.UP,PI),chair.global_position-machine.global_basis.y*.0075)
		var poses: Array[Transform3D]=blend.predicted_globals(cast_body.skeleton,_animation_player.get_animation("clip_03"),0.0,1.0)
		feet.prepare_end(poses,endpoint*relative)
		# All fallible resource checks completed before touching the live owner.
		clear_loop_activity()
		_local_loop("clip_03")
		_sewing_seat_previous_idle=preferred_idle
		preferred_idle="clip_03"
		_sewing_seat_machine=machine;_sewing_seat_chair=chair
		_sewing_seat_blend=blend;_sewing_seat_feet=feet;_sewing_seat_contact=contact
		attention.pipeline.sewing_seat=blend
		attention.pipeline.seated_feet=feet
		attention.pipeline.work_hands=contact
		if str(_animation_player.current_animation)!="clip_03":_animation_player.play("clip_03",.22)
	if amount>0.0 and amount<1.0 and not _sewing_seat_phase_locked:
		_sewing_seat_playback_scale=_animation_player.speed_scale
		_animation_player.speed_scale=0.0
		_sewing_seat_phase_locked=true
	_sewing_seat_blend.hold_phase=amount>0.0 and amount<1.0
	_sewing_seat_blend.amount=amount
	_sewing_seat_feet.amount=amount
	_sewing_seat_contact.posture_amount=amount
	_sewing_seat_working=working
	return true

func _sewing_seat_live() -> bool:
	return _sewing_seat_blend!=null and not _walking \
		and _animation_player!=null and str(_animation_player.current_animation)=="clip_03"

func _sewing_seat_work_allowed() -> bool:
	return _sewing_seat_live() and _sewing_seat_working and _sewing_seat_blend.amount>=1.0 \
		and _sewing_seat_feet!=null and _sewing_seat_feet.source_valid() \
		and not _sewing_seat_recovery_only and is_visible_in_tree() and is_instance_valid(_sewing_seat_machine) and is_instance_valid(_sewing_seat_chair) and not _loop_talking()

func stop_sewing_seat_work() -> void:
	_sewing_seat_working=false

## Emergency reverse only, for a genuine external outfit/mesh change. Rebind
## the actual known shoe in temporary storage; never reuse stale landmarks,
## change clothing, move root, resume work or accept an unreachable leg.
func recover_sewing_seat_support() -> bool:
	if _sewing_seat_blend==null or _sewing_seat_feet==null or _sewing_seat_feet.source_valid():return false
	var amount: float=_sewing_seat_blend.amount
	if not _sewing_seat_inputs(_sewing_seat_machine,_sewing_seat_chair,amount):return false
	var feet:=SewingSeatFeet.new()
	feet.pose_owner=_sewing_seat_blend
	if not feet.bind(cast_body,_sewing_seat_machine,_sewing_seat_live):return false
	feet.copy_transition(_sewing_seat_feet)
	var body: Skeleton3D=cast_body.skeleton
	var seconds:=_animation_player.current_animation_position
	var poses: Array[Transform3D]=_sewing_seat_blend.predicted_globals(body,_animation_player.get_animation("clip_03"),seconds,amount)
	if not feet.can_reach(poses,body.global_transform,amount):return false
	feet.amount=amount
	# All fallible validation precedes replacing our own contact slot.
	_sewing_seat_working=false
	_sewing_seat_recovery_only=true
	_sewing_seat_feet=feet
	attention.pipeline.seated_feet=feet
	return true

func clear_sewing_seat_pose() -> void:
	if _sewing_seat_blend==null:return
	if _sewing_seat_blend.amount<=0.0 and _sewing_seat_feet!=null and _sewing_seat_feet.source_valid() and walking_feet!=null:
		var planted: Array[Transform3D]=[]
		for leg: Dictionary in _sewing_seat_feet.legs:
			if leg.has("start"):planted.append(leg.start)
		if planted.size()==2:walking_feet.accept_sewing_seat_handoff(self,_sewing_seat_blend,planted)
	if is_instance_valid(attention):
		var pipeline=attention.pipeline
		if pipeline.sewing_seat==_sewing_seat_blend:pipeline.sewing_seat=null
		if pipeline.seated_feet==_sewing_seat_feet:pipeline.seated_feet=null
		if pipeline.work_hands==_sewing_seat_contact:pipeline.work_hands=null
	preferred_idle=_sewing_seat_previous_idle
	if _sewing_seat_phase_locked and _animation_player!=null:_animation_player.speed_scale=_sewing_seat_playback_scale
	_sewing_seat_phase_locked=false
	_sewing_seat_previous_idle=""
	_sewing_seat_recovery_only=false
	_sewing_seat_blend=null;_sewing_seat_feet=null;_sewing_seat_contact=null
	_sewing_seat_machine=null;_sewing_seat_chair=null;_sewing_seat_working=false

static func roster() -> Array[Dictionary]:
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/resident_animation_profiles.json"))
	var schedules: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			ScheduleDirector.SCHEDULE_PATH))
	var result: Array[Dictionary] = []
	if profiles is not Array or schedules is not Dictionary: return result
	for profile: Dictionary in profiles:
		var slug := str(profile.slug)
		if not schedules.residents.has(slug): return []
		# The old body must still be there (it is the fallback); a listed resident is built from the rebuilt one.
		var old_model := CastBodies.old_model(slug)
		if not ResourceLoader.exists(old_model) or not MatLib.SETS.has("resident_" + slug): return []
		var model := CastBodies.model_for(slug)
		result.append({"id": slug, "display": str(profile.display),
			"unit": str(schedules.residents[slug].unit), "model": model})
	return result if result.size() == 18 else []

func _ready() -> void:
	# Bare imported clips use clip_01..08, rather than a literal "idle".
	# Keep the existing per-resident temperament and personal rest-correct bake.
	var roles: Dictionary = ResidentRoutines.CHARACTER_ROLES.get(resident_id, {})
	preferred_idle = str(ResidentRoutines.ROLES.get(str(roles.get("idle", "idle")), "clip_01"))
	preferred_walk = "walk"
	super._ready()
	if mina_animation == null and _animation_player != null:
		_local_loop(preferred_idle)
		_local_loop(preferred_walk)
		_play_named("idle")

## Sit, and stay sitting, on a looped seated clip (the luncheonette's stools). Mina's own behaviour puts her back
## on her standing idle every frame, and a seated body is never walked, so it sets that behaviour aside.
func hold_seated(clip: String, immediate: bool = false) -> bool:
	if not _local_loop(clip):
		return false
	mina_animation = null
	preferred_idle = clip
	_play_named("idle")
	if immediate:
		# A freshly spawned counter resident is already sitting, not arriving
		# through a standing-to-seated blend with temporarily unreachable feet.
		_animation_player.stop(true)
		_animation_player.play(clip, 0.0)
		_animation_player.advance(0.0)
	return true

func _local_loop(clip: String) -> bool:
	if _animation_player == null or not _animation_player.has_animation(clip): return false
	if _local_loops.has(clip): return true
	var library_name := clip.get_slice("/", 0) if clip.contains("/") else ""
	var animation_name := clip.get_slice("/", 1) if clip.contains("/") else clip
	if not _local_libraries.has(library_name):
		# Evelyn's embedded library is shared by the imported PackedScene.
		# Duplicate its dictionary, then only the clips this actor actually uses.
		var local_library := _animation_player.get_animation_library(library_name).duplicate(false) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, local_library)
		_local_libraries[library_name] = local_library
	var library: AnimationLibrary = _local_libraries[library_name]
	var animation := library.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	library.remove_animation(animation_name); library.add_animation(animation_name, animation)
	_local_loops[clip] = true
	return true

## An arrived resident may wait attentively between their ordinary tasks.
## Sewing is a bounded owner request at Lena's arrived historical work mark;
## the existing handwork clip claims no needle grip, prop movement or sitting.
func set_loop_activity(activity: String, sewing: bool = false, work_surface: Node3D = null) -> void:
	if _sewing_seat_blend!=null:return
	if resident_id == "mina_vale" or mina_animation != null: return
	if activity.is_empty():
		clear_loop_activity()
		return
	if _animation_player == null: return
	if _walking or _loop_talking() or _loop_seated():
		clear_loop_activity()
		return
	var clip := "clip_03"
	var handwork := sewing and resident_id == "lena_ortiz" and activity == "work"
	if handwork:
		clip = "clip_07" # Counter-height handwork, NOT her shoulder-height busy/reach role.
	elif activity in ["rest", "idle", "resting"]:
		# Some personal idles are working clips. Do not borrow those as a
		# performed chore when no corresponding contact has been authored.
		clip = preferred_idle if preferred_idle in ["clip_01", "clip_02", "clip_03", "clip_04", "clip_05"] else "clip_01"
	if _loop_activity == activity and _loop_activity_clip == clip \
			and str(_animation_player.current_animation) == clip and _animation_player.is_playing():
		if handwork: _bind_sewing_hands(work_surface)
		return
	if not _local_loop(clip):
		clear_loop_activity()
		return
	_loop_activity = activity
	_loop_activity_clip = clip
	_loop_sewing = handwork
	if handwork: _bind_sewing_hands(work_surface)
	else: _release_sewing_hands()
	# Different authored tasks may share the same attentive attitude; do
	# not restart its motion just because the schedule's wording changed.
	if str(_animation_player.current_animation) != clip or not _animation_player.is_playing():
		_animation_player.play(clip, .22)

func clear_loop_activity() -> void:
	_release_sewing_hands()
	var owned_clip := _loop_activity_clip
	var was_sewing := _loop_sewing
	_loop_activity = ""
	_loop_activity_clip = ""
	_loop_sewing = false
	if resident_id == "mina_vale" or mina_animation != null or _animation_player == null: return
	# Another owner may already have started walking, talking or sitting.
	# Only release the clip we actually borrowed, leaving their clip alone.
	if not owned_clip.is_empty() and not _walking \
			and str(_animation_player.current_animation) == owned_clip:
		# Lena's personal idle is itself clip_07. Restoring it here would put
		# her hands straight back to work during dialogue or after cancellation.
		if was_sewing and _local_loop("clip_03"):
			_animation_player.play("clip_03", .22)
		else:
			_play_named("idle")

func _bind_sewing_hands(work_surface: Node3D) -> void:
	if not is_instance_valid(work_surface) or cast_body == null or attention == null:
		_release_sewing_hands()
		return
	if _sewing_hands != null and _sewing_hands.surface == work_surface: return
	_release_sewing_hands()
	var contact := SewingHands.new()
	if contact.bind(cast_body.skeleton, work_surface, _sewing_contact_allowed,cast_body.model):
		_sewing_hands = contact
		attention.pipeline.work_hands = contact

func _release_sewing_hands() -> void:
	if _sewing_hands != null and is_instance_valid(attention) and attention.pipeline.work_hands == _sewing_hands:
		attention.pipeline.work_hands = null
	_sewing_hands = null

func _sewing_contact_allowed() -> bool:
	return _loop_sewing and not _walking and is_visible_in_tree() and not _loop_talking() \
			and not _loop_seated() and _animation_player != null \
			and str(_animation_player.current_animation) == _loop_activity_clip

func _loop_talking() -> bool:
	if is_instance_valid(attention) and bool(attention.get("conversing")): return true
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	return player != null and player.call_locked and not ResidentConversations.permits_background_work(self, player)

func _loop_seated() -> bool:
	var clip := str(_animation_player.current_animation) if _animation_player != null else ""
	return clip == "clip_06" or clip.ends_with("/clip_06")

func _process(delta: float) -> void:
	super._process(delta)
	if _sewing_seat_blend!=null and not _sewing_seat_live():clear_sewing_seat_pose()
	if not _loop_activity.is_empty() and (_walking or _loop_talking() or _loop_seated()):
		clear_loop_activity()

func _set_walking(on: bool) -> void:
	if on and _sewing_seat_blend!=null:clear_sewing_seat_pose()
	if on and not _loop_activity.is_empty(): clear_loop_activity()
	super._set_walking(on)

func play_case_role(fragment: String) -> bool:
	if _sewing_seat_blend!=null:return false
	if not _loop_activity.is_empty(): clear_loop_activity()
	return super.play_case_role(fragment)

## A stage gesture never takes a seated body or a clip a loop activity has borrowed.
func _emote_allowed() -> bool:
	return super._emote_allowed() and _loop_activity.is_empty() and not _loop_seated() and _sewing_seat_blend==null

func play_seated() -> bool:
	if _sewing_seat_blend!=null:return false
	# Mina's supplied twenty clips have no seated motion. Her owner retains
	# its own idle and standing spot; never graft a retired donor pose onto her.
	if mina_animation != null or not _local_loop("clip_06"): return false
	clear_loop_activity()
	_animation_player.play("clip_06", .25)
	var animation := _animation_player.get_animation("clip_06")
	# Deterministic per-person phase avoids a room of synchronized gestures.
	_animation_player.seek(animation.length * float(resident_id.hash() & 65535) / 65536.0, true)
	return true

func _apply_presence_glow(node: Node) -> void:
	if node is MeshInstance3D:
		var draw := node as MeshInstance3D
		if resident_id == "jonah_price": _repair_atlas_uv(draw)
		var key := "resident_" + resident_id
		for surface in draw.mesh.get_surface_count():
			var original := draw.get_active_material(surface) as StandardMaterial3D
			var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			finish.uv1_triplanar = false
			finish.uv1_scale = Vector3.ONE
			finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if original != null: finish.cull_mode = original.cull_mode
			finish.emission_enabled = true
			finish.emission = PRESENCE_GLOW
			finish.emission_energy_multiplier = 1.0
			draw.set_surface_override_material(surface, finish)
		draw.set_meta("material_key", key)
		draw.set_meta("v2_resident_atlas", true)
	for child in node.get_children(): _apply_presence_glow(child)

func _repair_atlas_uv(draw: MeshInstance3D) -> void:
	# Blender-authored UV-only repair. Keep the approved rig and all skin,
	# geometry, blend shapes and original shared mesh data byte-for-byte.
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/orison_v2/resident_atlas_uv_repair.json"))
	if source.schema_version != 1 or source.resident != resident_id \
			or source.source != model_path or FileAccess.get_sha256(model_path) != source.source_sha256:
		push_error("Resident UV repair source changed"); return
	var local := draw.mesh.duplicate() as ArrayMesh
	for surface in local.get_surface_count():
		var arrays := local.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var changed := 0
		var repaired_vertices := {}
		for repair: Dictionary in source.repairs:
			if int(repair.native_loops) != 1:
				push_error("Resident UV repair no longer has a single native corner"); return
			var at := Vector3(repair.position[0], repair.position[1], repair.position[2])
			var before := Vector2(repair.before[0], repair.before[1])
			var after := Vector2(repair.after[0], repair.after[1])
			for index in vertices.size():
				if vertices[index].distance_to(at) < .00001 and uvs[index].distance_to(before) < .0001:
					uvs[index] = after; changed += 1; repaired_vertices[index] = true
		if changed == 0: push_error("Resident UV repair vertex not found"); continue
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		# Renew only the repaired face's tangent frame; keep every other
		# authored normal/tangent and all skin attributes unchanged.
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for face in range(0, indices.size(), 3):
			var a := indices[face]; var b := indices[face+1]; var c := indices[face+2]
			if not repaired_vertices.has(a) and not repaired_vertices.has(b) and not repaired_vertices.has(c): continue
			var u := uvs[b]-uvs[a]; var v := uvs[c]-uvs[a]
			var determinant := u.cross(v)
			if absf(determinant) < 1e-12: push_error("Native UV repair remains degenerate"); return
			var edge := vertices[b]-vertices[a]; var other := vertices[c]-vertices[a]
			var tangent := (edge*v.y-other*u.y)/determinant
			var bitangent := (other*u.x-edge*v.x)/determinant
			for vertex: int in [a,b,c]:
				var normal := normals[vertex]
				var direction := (tangent-normal*normal.dot(tangent)).normalized()
				tangents[vertex*4] = direction.x; tangents[vertex*4+1] = direction.y; tangents[vertex*4+2] = direction.z
				tangents[vertex*4+3] = -1.0 if normal.cross(direction).dot(bitangent) < 0 else 1.0
		arrays[Mesh.ARRAY_TANGENT] = tangents
		# The approved character is one surface, no blend shapes. Rebuild only
		# the local arrays so imported compressed buffers remain untouched.
		if local.get_surface_count() != 1 or local.get_blend_shape_count() != 0:
			push_error("Resident UV repair mesh ABI changed"); return
		var material := local.surface_get_material(surface)
		var original_surface: Dictionary = local.get("_surfaces")[surface]
		var shadow := local.shadow_mesh
		local.clear_surfaces()
		local.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# UV repair doesn't change vertex numbering. Retain the imported LOD
		# index buffers and position-only shadow mesh for distant residents.
		var rebuilt: Array = local.get("_surfaces")
		rebuilt[0].lods = original_surface.get("lods", {}).duplicate(true)
		local.clear_surfaces(); local.set("_surfaces", rebuilt)
		local.shadow_mesh = shadow
		local.surface_set_material(0, material)
		draw.set_meta("native_uv_repairs", changed)
		draw.mesh = local
