extends Node3D
## Historical presentation only. TemporalLoop/clock own entry and lifetime;
## no interaction, conversation, clue, death cause or persistent state writer.
const Cast := preload("res://scripts/characters/cast_model_presentation.gd")
const DATA := "res://data/characters/adela_discovery_pose.json"
var world: Node3D
var loop: Node
var body: Node3D
var solid: StaticBody3D
var last_refusal := ""
var _identity := ""
var _campaign: Dictionary = {}
var _recipe: Dictionary = {}
var _retry := 0.0

func configure(runtime: Node3D, temporal: Node) -> void:
	world=runtime;loop=temporal;name="AdelaDiscoveryTableau"

static func eligible(away: bool, anchor: String, info: Dictionary, minute: float, left: float) -> bool:
	return away and anchor=="stairs" and left>0.0 and info.get("year")==1929 and info.get("month")==7 and info.get("day_of_month")==20 and minute>=182.0 and minute<220.0

func _ready() -> void:
	add_to_group("adela_discovery_tableau")
	set_process(false);set_physics_process(false)
	if is_instance_valid(loop):
		if loop.has_signal("changed"):loop.changed.connect(refresh)
		if loop.has_signal("stage_reset"):loop.stage_reset.connect(refresh)
	refresh()

func _interested() -> bool:
	return is_instance_valid(world) and is_instance_valid(loop) and loop.in_visit() and loop.visit_anchor()=="stairs"

func _wanted() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(loop) or world.startup_ms<=0.0:return false
	var clock: CampaignClock=world.campaign_clock
	return clock!=null and eligible(loop.in_visit(),loop.visit_anchor(),clock.day_info(),clock.minute_of_day(),loop.loop_minutes_left())

func _visit_key() -> String:
	var ledger: Dictionary=loop.ledger()
	var visit: Dictionary=ledger.get("visit",{})
	var record: Dictionary=ledger.get("anchors",{}).get("stairs",{})
	return "%s|%s|%s|%s"%[visit.get("left_at"),visit.get("loop_started"),record.get("paid"),record.get("loops")]

func _living() -> bool:
	var dated: Node=world.get("adela_encounters")
	if is_instance_valid(dated):
		var actor: Node3D=dated.get("actor")
		if is_instance_valid(actor) and actor.is_visible_in_tree():return true
	var bar: Node=world.get("bar_region")
	if is_instance_valid(bar) and is_instance_valid(bar.get("actors")):
		var cast_owner: Node=bar.actors.get_node_or_null("HarukiyaCast")
		if cast_owner!=null:
			var actor: Node3D=cast_owner.performers.get("adela_voss")
			if is_instance_valid(actor) and actor.is_visible_in_tree():return true
	for actor: Node in get_tree().get_nodes_in_group("animated_residents"):
		if actor.get("resident_id")=="adela_voss" and actor is Node3D and actor.is_visible_in_tree():return true
	return false

func _physics_process(delta: float) -> void:
	if not _interested():refresh();return
	if not _wanted():_retire();return
	if not is_same(_campaign,RealityState.data) or _identity!=_visit_key():_retire()
	_retry-=delta
	if _retry>0.0:return
	_retry=.25
	if _living():_retire();last_refusal="living Adela still visible";return
	if not is_instance_valid(body):
		_campaign=RealityState.data;_identity=_visit_key();_mount()

## Event-only: no direct-space-state queries outside a physics tick.
## Existing parent _sync_visit also calls this after a same-visit load.
func refresh() -> void:
	if not _interested():_retire();set_physics_process(false);return
	if not _wanted() or _identity!=_visit_key() or not is_same(_campaign,RealityState.data):_retire()
	if _living():_retire();last_refusal="living Adela still visible"
	_retry=0.0;set_physics_process(true)

func _v(row: Array) -> Vector3:return Vector3(float(row[0]),float(row[1]),float(row[2]))

func _mount() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary or parsed.get("schema_version")!=1 or parsed.get("person")!="adela_voss":last_refusal="pose resource invalid";return
	_recipe=parsed
	if _recipe.bones.size()!=76 or _recipe.parts!=["b_top","b_feet","k_head"]:last_refusal="pose/wardrobe contract changed";return
	var anchor: Vector3=_v(_recipe.head_anchor)
	var frame: Transform3D=world.adapter.root.global_transform
	var at: Vector3=frame*anchor
	var low: Vector3=_v(_recipe.cpu_bounds[0]);var high: Vector3=_v(_recipe.cpu_bounds[1])
	var floor_y := 0.0
	for x: float in [low.x,(low.x+high.x)*.5,high.x]:
		for z: float in [low.z,(low.z+high.z)*.5,high.z]:
			var sample: Vector3=at+frame.basis*Vector3(x,0,z)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.8,sample-Vector3.UP*.8,1))
			if hit.is_empty() or (hit.normal as Vector3).y<.98:last_refusal="actual tableau floor missing or steep";return
			var y: float=(hit.position as Vector3).y
			if x==low.x and z==low.z:floor_y=y
			if absf(y-floor_y)>.005:last_refusal="tableau floor is not planar within5mm";return
	at.y=floor_y
	var shape:=BoxShape3D.new();shape.size=high-low
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform=Transform3D(frame.basis,at+frame.basis*((low+high)*.5))
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():last_refusal="actual tableau footprint blocked";return
	var candidate:=Cast.new()
	candidate.configure(str(_recipe.person),str(_recipe.model),_recipe.parts,"at_ease")
	candidate.name="AdelaHistoricalBody"
	candidate.set_active(false);add_child(candidate)
	if not candidate.ready_ok:candidate.queue_free();last_refusal="actual cast/wardrobe refused";return
	var skeleton: Skeleton3D=candidate.skeleton
	for row: Dictionary in _recipe.bones:
		var id: int=skeleton.find_bone(str(row.name))
		if id<0 or skeleton.get_bone_global_rest(id).origin.distance_to(_v(row.rest_global))>.001:
			candidate.queue_free();last_refusal="imported skeleton shape differs from authored pose";return
	for name: String in _recipe.mesh_counts:
		var found: Array=candidate.model.find_children(name.validate_node_name(),"MeshInstance3D",true,false)
		if found.size()!=1:candidate.queue_free();last_refusal="imported mesh missing: "+name;return
		var draw: MeshInstance3D=found[0]
		if draw.mesh==null:candidate.queue_free();last_refusal="imported mesh empty: "+name;return
		var count := 0
		for surface in draw.mesh.get_surface_count():count+=draw.mesh.surface_get_array_len(surface)
		if count!=int(_recipe.mesh_counts[name]):candidate.queue_free();last_refusal="imported mesh shape changed: "+name;return
	for row: Dictionary in _recipe.bones:
		var id: int=skeleton.find_bone(str(row.name));var q: Array=row.rotation
		skeleton.set_bone_pose_position(id,_v(row.position));skeleton.set_bone_pose_rotation(id,Quaternion(q[0],q[1],q[2],q[3]));skeleton.set_bone_pose_scale(id,Vector3.ONE)
	candidate.face.express("neutral",0.0);candidate.face.look(Vector2.ZERO)
	candidate.face.blink();candidate.face.step(float(candidate.face._data.blink.close_seconds));candidate.face.set_process(false)
	# No shared material mutation: corpse-local copies freeze shader flutter.
	for draw: MeshInstance3D in candidate.model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count() if draw.mesh!=null else 0:
			var material: Material=draw.material_override if draw.material_override!=null else draw.get_surface_override_material(surface)
			if material==null:material=draw.mesh.surface_get_material(surface)
			if not material is ShaderMaterial:continue
			var freeze: Dictionary={}
			for uniform: Dictionary in (material as ShaderMaterial).shader.get_shader_uniform_list():
				if str(uniform.name) in ["sway_amplitude","breeze"]:freeze[str(uniform.name)]=0.0
				elif str(uniform.name)=="sway":freeze.sway=Vector3.ZERO
			if freeze.is_empty():continue
			var copy: ShaderMaterial=material.duplicate() as ShaderMaterial
			for key: String in freeze:copy.set_shader_parameter(key,freeze[key])
			if draw.material_override!=null:draw.material_override=copy
			else:draw.set_surface_override_material(surface,copy)
	global_transform=Transform3D(frame.basis,at)
	candidate.transform=Transform3D(Basis(Vector3.BACK,deg_to_rad(float(_recipe.basis_rotation_z_degrees))),_v(_recipe.local_offset))
	skeleton.force_update_all_bone_transforms();candidate.visible=true
	body=candidate
	solid=StaticBody3D.new();solid.name="TableauPhysicalEnvelope";solid.collision_layer=1;solid.collision_mask=0
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=(low+high)*.5;solid.add_child(collision);add_child(solid)
	last_refusal=""

func head_world() -> Variant:
	return body.skeleton.global_transform*body.skeleton.get_bone_global_pose(body.skeleton.find_bone("Head")).origin if is_instance_valid(body) else null

func right_hand_world() -> Variant:
	return body.skeleton.global_transform*body.skeleton.get_bone_global_pose(body.skeleton.find_bone("RightHand")).origin if is_instance_valid(body) else null

func _retire() -> void:
	if is_instance_valid(body):body.hide();body.queue_free()
	if is_instance_valid(solid):solid.collision_layer=0;solid.queue_free()
	body=null;solid=null;_identity=""

func _exit_tree() -> void:
	_retire()

## Fresh read-only inventory for private native skin/POV proof. No ownership transfer.
func skin_nodes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if not is_instance_valid(body):return result
	for draw: MeshInstance3D in body.model.find_children("*","MeshInstance3D",true,false):
		if draw.is_visible_in_tree() and draw.skin!=null:result.append(draw)
	return result
