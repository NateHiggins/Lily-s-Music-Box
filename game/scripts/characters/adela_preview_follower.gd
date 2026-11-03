extends CharacterBody3D
## Temporary owner-requested model preview. No schedule, dialogue or save owner.
const MODEL := "res://assets/characters/adela_voss/adela_voss.glb"
const FINISH := "resident_adela_voss"
const FOLLOW_DISTANCE := 1.8
const MAX_TRAIL := 512
const STEP_HEIGHT := .22
var world: Node3D
var player: PlayerController
var model: Node3D
var animation: AnimationPlayer
var trail: Array[Vector3] = []
var queued_metres := 0.0
var last_sample := Vector3.ZERO
var trail_lost := false
var spawned := false
var _shape := CapsuleShape3D.new()

func setup(owner_world: Node3D) -> void:
	world=owner_world;player=world.player
	collision_layer=0;collision_mask=1
	_shape.radius=ResidentNav.RESIDENT_BODY_RADIUS
	_shape.height=ResidentNav.RESIDENT_BODY_HEIGHT
	var solid:=CollisionShape3D.new();solid.shape=_shape;solid.position.y=_shape.height*.5
	add_child(solid);add_collision_exception_with(player)
	visible=false
	if OS.get_environment("ORISON_ADELA_FOLLOW")=="0":set_physics_process(false)

func _presentation_allowed() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(player) or world.startup_failed:return false
	var director: Node=world.get("prologue_director")
	if is_instance_valid(director):return str(director.state.get("phase",""))=="prologue_complete"
	var shell:=get_tree().get_first_node_in_group("campaign_shell")
	return shell==null or not shell.uses_prologue_entry()

func _load_model() -> bool:
	var packed:=load(MODEL) as PackedScene
	if packed==null:return false
	model=packed.instantiate();add_child(model)
	_bind_materials(model)
	animation=_find_animation(model)
	if animation==null:return false
	var library:=animation.get_animation_library("").duplicate(false) as AnimationLibrary
	animation.remove_animation_library("");animation.add_animation_library("",library)
	for clip: String in ["adela_idle","adela_walking","adela_running"]:
		if not animation.has_animation(clip):return false
		var original:=animation.get_animation(clip)
		var local:=original.duplicate(true) as Animation;local.loop_mode=Animation.LOOP_LINEAR
		library.remove_animation(clip);library.add_animation(clip,local)
	_motion("adela_idle",0.0);animation.advance(0)
	return true

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found:=_find_animation(child)
		if found!=null:return found
	return null

func _bind_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var finish:=MatLib.get_mat(FINISH).duplicate() as StandardMaterial3D
		finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE
		finish.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		finish.emission_enabled=true;finish.emission=AnimatedResident.PRESENCE_GLOW
		for surface in node.mesh.get_surface_count():node.set_surface_override_material(surface,finish)
		node.set_meta("material_key",FINISH);node.set_meta("v2_resident_atlas",true)
	for child in node.get_children():_bind_materials(child)

func _floor_at(point: Vector3) -> Dictionary:
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.35,point-Vector3.UP*.6,1)
	ray.exclude=[player.get_rid(),get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray)

func _clear(from: Vector3,to: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=_shape;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,from+Vector3.UP*(_shape.height*.5+.015))
	query.motion=to-from;query.margin=0.;query.exclude=[player.get_rid(),get_rid()]
	var space:=get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty():return false
	var fractions:=space.cast_motion(query)
	return fractions.size()==2 and fractions[0]>=.99999

func _spawn_near_player() -> bool:
	var behind:=player.global_basis.z;behind.y=0.;behind=behind.normalized()
	for offset: Vector3 in [behind*1.6,player.global_basis.x*1.5,-player.global_basis.x*1.5,-behind*1.6]:
		var floor:=_floor_at(player.global_position+offset)
		if floor.is_empty() or floor.normal.y<.65:continue
		var candidate: Vector3=floor.position
		if absf(candidate.y-player.global_position.y)>.25 or not _clear(candidate,player.global_position):continue
		global_position=candidate+Vector3.UP*.015
		last_sample=player.global_position;trail.assign([last_sample]);queued_metres=0.
		spawned=true;return true
	return false

func _grounded_player_point() -> Vector3:
	# The player's step assist transiently lifts its foot above the floor.
	# Queue the witnessed support, not that transient airborne height. Wait
	# through unsupported motion instead of inventing a walkable bridge.
	var point:=player.global_position
	if point.distance_to(last_sample)<=.25:return last_sample
	var support:=_floor_at(point)
	if support.is_empty() or support.normal.y<.65:return last_sample
	point.y=support.position.y
	return point

func _motion(clip: String,speed: float) -> void:
	if animation==null:return
	if animation.current_animation!=clip:animation.play(clip,.2)
	animation.speed_scale=1. if clip=="adela_idle" else clampf(speed/(2.8 if clip=="adela_running" else 1.1),.65,1.8)

func _physics_process(delta: float) -> void:
	if not _presentation_allowed():
		visible=false;velocity=Vector3.ZERO;return
	if model==null and not _load_model():
		push_error("Adela preview model or personal clips refused");set_physics_process(false);return
	if not spawned and not _spawn_near_player():return
	visible=true
	if player.protected_input_active() or player.text_input_owner!=null:
		velocity=Vector3.ZERO;_motion("adela_idle",0.);return
	var point:=_grounded_player_point()
	if point.distance_to(last_sample)>2.5:trail_lost=true
	if trail_lost and point.distance_to(last_sample)<1.0 and _clear(last_sample,point):trail_lost=false
	if not trail_lost and point.distance_to(last_sample)>.25:
		if trail.size()>=MAX_TRAIL:trail_lost=true
		else:
			if not trail.is_empty():queued_metres+=trail[-1].distance_to(point)
			trail.append(point);last_sample=point
	while trail.size()>1 and Vector2(global_position.x-trail[0].x,global_position.z-trail[0].z).length()<.14 and absf(global_position.y-trail[0].y)<=STEP_HEIGHT+.03:
		queued_metres=maxf(0.,queued_metres-trail[0].distance_to(trail[1]));trail.pop_front()
	var target: Vector3=trail[0] if not trail.is_empty() else global_position
	var distance:=global_position.distance_to(target)+queued_metres
	var direction:=target-global_position;direction.y=0.
	var speed:=5.0 if distance>5.0 else 2.0
	var moving:=distance>FOLLOW_DISTANCE and direction.length()>.03
	var motion:=direction.normalized()*minf(speed,direction.length()/maxf(delta,.001))*delta if moving else Vector3.ZERO
	if moving and is_on_floor() and test_move(global_transform,motion):
		var floor:=_floor_at(global_position+motion+direction.normalized()*(_shape.radius+.05))
		if not floor.is_empty():
			var rise: float=floor.position.y-global_position.y
			if rise>.015 and rise<=STEP_HEIGHT and not test_move(global_transform,Vector3.UP*(rise+.015)) and not test_move(global_transform.translated(Vector3.UP*(rise+.015)),motion):
				global_position.y+=rise+.015
	velocity.x=motion.x/maxf(delta,.001);velocity.z=motion.z/maxf(delta,.001)
	velocity.y-=PlayerController.GRAVITY*delta
	var before:=global_position;move_and_slide()
	var actual:=Vector2(global_position.x-before.x,global_position.z-before.z).length()/maxf(delta,.001)
	_motion("adela_idle" if actual<.05 else "adela_running" if actual>2.5 else "adela_walking",actual)
	var look:=direction if actual>.05 else player.global_position-global_position
	if Vector2(look.x,look.z).length()>.1:rotation.y=lerp_angle(rotation.y,atan2(look.x,look.z),minf(1.,delta*6.))
