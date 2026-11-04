extends Node3D
## Isolated real-controller follow/obstacle/step/pause diagnostic, not world proof.
const Follower:=preload("res://scripts/characters/adela_preview_follower.gd")
class FixtureDirector extends Node:
	var state: Dictionary={"phase":"bedroom"}
class FixtureWorld extends Node3D:
	var player: PlayerController
	var prologue_director: Node
	var startup_failed:=false
var failures: Array[String]=[]
var checks:=0
var world: FixtureWorld
var player: PlayerController
var follower: CharacterBody3D
var wall_crossed:=false
var observations: Array[Dictionary]=[]

func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);push_error("ADELA FOLLOW: "+label)
	return ok

func _box(at: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=at
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	var draw:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;draw.mesh=mesh;body.add_child(draw)
	world.add_child(body);return body

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	RealityState.persistence_enabled=false
	world=FixtureWorld.new();world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
	_box(Vector3(0,-.1,0),Vector3(20,.2,20))
	_box(Vector3(1,.9,-2.5),Vector3(.2,1.8,3))
	_box(Vector3(5.5,.075,-5),Vector3(.7,.15,2))
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.;world.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.08,.09,.11);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.7,.7,.7);env.environment.ambient_light_energy=.45;world.add_child(env)
	player=PlayerController.new();player.position=Vector3(0,.02,0);world.add_child(player);world.player=player
	player.camera.make_current();player.set_mouse_released(false)
	var director:=FixtureDirector.new();world.add_child(director);world.prologue_director=director
	follower=Follower.new();world.add_child(follower);follower.setup(world)
	for frame in 3:await get_tree().physics_frame
	check(follower.model==null and not follower.visible,"prologue suppresses preview without creating a second character")
	director.state["phase"]="prologue_complete"
	for frame in 12:await get_tree().physics_frame
	var before: Dictionary=RealityState.data.duplicate(true)
	if check(follower.model!=null and follower.spawned and follower.visible,"supplied model loads and spawns on clear supported ground"):
		check(follower.animation.has_animation("adela_idle") and follower.animation.has_animation("adela_walking") and follower.animation.has_animation("adela_running"),"all three personal clips are available")
		var draws: Array[Node]=follower.model.find_children("*","MeshInstance3D",true,false)
		for draw: MeshInstance3D in draws:
			for surface in draw.mesh.get_surface_count():
				var material:=draw.get_active_material(surface) as StandardMaterial3D
				check(material!=null and material.normal_enabled and not material.uv1_triplanar,"registered original-UV PBR is loaded")
				if material!=null:
					for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
						var image:=texture.get_image() if texture!=null else null
						check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==11,"2048 atlas has complete loaded mip chain")
		if await _walk(Vector3(0,0,-5)) and await _walk(Vector3(4,0,-5)):
			await _catch_up()
			check(not wall_crossed,"trail follows the real bend instead of crossing its wall")
			check(follower.global_position.distance_to(player.global_position)<2.3,"follower catches up to conversational distance")
			_observe("after_corner")
			await _capture("adela_after_corner")
			var mid: Vector3=(follower.global_position+player.global_position)*.5
			var gate:=_box(Vector3(mid.x,.95,-5),Vector3(.12,1.9,2))
			await get_tree().physics_frame;await get_tree().physics_frame
			if await _walk(Vector3(9,0,-5)):
				for frame in 120:await get_tree().physics_frame
				check(follower.global_position.x<gate.global_position.x-.25,"closed obstacle blocks the follower without teleport or wall crossing")
				_observe("gate_closed")
				await _capture("adela_waits_at_gate")
			gate.free();await get_tree().physics_frame;await get_tree().physics_frame
			await _catch_up()
			_observe("after_step")
			check(follower.global_position.distance_to(player.global_position)<2.3,"follower resumes through cleared path and over the150mm step")
			check(follower.global_position.x>6.15 and follower.global_position.y>-.03 and follower.global_position.y<.2,"follower has crossed the entire step and retained floor support")
			player.call_locked=true
			for frame in 3:await get_tree().physics_frame
			var held:=follower.global_transform
			for frame in 12:await get_tree().physics_frame
			check(follower.global_transform.is_equal_approx(held),"protected input holds follower position")
			player.call_locked=false
			var paused_pose:=follower.global_transform
			var paused_animation: float=follower.animation.current_animation_position
			get_tree().paused=true
			for frame in 8:await get_tree().process_frame
			check(follower.global_transform.is_equal_approx(paused_pose) and is_equal_approx(follower.animation.current_animation_position,paused_animation),"pause freezes locomotion and personal animation")
			get_tree().paused=false
			await _capture("adela_follow_resumed")
	check(RealityState.data==before,"preview creates no persistent campaign facts")
	var output:=OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("adela_follow.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"observations":observations,"scope":"Isolated supplied model, real player movement, bend/wall/obstacle/step, input protection and pause. Not installed-world, prologue timing, save or artistic acceptance."},"\t"))
	print("ADELA FOLLOW DIAGNOSTIC: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _observe(label: String) -> void:
	observations.append({"phase":label,"player":str(player.global_position),"follower":str(follower.global_position),"target":str(follower.trail[0]) if not follower.trail.is_empty() else "none","queued_metres":follower.queued_metres,"trail_lost":follower.trail_lost,"on_floor":follower.is_on_floor()})

func _walk(to: Vector3) -> bool:
	for frame in 480:
		var toward:=to-player.global_position;toward.y=0.
		if toward.length()<.1:Input.action_release("move_forward");return true
		var yaw:=atan2(-toward.x,-toward.z)
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(-wrapf(yaw-player.rotation.y,-PI,PI)/PlayerController.MOUSE_SENS,0.)
		player._unhandled_input(motion);Input.action_press("move_forward")
		await get_tree().physics_frame
		wall_crossed=wall_crossed or (follower.global_position.x>.7 and follower.global_position.x<1.3 and follower.global_position.z>-4 and follower.global_position.z< -1)
	Input.action_release("move_forward");return check(false,"real player reaches "+str(to))

func _catch_up() -> void:
	for frame in 360:
		if follower.global_position.distance_to(player.global_position)<2.1:return
		await get_tree().physics_frame

func _capture(label: String) -> void:
	var output:=OS.get_environment("SHOT_DIR")
	if output.is_empty():return
	DirAccess.make_dir_recursive_absolute(output)
	var original:=player.camera.global_transform
	player.camera.look_at(follower.global_position+Vector3.UP*1.0)
	for frame in 3:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
	player.camera.global_transform=original
