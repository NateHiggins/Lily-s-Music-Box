extends Node3D
## Separate round native stock after extraction. The folded representation has
## no solver. Production uses visual following; numerical modes are diagnostics.
const EXTRACTION_M:=.20
var actor: Node3D
var joint: Node3D
var model: Node3D
var rig:=preload("res://scripts/props/native_hose_rig.gd").new()
var contact:=preload("res://scripts/props/native_hose_world_contact.gd").new()
var tether:=preload("res://scripts/props/native_hose_tether.gd").new()
var deployed:=false
var extraction:=0.
var error:=""
var setup_ms:=0.
var _receiver:=Transform3D.IDENTITY
var _extracted_receiver:=Transform3D.IDENTITY
var _placement:=PackedVector3Array()
var _stored: Array[Node3D]=[]
var _stock_layers: Dictionary={}
var _stock_processing: Dictionary={}
var _receiver_from_tip:=Transform3D.IDENTITY
var _bend_radii:=PackedFloat64Array()
var _physical_bend_spans:=PackedFloat64Array()
var last_nozzle_query: Dictionary={}
var last_fitting_blocker:=""
var cast_observer: Callable
var _fitting_candidates: Array[Dictionary]=[]
var _nozzle_bounds: Dictionary={}
var _nozzle_box:=BoxShape3D.new()
var _nozzle_radius:=0.
var _receiving_stock: Array[Dictionary]=[]
var guide_enabled:=false
var ground_y_local:=0.
var guide_axis_local:=Vector3.LEFT
var guide_side_local:=Vector3.BACK
var _guide_floor:=0.
var profile_motion:=false
var last_motion_profile: Dictionary={}
var motion_profile_records: Array[Dictionary]=[]
var _last_fitting_usec:=0
var _last_prepare_usec:=0
var _last_broad_queries:=0
var _last_shell_queries:=0
var local_follow_enabled:=false
var local_contacts_enabled:=false
var fps_aim_enabled:=false
var fps_once_per_frame:=false
var last_hand_debug: Dictionary={}
var _hold_frame: int=-1
var _last_hold_usec: int=0
var _carrier: WeakRef
var _inspection_holder: WeakRef
var _auxiliary_contacts: Array[Dictionary]=[]
var _cover: PhysicsBody3D
var _cover_stock_added:=false
var _cover_holder_added:=false
var _contact_exclusions: Array[RID]=[]
var _local_follow:=preload("res://scripts/props/round_local_endpoint.gd").new()
var visual_follow_enabled:=false
var visual_route: RefCounted=preload("res://scripts/props/hose_visual_route.gd").new()
var water:=preload("res://scripts/props/hose_water_charge.gd").new()
var _spray: GPUParticles3D
var _charge_dirty:=false
# Cosmetic water only: no hydraulic, inventory, weather or save authority.
const WET_STEP:=.05
const WET_LIMIT:=16
const WET_RADIUS:=.08
const WET_SECONDS:=8.
var _wet_timer: Timer
var _wet_drops: Array[Dictionary]=[]
var _wet_marks: Array[Dictionary]=[]
var _wet_mesh: ArrayMesh
var _wet_finish: StandardMaterial3D
var last_spray_impact: Dictionary={}
# Swept presentation is selected on first positive flow.
const SPLASH_LIMIT := 12
const SPLASH_SECONDS := .15
var _swept_spray := true
var _swept_jet: MultiMeshInstance3D
var _swept_splash_draw: MultiMeshInstance3D
var _swept_splash: Array[Dictionary] = []
# Dense flight uses a packed active prefix, allocated on first use.
var _dense_positions := PackedVector3Array()
var _dense_velocities := PackedVector3Array()
var _dense_remaining := PackedFloat64Array()
var _dense_launch_owners: Array[RID] = []
var _dense_count := 0
var _dense_credit := 0.0
var _dense_sequence := 0
var _dense_query: PhysicsRayQueryParameters3D
var _dense_hit_this_tick := false
var swept_stats := {"ticks":0,"usec":0,"max_usec":0,"visual_usec":0,"max_visual_usec":0,
	"visual_rays":0,"wet_rays":0,"splash_rays":0,"rim_rays":0,"impacts":0,"bursts":0,
	"births":0,"dropped_births":0,"inspection_origin_retries":0}
var last_swept_impact: Dictionary = {}
var inspection_origin_witness: Dictionary = {}
var release_support:=preload("res://scripts/props/hose_release_support.gd").new()

func deployment_snapshot() -> Dictionary:
	var pose: Transform3D=joint.receiver
	var axes: Array=[]
	for axis: Vector3 in [pose.basis.x,pose.basis.y,pose.basis.z]:axes.append([axis.x,axis.y,axis.z])
	return {"deployed":deployed,"extraction":extraction,"wheel":actor._wheel_angle,
		"receiver":{"position":[pose.origin.x,pose.origin.y,pose.origin.z],"basis":axes},"water":water.snapshot()}

func saved_receiver(value: Dictionary) -> Transform3D:
	var row: Dictionary=value.receiver
	var axes: Array[Vector3]=[]
	for axis: Array in row.basis:axes.append(Vector3(axis[0],axis[1],axis[2]))
	return Transform3D(Basis(axes[0],axes[1],axes[2]),Vector3(row.position[0],row.position[1],row.position[2]))

func valid_deployment(value: Variant) -> bool:
	if not visual_follow_enabled or value is not Dictionary or value.size()!=5:return false
	for key: String in ["deployed","extraction","wheel","receiver","water"]:
		if not value.has(key):return false
	if value.deployed is not bool or not water.valid(value.water):return false
	for key: String in ["extraction","wheel"]:
		if typeof(value[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])):return false
	if value.extraction<0. or value.extraction>EXTRACTION_M or value.wheel<0. or value.wheel>(TAU*2. if value.deployed else .025):return false
	var row: Variant=value.receiver
	if row is not Dictionary or row.size()!=2 or row.get("position") is not Array or row.position.size()!=3 or row.get("basis") is not Array or row.basis.size()!=3:return false
	var numbers: Array=row.position.duplicate()
	for axis: Variant in row.basis:
		if axis is not Array or axis.size()!=3:return false
		numbers.append_array(axis)
	for number: Variant in numbers:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):return false
	var pose: Transform3D=saved_receiver(value)
	if absf(pose.basis.determinant()-1.)>.00001 or not pose.basis.transposed().is_equal_approx(pose.basis.inverse()):return false
	if value.deployed:
		return absf(float(value.extraction)-EXTRACTION_M)<.000001 and (model.transform.affine_inverse()*pose.origin).distance_to(rig.strand.anchor)<=rig.strand.total_length-.15+.00001
	var expected:=_receiver;expected.origin+=Vector3.BACK*float(value.extraction)
	expected.basis=Basis(_receiver.basis.get_rotation_quaternion().slerp(_extracted_receiver.basis.get_rotation_quaternion(),float(value.extraction)/EXTRACTION_M))
	return pose.is_equal_approx(expected) and float(value.water.fill)==0. and float(value.water.pressure)==0.

func _show_deployment(enabled: bool) -> void:
	deployed=enabled;model.visible=enabled
	if enabled and visual_follow_enabled:
		actor._door_angle=maxf(actor._door_angle,actor._minimum("door"));actor._apply_hand_pose()
	for node: Node3D in _stored:
		if not _stock_processing.has(node):_stock_processing[node]={"visible":node.visible,"process":node.is_processing()}
		node.visible=false if enabled else _stock_processing[node].visible
		node.set_process(false if enabled else _stock_processing[node].process)
		for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
			if not _stock_layers.has(body):_stock_layers[body]=body.collision_layer
			body.collision_layer=0 if enabled else _stock_layers[body]

func restore_deployment(value: Dictionary) -> void:
	_wet_clear()
	# Cabinet validates the complete payload before restoring any owner.
	water.restore(value.water);_charge_dirty=false;extraction=float(value.extraction);actor._wheel_angle=float(value.wheel)
	_show_deployment(value.deployed)
	if deployed:_visual_receiver(actor.global_transform*saved_receiver(value))
	else:joint.receiver=saved_receiver(value);joint.sync()
	if _spray!=null:_spray.emitting=false
	set_physics_process(false)
	water_controls_changed()

func restore_stored() -> void:
	_wet_clear()
	water.restore({"fill":0.,"pressure":0.});_charge_dirty=false;extraction=0.;actor._wheel_angle=0.
	_show_deployment(false);joint.receiver=_receiver;joint.sync()
	if _spray!=null:_spray.emitting=false
	set_physics_process(false)

func enable_visual_follow() -> void:
	# Owner-authorized approximation supersedes physical full-payout solves.
	# Maintenance fittings retain their existing separate mechanical owners.
	tether.cancel_motion();set_process(false);visual_follow_enabled=true
	fps_aim_enabled=true;fps_once_per_frame=true;error=""
	actor._live_hose=self
	if not actor.manipulation_changed.is_connected(water_controls_changed):actor.manipulation_changed.connect(water_controls_changed)
	if deployed:rig.apply_points(rig.strand.points,water.pressure)
	water_controls_changed()

func water_controls_changed() -> void:
	if not visual_follow_enabled or not deployed:return
	var connected: bool=actor.gasket_seated and actor.coupling_made_up and actor.nozzle_coupled
	var needs_fill: bool=connected and actor.hose_supply_opening()>0.
	var needs_drain: bool=water.fill>0. and (not connected or actor._lever_angle<-.0001)
	if needs_fill or needs_drain or water.spray>0.:set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not visual_follow_enabled or not deployed:set_physics_process(false);return
	var connected: bool=actor.gasket_seated and actor.coupling_made_up and actor.nozzle_coupled
	var supply: float=actor.hose_supply_opening()
	var lever: float=0. if actor.nozzle_shut else clampf(-actor._lever_angle/.95,0.,1.)
	var changed: bool=water.advance(delta,supply,lever,connected)
	_charge_dirty=_charge_dirty or changed
	if changed:rig.apply_points(rig.strand.points,water.pressure)
	if water.spray>0.001 and _spray==null:_make_spray()
	if _spray!=null:
		var flowing: bool = water.spray > .001
		if flowing and _wet_timer == null:
			_wet_prepare()
		if flowing and _swept_spray:
			_prepare_swept_spray()
		_spray.emitting = flowing and not _swept_spray
		if _spray.emitting:
			_spray.visible = true
		_spray.amount_ratio = clampf(water.spray, 0., 1.)
		if flowing and _wet_timer != null and _wet_timer.is_stopped():
			_wet_timer.start()
	# Stable pressure and the independent spray timer need no cloth/fluid tick.
	# Publish the completed fill/drain through the existing household signal,
	# rather than leaving the last saved value at the valve's release instant.
	if not changed and _charge_dirty:
		_charge_dirty=false;actor.manipulation_changed.emit()
	set_physics_process(changed)

func _make_spray() -> void:
	if _spray!=null:return
	var started:=Time.get_ticks_usec()
	_spray=GPUParticles3D.new();_spray.name="NozzleWater";_spray.emitting=false;_spray.visible=false
	_spray.local_coords=false
	# Longer overlapping streaks read as a jet at normal play distance.
	# Fewer droplets also reduce submitted water geometry; water is not an
	# opaque shadow caster. The original hydraulic owner still gates flow.
	_spray.amount=128;_spray.lifetime=.65;_spray.fixed_fps=30
	_spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	_spray.visibility_aabb=AABB(Vector3(-12,-12,-12),Vector3(24,24,24))
	var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=.75
	process.initial_velocity_min=11.;process.initial_velocity_max=13.;process.gravity=Vector3(0,-9.8,0)
	process.particle_flag_align_y=true
	process.scale_min=.8;process.scale_max=1.2;_spray.process_material=process
	var drop:=SphereMesh.new();drop.radius=.003;drop.height=.12;drop.radial_segments=8;drop.rings=4
	var geometry_done:=Time.get_ticks_usec()
	var finish: StandardMaterial3D=MatLib.get_mat("water_clear").duplicate()
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3(.05,.10,1.)
	finish.normal_enabled=true;finish.normal_scale=.1
	finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	# Optical scattering fill keeps aerated water readable inside the barrel's
	# hard shadow. This material does not provide scene/GI illumination.
	finish.emission_enabled=true;finish.emission=Color(.85,.92,1.);finish.emission_energy_multiplier=.35
	finish.albedo_color=Color(.72,.86,.94,.5);finish.roughness=.12
	var finish_done:=Time.get_ticks_usec()
	drop.material=finish;_spray.draw_pass_1=drop
	var assigned:=Time.get_ticks_usec()
	# Keep the physical body's shape-only child contract intact. The original
	# play-pipe presentation already follows its authoritative rigid pose.
	actor._play_pipe.add_child(_spray);_spray.position=Vector3(0,.171,0)

	if OS.get_environment("ORISON_PROFILE_HOSE_SPRAY")=="1":print("HOSE_SPRAY_CREATE ",JSON.stringify({"cabinet":str(actor.name),"geometry_ms":(geometry_done-started)/1000.,"finish_ms":(finish_done-geometry_done)/1000.,"assignment_ms":(assigned-finish_done)/1000.,"attach_ms":(Time.get_ticks_usec()-assigned)/1000.,"total_ms":(Time.get_ticks_usec()-started)/1000.}))


# A small CPU droplet sample follows elapsed flight from the actual muzzle.
# It is not a claim that the GPU renderer reports particle collisions.
func _wet_prepare() -> void:
	if _wet_timer!=null:return
	_wet_finish=MatLib.get_mat("water_clear").duplicate() as StandardMaterial3D
	_wet_finish.uv1_triplanar=false # Disk UVs below are metres; retain catalogue scale/maps.
	_wet_finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_wet_finish.albedo_color=Color(.24,.29,.32,.32)
	_wet_finish.roughness=.08;_wet_finish.emission_enabled=false
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	var uv:=PackedVector2Array();var tangents:=PackedFloat32Array()
	for edge in 16:
		for angle: float in [0.,TAU*float(edge)/16.,TAU*float(edge+1)/16.]:
			var point:=Vector3.ZERO if vertices.size()%3==0 else Vector3(cos(angle),0,sin(angle))*WET_RADIUS
			vertices.append(point);normals.append(Vector3.UP)
			uv.append(Vector2(point.x,point.z)+Vector2.ONE*WET_RADIUS)
			tangents.append_array(PackedFloat32Array([1.,0.,0.,-1.]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TANGENT]=tangents
	_wet_mesh=ArrayMesh.new();_wet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_wet_mesh.surface_set_material(0,_wet_finish)
	for index in WET_LIMIT:
		var draw:=MeshInstance3D.new();draw.name="HoseWetFilm%d"%index
		draw.mesh=_wet_mesh;draw.visible=false
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		add_child(draw);draw.set_as_top_level(true)
		_wet_marks.append({"draw":draw,"receiver":null,"rid":RID(),"pose":Transform3D.IDENTITY,"left":0.})
	_wet_timer=Timer.new();_wet_timer.wait_time=WET_STEP
	_wet_timer.process_callback=Timer.TIMER_PROCESS_PHYSICS
	add_child(_wet_timer);_wet_timer.timeout.connect(_wet_tick)

func _wet_ray(ray_from: Vector3, ray_to: Vector3, counter: String = "rim_rays",
		inspection_owner: RID = RID(), flight: Dictionary = {}) -> Dictionary:
	if _swept_spray:
		swept_stats[counter] += 1
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.hit_back_faces = true
	var space := get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if _inside_launch_owner(hit, ray_from, inspection_owner) and flight.get("launch_owner", RID()) == inspection_owner:
		return _retry_launch_origin(space, query, inspection_owner)
	if flight.has("launch_owner"):
		flight.erase("launch_owner")
	return hit

func _inside_launch_owner(hit: Dictionary, origin: Vector3, owner: RID) -> bool:
	return owner.is_valid() and not hit.is_empty() and hit.rid == owner and hit.normal == Vector3.ZERO and hit.position == origin

func _retry_launch_origin(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, owner: RID) -> Dictionary:
	# This is the capsule the borrowed nozzle launched inside. Incoming hits
	# and every other solid continue to use the original first query.
	query.exclude = [owner]
	var hit: Dictionary = space.intersect_ray(query)
	query.exclude = []
	if _swept_spray:
		swept_stats.inspection_origin_retries += 1
		if inspection_origin_witness.is_empty():
			inspection_origin_witness = {
				"inspector_rid": str(owner), "origin": var_to_str(query.from),
				"end": var_to_str(query.to), "retry_rid": str(hit.get("rid", RID())),
				"retry_clear": hit.is_empty(),
			}
	return hit

func _wet_tick() -> void:
	var started: int = Time.get_ticks_usec() if _swept_spray else 0
	var exclusions: Array[RID] = inspection_control_exclusions()
	var inspection_owner: RID = exclusions[0] if not exclusions.is_empty() else RID()
	if _swept_spray:
		_swept_update_splash()
	for row: Dictionary in _wet_marks:
		var draw: MeshInstance3D=row.draw
		if float(row.left)<=0.:continue
		var receiver: StaticBody3D=row.receiver.get_ref() if row.receiver!=null else null
		row.left=maxf(0.,float(row.left)-WET_STEP)
		if not is_instance_valid(receiver) or not receiver.is_inside_tree() or receiver.get_rid()!=row.rid:row.left=0.
		if float(row.left)<=0.:draw.visible=false;row.receiver=null;continue
		draw.global_transform=receiver.global_transform*row.pose
		draw.transparency=1.-clampf(float(row.left)/2.,0.,1.)
	var flowing: bool=visual_follow_enabled and deployed and is_instance_valid(_spray) and water.spray>.001 		and actor.gasket_seated and actor.coupling_made_up and actor.nozzle_coupled and not actor.nozzle_shut
	if flowing and _wet_drops.size()<WET_LIMIT:
		var process: ParticleProcessMaterial=_spray.process_material
		var velocity: Vector3=(_spray.global_basis*process.direction).normalized()*(process.initial_velocity_min+process.initial_velocity_max)*.5
		_wet_drops.append({"position":_spray.global_position,"velocity":velocity,"gravity":process.gravity,"left":_spray.lifetime,"launch_owner":inspection_owner})
	for index in range(_wet_drops.size()-1,-1,-1):
		var drop: Dictionary=_wet_drops[index]
		var dt: float=minf(WET_STEP,float(drop.left))
		var position: Vector3=drop.position
		var velocity: Vector3=drop.velocity
		var gravity: Vector3=drop.gravity
		var next: Vector3=position+velocity*dt+gravity*(dt*dt*.5)
		var hit: Dictionary=_wet_ray(position, next, "wet_rays", inspection_owner, drop)
		if not hit.is_empty():
			var fraction: float=clampf((hit.position-position).dot(next-position)/maxf(position.distance_squared_to(next),.000000000001),0.,1.)
			var impact_velocity: Vector3 = velocity + gravity * (dt * fraction)
			_wet_deposit(hit,impact_velocity)
			_wet_drops.remove_at(index) # First solid consumes the sample, even when rejected.
			continue
		drop.position=next;drop.velocity=velocity+gravity*dt;drop.left=float(drop.left)-dt
		if float(drop.left)<=.000001:_wet_drops.remove_at(index)
	if _swept_spray:
		var visual_start: int = Time.get_ticks_usec()
		_dense_update(flowing, inspection_owner)
		var visual_elapsed: int = Time.get_ticks_usec() - visual_start
		swept_stats.visual_usec += visual_elapsed
		swept_stats.max_visual_usec = maxi(swept_stats.max_visual_usec, visual_elapsed)
		var elapsed: int = Time.get_ticks_usec() - started
		swept_stats.ticks += 1
		swept_stats.usec += elapsed
		swept_stats.max_usec = maxi(swept_stats.max_usec, elapsed)
	var preview_pending: bool = _swept_spray and (_dense_count > 0 or _swept_jet.multimesh.visible_instance_count > 0 or not _swept_splash.is_empty() or _swept_splash_draw.multimesh.visible_instance_count > 0)
	if not flowing and _wet_drops.is_empty() and not preview_pending:
		var fading:=false
		for row: Dictionary in _wet_marks:
			if float(row.left)>0.:fading=true;break
		if not fading:_wet_timer.stop()

func _wet_deposit(hit: Dictionary,velocity: Vector3) -> void:
	var receiver: StaticBody3D=hit.get("collider") as StaticBody3D
	var normal: Vector3=hit.get("normal",Vector3.ZERO)
	var position: Vector3=hit.get("position",Vector3.ZERO)
	last_spray_impact={"position":position,"normal":normal,"velocity":velocity,"rid":hit.get("rid",RID()),"shape":hit.get("shape",-1),"accepted":false}
	if not is_instance_valid(receiver) or not position.is_finite() or not normal.is_finite() or normal.length_squared()<.99 or velocity.length_squared()<.000001:return
	normal=normal.normalized()
	# Only descending floor tops and front-facing vertical solids. Never undersides.
	var floor_top: bool=normal.y>=.99 and velocity.y<=-.01
	var wall: bool=absf(normal.y)<=.1 and normal.dot(velocity.normalized())<-.05
	if not floor_top and not wall:return
	if normal.dot(velocity)>=0.:return
	var basis:=Basis(Quaternion(Vector3.UP,normal))
	# A whole small film must fit on this exact first-hit shape/plane. Do not
	# draw through ledges, seams, doorways, or an adjacent floor/wall.
	for edge in 16:
		var angle: float=TAU*float(edge)/16.
		var rim: Vector3=position+(basis.x*cos(angle)+basis.z*sin(angle))*WET_RADIUS
		var support: Dictionary=_wet_ray(rim+normal*.01,rim-normal*.01)
		if support.is_empty() or support.get("rid")!=hit.get("rid") or support.get("shape")!=hit.get("shape"):return
		var support_normal: Vector3=support.get("normal",Vector3.ZERO)
		var support_position: Vector3=support.get("position",Vector3.INF)
		if support_normal.dot(normal)<.99 or absf((support_position-position).dot(normal))>.001:return
	var selected: Dictionary={}
	for row: Dictionary in _wet_marks:
		if row.rid==receiver.get_rid() and float(row.left)>0.:
			var draw: MeshInstance3D=row.draw
			if draw.global_position.distance_to(position)<WET_RADIUS*.5 and draw.global_basis.y.dot(normal)>.99:
				row.left=WET_SECONDS;last_spray_impact.accepted=true;return
		if selected.is_empty() or float(row.left)<float(selected.left):selected=row
	if selected.is_empty():return
	var draw: MeshInstance3D=selected.draw
	var pose:=Transform3D(basis,position+normal*.0006)
	selected.receiver=weakref(receiver);selected.rid=receiver.get_rid()
	selected.pose=receiver.global_transform.affine_inverse()*pose;selected.left=WET_SECONDS
	draw.global_transform=pose;draw.transparency=0.;draw.visible=true
	last_spray_impact.accepted=true

func _wet_clear() -> void:
	_swept_clear()
	if _wet_timer!=null:_wet_timer.stop()
	_wet_drops.clear();last_spray_impact.clear()
	for row: Dictionary in _wet_marks:
		row.draw.visible=false;row.receiver=null;row.left=0.

func _prepare_swept_spray() -> void:
	if _swept_jet != null:
		return
	_swept_jet = _swept_pool("SweptJet", _spray.amount)
	_swept_splash_draw = _swept_pool("SweptSplash", SPLASH_LIMIT)
	_dense_positions.resize(_spray.amount)
	_dense_velocities.resize(_spray.amount)
	_dense_remaining.resize(_spray.amount)
	_dense_launch_owners.resize(_spray.amount)
	_dense_query = PhysicsRayQueryParameters3D.new()
	_dense_query.collision_mask = 1
	_dense_query.collide_with_areas = false
	_dense_query.collide_with_bodies = true
	_dense_query.hit_from_inside = true
	_dense_query.hit_back_faces = true

# The fixed-nozzle comparison can still select the original presentation.
func set_swept_spray_enabled(enabled: bool) -> void:
	if enabled == _swept_spray:
		return
	_swept_spray = enabled
	if not is_instance_valid(_spray):
		return
	if enabled:
		if water.spray > .001 or (_wet_timer != null and not _wet_timer.is_stopped()):
			_prepare_swept_spray()
		_spray.emitting = false
		_spray.visible = false
	else:
		_swept_clear()
		if water.spray > .001:
			_spray.visible = true
			_spray.restart()

func _dense_update(flowing: bool, inspection_owner: RID) -> void:
	var process: ParticleProcessMaterial = _spray.process_material
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var counts := Vector2i.ZERO # x is active packets, y is visible instances.
	_dense_hit_this_tick = false
	# Compact in place before birthing new packets. Existing flights remain world-space.
	for index in _dense_count:
		counts = _dense_advance(index, counts, WET_STEP, process.gravity, space, inspection_owner)
	if flowing:
		# The source emitter's count, lifetime and live ratio determine density.
		var rate: float = float(_spray.amount) / _spray.lifetime * clampf(water.spray, 0., 1.)
		var credit_before: float = _dense_credit
		var budget: float = credit_before + rate * WET_STEP
		var births: int = floori(budget)
		_dense_credit = budget - float(births)
		var muzzle: Transform3D = _spray.global_transform
		var axis: Vector3 = (muzzle.basis * process.direction).normalized()
		var up: Vector3 = Vector3.UP if absf(axis.y) < .99 else Vector3.RIGHT
		var across: Vector3 = axis.cross(up).normalized()
		var tangent: Vector3 = across.cross(axis)
		for birth in births:
			if counts.x >= _dense_positions.size():
				swept_stats.dropped_births += births - birth
				break
			# Sample and hold the actual muzzle pose for this tick. Stagger ages
			# inside the interval without guessing intermediate nozzle transforms.
			var birth_time: float = (float(birth + 1) - credit_before) / rate
			var age: float = clampf(WET_STEP - birth_time, 0., WET_STEP)
			var phase: float = float(_dense_sequence)
			_dense_sequence = (_dense_sequence + 1) % 1024
			var angle: float = deg_to_rad(process.spread) * sqrt(fposmod(phase * .754877666, 1.))
			var azimuth: float = phase * 2.39996323
			var direction: Vector3 = axis * cos(angle) + (across * cos(azimuth) + tangent * sin(azimuth)) * sin(angle)
			var speed: float = lerpf(process.initial_velocity_min, process.initial_velocity_max, fposmod(phase * .569840296, 1.))
			_dense_positions[counts.x] = muzzle.origin
			_dense_velocities[counts.x] = direction * speed
			_dense_remaining[counts.x] = _spray.lifetime
			_dense_launch_owners[counts.x] = inspection_owner
			swept_stats.births += 1
			counts = _dense_advance(counts.x, counts, age, process.gravity, space, inspection_owner)
	else:
		_dense_credit = 0.0
	_dense_count = counts.x
	_swept_jet.multimesh.visible_instance_count = counts.y

func _dense_advance(index: int, counts: Vector2i, requested_step: float, gravity: Vector3,
		space: PhysicsDirectSpaceState3D, inspection_owner: RID) -> Vector2i:
	var start: Vector3 = _dense_positions[index]
	var velocity: Vector3 = _dense_velocities[index]
	var left: float = _dense_remaining[index]
	var launch_owner: RID = _dense_launch_owners[index]
	var step: float = minf(requested_step, left)
	var goal: Vector3 = start + velocity * step + gravity * (step * step * .5)
	if step > .00000001:
		_dense_query.from = start
		_dense_query.to = goal
		var hit: Dictionary = space.intersect_ray(_dense_query)
		if launch_owner == inspection_owner and _inside_launch_owner(hit, start, inspection_owner):
			hit = _retry_launch_origin(space, _dense_query, inspection_owner)
		else:
			launch_owner = RID()
		swept_stats.visual_rays += 1
		if not hit.is_empty():
			counts.y = _swept_draw_step(_swept_jet.multimesh, counts.y, start, goal, hit, 1.)
			swept_stats.impacts += 1
			if not _dense_hit_this_tick:
				_dense_hit_this_tick = true
				var fraction: float = clampf((hit.position - start).dot(goal - start) / maxf(start.distance_squared_to(goal), .000000000001), 0., 1.)
				var collider: Node = hit.get("collider") as Node
				var burst: bool = _swept_make_splash(hit, velocity + gravity * (step * fraction), gravity)
				last_swept_impact = {"instance_id":collider.get_instance_id() if collider != null else 0,
					"path":str(collider.get_path()) if collider != null else "", "rid":str(hit.rid), "shape":hit.shape,
					"position":var_to_str(hit.position), "normal":var_to_str(hit.normal),
					"step_start":var_to_str(start), "step_end":var_to_str(goal), "burst":burst}
			return counts # The first solid consumes this packet, even without a burst.
		if left <= step + .000001:
			return counts
		counts.y = _swept_draw_step(_swept_jet.multimesh, counts.y, start, goal, {}, 1.)
	_dense_positions[counts.x] = goal
	_dense_velocities[counts.x] = velocity + gravity * step
	_dense_remaining[counts.x] = left - step
	_dense_launch_owners[counts.x] = launch_owner
	counts.x += 1
	return counts

func _swept_pool(label: String, limit: int) -> MultiMeshInstance3D:
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.mesh = _spray.draw_pass_1
	pool.instance_count = limit
	pool.visible_instance_count = 0
	var draw := MultiMeshInstance3D.new()
	draw.name = label
	draw.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	draw.multimesh = pool
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(draw)
	draw.set_as_top_level(true)
	draw.global_transform = Transform3D.IDENTITY
	return draw

func _swept_draw_step(pool: MultiMesh, index: int, start: Vector3, goal: Vector3, hit: Dictionary, width: float) -> int:
	var end: Vector3 = goal if hit.is_empty() else hit.position
	var length: float = start.distance_to(end)
	if length <= .000001 or index >= pool.instance_count:
		return index
	var direction: Vector3 = (end - start) / length
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		var incidence: float = -direction.dot(normal)
		if normal.length_squared() < .99 or incidence <= .0001:
			return index
		# Keep the finite-radius streak on the incident side of the hit plane.
		var retreat: float = .003 * width / incidence
		if retreat >= length:
			return index
		end -= direction * retreat
		length -= retreat
	length = minf(length, .12 * width)
	var basis := Basis(Quaternion(Vector3.UP, direction))
	basis = Basis(basis.x * width, basis.y * (length / .12), basis.z * width)
	pool.set_instance_transform(index, Transform3D(basis, end - direction * length * .5))
	return index + 1

func _swept_make_splash(hit: Dictionary, velocity: Vector3, gravity: Vector3) -> bool:
	var normal: Vector3 = hit.normal
	if not normal.is_finite() or normal.length_squared() < .99 or normal.dot(velocity) >= 0.:
		return false
	if _swept_splash.size() + 3 > SPLASH_LIMIT:
		return false
	var across: Vector3 = Vector3.UP if absf(normal.y) < .95 else Vector3.RIGHT
	var tangent: Vector3 = normal.cross(across).normalized()
	for index in range(-1, 2):
		_swept_splash.append({"position":hit.position + normal * .004,"velocity":normal * 1.15 + tangent * float(index) * .8,"gravity":gravity,"left":SPLASH_SECONDS})
	swept_stats.bursts += 1
	return true

func _swept_update_splash() -> void:
	var count: int = 0
	for index in range(_swept_splash.size() - 1, -1, -1):
		var drop: Dictionary = _swept_splash[index]
		var dt: float = minf(WET_STEP, float(drop.left))
		var start: Vector3 = drop.position
		var next: Vector3 = start + drop.velocity * dt + drop.gravity * (dt * dt * .5)
		var hit: Dictionary = _wet_ray(start, next, "splash_rays")
		count = _swept_draw_step(_swept_splash_draw.multimesh, count, start, next, hit, .55)
		if not hit.is_empty() or float(drop.left) <= dt + .000001:
			_swept_splash.remove_at(index)
		else:
			drop.position = next
			drop.velocity += drop.gravity * dt
			drop.left -= dt
	_swept_splash_draw.multimesh.visible_instance_count = count

func _swept_clear() -> void:
	_dense_count = 0
	_dense_credit = 0.0
	_dense_sequence = 0
	_swept_splash.clear()
	last_swept_impact.clear()
	inspection_origin_witness.clear()
	if is_instance_valid(_swept_jet):
		_swept_jet.multimesh.visible_instance_count = 0
		_swept_splash_draw.multimesh.visible_instance_count = 0

func _visual_receiver(wanted: Transform3D) -> void:
	var started: int=Time.get_ticks_usec()
	var anchor: Vector3=model.to_global(rig.strand.anchor)
	wanted.origin=anchor+(wanted.origin-anchor).limit_length(rig.strand.total_length-.15)
	var local_tip: Vector3=model.to_local(wanted.origin)
	var back: Vector3=(model.global_basis.inverse()*-wanted.basis.y).normalized()
	var up: Vector3=(model.global_basis.inverse()*Vector3.UP).normalized()
	var points: PackedVector3Array=visual_route.build(local_tip,back,rig.strand.anchor,rig.rest.size(),rig.strand.total_length,up,_guide_floor)
	if points.is_empty() or not rig.apply_points(points,water.pressure):error="visual hose route unavailable";return
	rig.strand.points=points
	wanted.origin=model.to_global(points[0])
	joint.receiver=actor.global_transform.affine_inverse()*wanted
	joint.sync();error=""
	if profile_motion:
		last_motion_profile={"total_usec":Time.get_ticks_usec()-started,"mode":"visual","process_frame":Engine.get_process_frames(),"shell_queries":0,"broad_queries":0}
		motion_profile_records.append(last_motion_profile)
		if motion_profile_records.size()>512:motion_profile_records.pop_front()

func set_local_follow(enabled: bool) -> bool:
	if not contact.ready:return false
	if enabled:
		if _local_follow.rig==null and not _local_follow.configure(rig,_bend_radii):return false
		_local_follow.prime(rig.strand.points if deployed else _placement)
		tether.seed_factory=_carry_seed;tether.substep_m=.08
		tether.constrained_seed_factory=_local_follow.constrained_seed if local_contacts_enabled else Callable()
	else:
		tether.constrained_seed_factory=Callable()
		tether.seed_factory=_guide_seed if guide_enabled else Callable()
		tether.substep_m=.08 if guide_enabled else .008
	local_follow_enabled=enabled;return true

func _carry_seed(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	return _local_follow.seed(before,goal)

func configure_visual(owner_actor: Node3D,asset_path: String) -> bool:
	var started: int=Time.get_ticks_usec()
	if actor!=null or owner_actor._nozzle_joint==null:return false
	actor=owner_actor;joint=actor._nozzle_joint;_receiver=joint.receiver
	_extracted_receiver=_receiver;_extracted_receiver.origin+=Vector3.BACK*EXTRACTION_M
	if not _configure_skin(asset_path):return false
	release_support.prepare(self)
	visual_route=preload("res://scripts/props/hose_cabinet_route.gd").new()
	visual_route.model_to_actor=model.transform
	var up: Vector3=(model.global_basis.inverse()*Vector3.UP).normalized()
	# The dry transported ribbon can roll its wide axis toward the floor.
	# Allow its flattened half-width and a millimetre of clearance.
	var ribbon_clearance: float=.021*PI*.5+.001
	_guide_floor=up.dot(model.transform.affine_inverse()*Vector3(0,ground_y_local+ribbon_clearance,0))
	var tip: Vector3=model.transform.affine_inverse()*_extracted_receiver.origin
	var back: Vector3=-(model.basis.inverse()*_extracted_receiver.basis.y)
	_placement=visual_route.build(tip,back,rig.strand.anchor,rig.rest.size(),rig.strand.total_length,up,_guide_floor)
	if _placement.is_empty():return false
	enable_visual_follow()
	joint.hose_grip_provider=grip;joint.hose_seat_grip_provider=grip
	# Pay native mesh/material setup before play, with emission and visibility
	# disabled. No cloth/fluid tick or particle simulation is started here.
	_make_spray()
	setup_ms=(Time.get_ticks_usec()-started)/1000.
	return true

func _configure_skin(asset_path: String,projection: Variant=null) -> bool:
	var packed:=load(asset_path) as PackedScene
	if packed==null:return false
	model=packed.instantiate();add_child(model);model.visible=false
	var prepared: bool=rig.configure_deployment(model) if projection==null else rig.configure(model,projection)
	if not prepared or not rig.enable_material_transport():return false
	# Retain the native upstream frame at the original union port.
	model.transform=Transform3D(Basis(Vector3.BACK,PI*.5),Vector3.ZERO)
	model.position=Vector3(.170,.445,.098)-model.basis*rig.rest[-1]
	for node: Node3D in [actor._folds,actor.get_node("NativeContinuousFolds"),actor.get_node("NativeHoseRuns")]:_stored.append(node)
	var finish: StandardMaterial3D=MatLib.get_mat("linen").duplicate()
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json"))
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE/float(catalogue.materials.linen.meters_per_tile)
	finish.albedo_color=Color(.75,.71,.59);finish.normal_scale=.08;finish.roughness=.9;finish.metallic=0.
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):draw.material_override=finish
	set_process(false);set_physics_process(false)
	return true

func configure(owner_actor: Node3D,asset_path: String,projection: Dictionary,placement: Dictionary) -> bool:
	var started: int=Time.get_ticks_usec()
	if actor!=null or owner_actor._nozzle_joint==null:return false
	actor=owner_actor;joint=actor._nozzle_joint;_receiver=joint.receiver
	_extracted_receiver=_receiver;_extracted_receiver.origin+=Vector3.BACK*EXTRACTION_M
	for shape: CollisionShape3D in joint.body.get_children():
		if not shape.shape is ConvexPolygonShape3D:return false
		var local:=AABB(shape.shape.points[0],Vector3.ZERO)
		for point: Vector3 in shape.shape.points:local=local.expand(point)
		_nozzle_bounds[shape]={"resource":shape.shape,"bounds":local}
		for point: Vector3 in shape.shape.points:_nozzle_radius=maxf(_nozzle_radius,(shape.transform*point).length())
	# The receiving seat and captured nut travel with the cloth as well as
	# the barrel. Preserve their bores with native angular stock sectors.
	var nut_mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=joint.stock.physical_nut.get_faces()
	var indices:=PackedInt32Array();indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
	for i in indices.size():indices[i]=i
	arrays[Mesh.ARRAY_INDEX]=indices
	nut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for row: Dictionary in [{"mesh":joint.seat.mesh,"nut":false,"cuts":[-.016,0.,.005,.014,.017]}, {"mesh":nut_mesh,"nut":true,"cuts":[.005,.0055,.014,.017,.0285,.029]}]:
		var cuts: Array[float]=[]
		for height: float in row.cuts:cuts.append(height)
		var cells: Array[ConvexPolygonShape3D]=preload("res://scripts/props/native_annular_collision.gd").build(row.mesh,cuts,48)
		if cells.is_empty():return false
		for cell: ConvexPolygonShape3D in cells:
			var bounds:=AABB(cell.points[0],Vector3.ZERO)
			for point: Vector3 in cell.points:bounds=bounds.expand(point)
			_receiving_stock.append({"shape":cell,"bounds":bounds,"nut":row.nut})
	if not _configure_skin(asset_path,projection):return false
	if placement.get("points") is not Array or placement.points.size()!=rig.rest.size():return false
	for row: Array in placement.points:
		if row.size()!=3:return false
		_placement.append(model.transform.affine_inverse()*Vector3(.340-float(row[0]),row[1],row[2]))
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	# Bound the discrete mitres by the round outer section. Inflate the
	# required span by the numerical tolerance BEFORE deriving solver radii,
	# so accepting that tolerance cannot violate the physical span below.
	_bend_radii.resize(rig.rest.size());_bend_radii.fill(.02152)
	for i in range(1,rig.rest.size()-1):
		var first: float=rig.strand.lengths[i-1];var second: float=rig.strand.lengths[i]
		var angle: float=minf(PI*.5,2.*atan(minf(first,second)/(2.*.02152)))
		var span: float=sqrt(first*first+second*second+2.*first*second*cos(angle))
		_physical_bend_spans.append(span)
		var target: float=span+.00002
		if target>=first+second:return false
		var solver_angle: float=acos(clampf((target*target-first*first-second*second)/(2.*first*second),-1.,1.))
		_bend_radii[i]=(first+second)*.5/solver_angle
	if not kernel.configure(rig.strand.lengths,_placement,_bend_radii):return false
	if not kernel.coupled.set_bend_error(.00002):return false
	kernel.bend_error_m=.00002
	var tip: Vector3=model.transform.affine_inverse()*(_receiver.origin+Vector3.BACK*EXTRACTION_M)
	# The barrel extends along receiver +Y; cloth leaves the back of its
	# socket along -Y. Reversing this creates a needless loop inside the tip.
	var into_hose: Vector3=-(model.basis.inverse()*_receiver.basis.y)
	var pins: Dictionary={0:tip,1:tip+into_hose*.005,2:tip+into_hose*.010,
		rig.rest.size()-2:_placement[-2],rig.rest.size()-3:_placement[-3]}
	for attempt in 16:
		var solved: PackedVector3Array=kernel.follow(_placement,rig.strand.anchor,{},pins,attempt>0)
		if not solved.is_empty():_placement=solved;break
		if kernel.coupled.last_iterate.size()!=_placement.size():error=kernel.error;return false
		if attempt==15:error=kernel.error;return false
		_placement=kernel.coupled.last_iterate.duplicate()
	if not rig.strand._valid_positions(_placement):error="unracked placement changes material length";return false
	var own: Dictionary=kernel.coupled.round_self_constraints(_placement,_placement,.021,pins)
	if not own.valid or not own.clear:error="unracked placement has round self contact: "+str(own);return false
	_receiver_from_tip=rig.model_frames(_placement)[0].affine_inverse()*model.transform.affine_inverse()*(_receiver*Transform3D(Basis.IDENTITY,_receiver.basis.inverse()*Vector3.BACK*EXTRACTION_M))
	setup_ms=(Time.get_ticks_usec()-started)/1000.
	set_process(false);set_physics_process(false)
	return true

func prepare_contact() -> bool:
	var excluded: Array[RID]=[actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	if not joint.loose:excluded.append(joint.body.get_rid())
	for node: Node3D in _stored:
		for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	if not contact.configure(rig,get_world_3d().direct_space_state,excluded):error=contact.error;return false
	_contact_exclusions=excluded.duplicate()
	contact.analytic_boxes=true
	var before: PackedVector3Array=rig.strand.points
	rig.strand.points=_placement
	tether.round_self_radius_m=.021
	tether.lock_tip_direction=false
	if guide_enabled:tether.substep_m=.08
	var prepared: bool=tether.configure(rig,contact,_bend_radii)
	rig.strand.points=before
	if not prepared:return false
	if not tether.kernel.coupled.set_bend_error(.00002):return false
	tether.kernel.bend_error_m=.00002
	var up: Vector3=model.basis.inverse()*Vector3.UP
	_guide_floor=up.dot(model.transform.affine_inverse()*Vector3(0,ground_y_local+.023,0))
	if guide_enabled:
		tether.seed_factory=_guide_seed
	var pins: Dictionary={0:_placement[0],1:_placement[1],2:_placement[2],_placement.size()-2:_placement[-2],_placement.size()-3:_placement[-3]}
	if guide_enabled:
		var seed: PackedVector3Array=_guide_seed(_placement,_placement[0])
		if seed.is_empty():error="simple extended guide unavailable";return false
		pins[1]=seed[1];pins[2]=seed[2]
		var guided: PackedVector3Array=tether.kernel.follow(seed,rig.strand.anchor,{},pins)
		if guided.is_empty():error="initial simple guide fit: "+tether.kernel.error;return false
		_placement=guided
	var planes: Dictionary={}
	for attempt in 16:
		var occupied: Dictionary=contact.contact_constraints(_placement,4096)
		if not occupied.valid or occupied.truncated:error="invalid initial native hose contacts";return false
		if occupied.planes.is_empty():
			if not _physical_bends_clear(_placement):error="initial round hose physical bend bound";return false
			var own: Dictionary=tether.kernel.coupled.round_self_constraints(_placement,_placement,.021,pins)
			if not own.valid or not own.clear:error="world-fitted layout has round self contact: "+str(own);return false
			_extracted_receiver=model.transform*rig.model_frames(_placement)[0]*_receiver_from_tip
			return true
		for plane: Dictionary in occupied.planes:tether._merge(planes,plane)
		var fitted: PackedVector3Array=tether.kernel.follow(_placement,rig.strand.anchor,planes,pins)
		if fitted.is_empty():error="initial hose contact fit: "+tether.kernel.error;return false
		_placement=fitted
	error="initial hose contact fit ceiling";return false

func _guide_seed(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	var retained: PackedVector3Array=before
	var tension: float=clampf((goal.distance_to(rig.strand.anchor)-11.)/8.,0.,.35)
	if tension>0.:
		# The loose floor route must lift inside the case under tension. Give
		# the solver a shorter spatial route, retaining EVERY material interval
		# and the fixed native port. Actual swept contact still vetoes this hint.
		retained=before.duplicate()
		var into_model: Basis=model.basis.inverse()
		var neck: int=before.size()-4
		retained[neck]=retained[neck+1]+into_model*Vector3.DOWN*rig.strand.lengths[neck]
		var horizontal:=Vector3(-sqrt(1.-.4*.4),0,.4)
		var directions: Array[Vector3]=[Vector3(-sin(.14),-cos(.14),0),horizontal*sin(deg_to_rad(85.))+Vector3.DOWN*cos(deg_to_rad(85.)),horizontal,horizontal]
		for offset in 4:
			var index: int=neck-1-offset
			var current: Vector3=(before[index]-before[index+1]).normalized()
			var desired: Vector3=(into_model*directions[offset]).normalized()
			retained[index]=retained[index+1]+current.slerp(desired,tension).normalized()*rig.strand.lengths[index]
	var seed: Dictionary=tether.kernel.coupled.round_guide_seed(retained,goal,before.size()-8,model.basis.inverse()*guide_axis_local,model.basis.inverse()*guide_side_local,_guide_floor)
	return seed.points

func _physical_bends_clear(points: PackedVector3Array) -> bool:
	if points.size()!=_physical_bend_spans.size()+2:return false
	for i in _physical_bend_spans.size():
		if points[i].distance_to(points[i+2])<_physical_bend_spans[i]-.000001:return false
	return true

func grip() -> Dictionary:
	if not deployed and not actor.door_open:return {}
	var part: Node3D=joint.seat if joint.loose else actor._play_pipe
	if deployed:
		return {"owner":actor,"part":part,"frame":model,"kind":"free",
			"physics_body":joint.body if not joint.loose else null,
			"bind_holder":_bind_hose_holder,
			"hold_pose":_hold_pose if fps_aim_enabled else null,
			"read":func():return rig.strand.points[0],"write":_move,
			"begin":_begin_hose,"owns":func():return actor._hand=="hose",
			"motion_pending":func():return tether.pending,"constraint_feedback":_constraint_feedback,"end":_release}
	return {"owner":actor,"part":part,"frame":actor,"kind":"slider","axis":Vector3.BACK,
		"minimum":0.,"maximum":EXTRACTION_M,"read":func():return extraction,"write":_extract,
		"continue_grab":func():return grip() if visual_follow_enabled and deployed else {},
		"begin":_begin_hose,"owns":func():return actor._hand=="hose","constraint_feedback":_extraction_feedback,"end":_release}

func _begin_hose() -> bool:
	if not tether.set_hand_follow_budget(.6 if fps_aim_enabled else tether.MAX_MOVE_M,12000 if fps_aim_enabled else tether.WORK_BUDGET_USEC):return false
	if not actor._claim("hose"):return false
	error="";tether.blocked=false;tether.limited=false;return true

func _bind_hose_holder(holder: Node3D) -> void:
	_inspection_holder=null
	_hold_frame=-1;_last_hold_usec=0
	_clear_cover_passage();_clear_auxiliary_contacts();_carrier=weakref(holder);_refresh_cover_passage()
	if holder is not PhysicsBody3D:return
	var roots: Array[Node]=[joint.seat]
	if not joint.loose:roots.append_array([joint.nut,joint.physical_nut,actor._bodies.lever])
	var parts: Array[PhysicsBody3D]=[]
	for root: Node in roots:
		if root is PhysicsBody3D and not parts.has(root):parts.append(root)
		for part: PhysicsBody3D in root.find_children("*","PhysicsBody3D",true,false):
			if not parts.has(part):parts.append(part)
	for part: PhysicsBody3D in parts:
		if part==joint.body or part==holder:continue
		var holder_added: bool=not holder.get_collision_exceptions().has(part)
		var part_added: bool=not part.get_collision_exceptions().has(holder)
		if holder_added:holder.add_collision_exception_with(part)
		if part_added:part.add_collision_exception_with(holder)
		_auxiliary_contacts.append({"body":part,"holder_added":holder_added,"part_added":part_added})

func _clear_auxiliary_contacts() -> void:
	var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
	for row: Dictionary in _auxiliary_contacts:
		var part: PhysicsBody3D=row.body
		if holder==null or not is_instance_valid(part):continue
		if row.holder_added:holder.remove_collision_exception_with(part)
		if row.part_added:part.remove_collision_exception_with(holder)
	_auxiliary_contacts.clear()

func _refresh_cover_passage() -> void:
	if not actor.door_open or joint.loose or actor._hand!="hose":
		_clear_cover_passage();return
	if is_instance_valid(_cover):return
	var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
	if holder==null:return
	_cover=actor._bodies.door
	_cover_stock_added=not joint.body.get_collision_exceptions().has(_cover)
	_cover_holder_added=not holder.get_collision_exceptions().has(_cover)
	if _cover_stock_added:joint.body.add_collision_exception_with(_cover)
	if _cover_holder_added:holder.add_collision_exception_with(_cover)

func _clear_cover_passage() -> void:
	if is_instance_valid(_cover):
		if _cover_stock_added and is_instance_valid(joint):joint.body.remove_collision_exception_with(_cover)
		var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
		if _cover_holder_added and holder!=null:holder.remove_collision_exception_with(_cover)
	_cover=null;_cover_stock_added=false;_cover_holder_added=false

func _exit_tree() -> void:
	_wet_clear()
	_clear_cover_passage();_clear_auxiliary_contacts()
	if is_instance_valid(actor) and actor._live_hose==self:actor._live_hose=null
	if is_instance_valid(_spray):_spray.queue_free()

func _hold_pose(view: Transform3D) -> void:
	_refresh_cover_passage()
	if fps_once_per_frame:
		var frame: int=Engine.get_process_frames()
		if frame==_hold_frame:return
		_hold_frame=frame
	if visual_follow_enabled:
		var aimed:=Basis(view.basis.x,-view.basis.z,view.basis.y)
		var wanted:=Transform3D(aimed*Basis(Vector3.UP,-joint.clocking),view*Vector3(.17,-.16,-.48))
		_visual_receiver(wanted)
		return
	if not fps_aim_enabled:
		# Preserve the previous position-only candidate for isolated controls.
		var point: Vector3=joint.body.global_position
		_move(rig.strand.points[0]+model.global_basis.inverse()*(view*Vector3(.17,-.16,-.48)-point).limit_length(.06))
		return
	var before: PackedVector3Array=rig.strand.points
	var direction: Vector3=(before[1]-before[0]).normalized()
	var desired: Vector3=(model.global_basis.inverse()*view.basis.z).normalized()
	var goal: Vector3=model.to_local(view*Vector3(.17,-.16,-.48))
	# Withdraw into the hand before turning beside the rack and open leaf.
	# A blocked translation still remains blocked by the original fitting sweep.
	if before[0].distance_to(goal)>.12:desired=direction
	var angle: float=acos(clampf(direction.dot(desired),-1.,1.))
	var now: int=Time.get_ticks_usec()
	var elapsed: float=minf(float(now-_last_hold_usec)/1000000.,.1) if fps_once_per_frame and _last_hold_usec>0 else get_physics_process_delta_time()
	_last_hold_usec=now
	var turn: float=minf(angle,6.*elapsed)
	if angle>.00001:
		# Antiparallel directions need an explicit stable perpendicular axis.
		var axis: Vector3=direction.cross(desired)
		if axis.length_squared()<1e-12:axis=direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT)
		direction=direction.rotated(axis.normalized(),turn).normalized()
	if tether.tip_direction.distance_to(direction)>.000001:tether.cancel_motion()
	if profile_motion:last_hand_debug={"frame":Engine.get_process_frames(),"distance_to_hand":before[0].distance_to(goal),"angle":angle,"elapsed":elapsed,"turn":turn,"requested":[direction.x,direction.y,direction.z],"desired":[desired.x,desired.y,desired.z]}
	tether.tip_direction=direction;_local_follow.tip_direction=direction
	_move(before[0]+(goal-before[0]).limit_length(minf(.6,12.*elapsed)))

func _constraint_feedback() -> String:
	if visual_follow_enabled:
		if not error.is_empty():return "blocked"
		return "limit" if visual_route.limited else "grabbed"
	if tether.pending:return "grabbed"
	if not error.is_empty() or tether.blocked:return "blocked"
	return "limit" if tether.limited else "grabbed"

func _extraction_feedback() -> String:
	if not error.is_empty():return "blocked"
	return "limit" if extraction>=EXTRACTION_M-.000001 else "grabbed"

func _nozzle_clear(receiver: Transform3D) -> bool:
	last_fitting_blocker=""
	if not _receiving_stock_clear(receiver):return false
	if joint.loose:return true
	var pose: Transform3D=actor.global_transform*joint.thread_pose(joint.angle)
	var proposed: Transform3D=actor.global_transform*receiver*Transform3D(Basis(Vector3.UP,joint.clocking),Vector3(0,joint.stock.body_y(joint.angle),0))
	var excluded: Array[RID]=[joint.body.get_rid(),actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	_append_carried_exclusions(excluded)
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	# Receiver transport can change the child collider frames independently
	# of the lever angle. Transform immutable local bounds; do not regenerate
	# the receiver's expensive radial contact profiles for a broad-phase test.
	var bounds:=AABB();var first:=true;var radius:=0.
	for shape: CollisionShape3D in joint.body.get_children():
		if shape.disabled:continue
		if not _nozzle_bounds.has(shape) or _nozzle_bounds[shape].resource!=shape.shape:return false
		var local: AABB=shape.transform*_nozzle_bounds[shape].bounds
		radius=maxf(radius,local.position.abs().max(local.end.abs()).length())
		var current: AABB=pose*local
		current=current.merge(proposed*local)
		bounds=current if first else bounds.merge(current);first=false
	if first:return false
	var motion: Vector3=proposed.origin-pose.origin
	var angle: float=pose.basis.get_rotation_quaternion().angle_to(proposed.basis.get_rotation_quaternion())
	# Endpoint boxes contain every vertex chord. Inflate by the maximum
	# circular-arc sagitta to contain the complete rotation between endpoints.
	bounds=bounds.grow(radius*(1.-cos(angle*.5))+.0001)
	var space:=get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=excluded;query.margin=0.
	_nozzle_box.size=bounds.size;query.shape=_nozzle_box;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	var broad_clear: bool=space.intersect_shape(query,1).is_empty()
	if cast_observer.is_valid():_fitting_candidates=space.intersect_shape(query,256)
	last_nozzle_query={"motion":motion,"broad_clear":broad_clear}
	if broad_clear:return true
	# The coupled body is frozen. Sweep its actual convex stock directly,
	# including the lever, rather than relying on dynamic-body motion recovery.
	query.margin=.00002
	for shape: CollisionShape3D in joint.body.get_children():
		if shape.disabled:continue
		if not shape.shape is ConvexPolygonShape3D:return false
		if angle>.000001:
			# Reuse cached stock at each short arc's midpoint orientation.
			# Inflation bounds every vertex's displacement from that midpoint;
			# the translation cast covers the simultaneous origin movement.
			var steps: int=ceili(angle/.04)
			if steps>64:return false
			query.margin=2.*radius*sin(angle/(4.*steps))+.00002
			query.shape=shape.shape
			var first_rotation: Quaternion=pose.basis.get_rotation_quaternion()
			var last_rotation: Quaternion=proposed.basis.get_rotation_quaternion()
			for step in steps:
				var fraction: float=float(step)/steps
				var basis:=Basis(first_rotation.slerp(last_rotation,(float(step)+.5)/steps))
				query.transform=Transform3D(basis,pose.origin+motion*fraction)*shape.transform;query.motion=Vector3.ZERO
				if not _fitting_probe_clear(space,query,"barrel rotation"):return false
				query.motion=motion/steps
				if not _fitting_sweep_clear(space,query,"barrel arc"):return false
			continue
		query.shape=shape.shape;query.transform=proposed*shape.transform;query.motion=Vector3.ZERO
		if not _fitting_probe_clear(space,query,"barrel endpoint"):return false
		query.transform=pose*shape.transform;query.motion=proposed.origin-pose.origin
		if not _fitting_sweep_clear(space,query,"barrel translation"):return false
	return true

func _fitting_sweep_clear(space: PhysicsDirectSpaceState3D,query: PhysicsShapeQueryParameters3D,stage: String) -> bool:
	var result: PackedFloat32Array=space.cast_motion(query)
	if result.size()==2 and result[0]>=1.:return true
	if cast_observer.is_valid():cast_observer.call(query,_fitting_candidates,stage,result)
	last_fitting_blocker=stage+": fractions="+str(result)
	if profile_motion and result.size()==2:
		var original: Transform3D=query.transform;var motion: Vector3=query.motion
		query.transform=original.translated(motion*result[1]);query.motion=Vector3.ZERO
		var hits: Array[Dictionary]=space.intersect_shape(query,1)
		if not hits.is_empty():
			var collider: Object=hits[0].get("collider")
			last_fitting_blocker+=" "+(str(collider.get_path()) if collider is Node else str(collider))
		query.transform=original;query.motion=motion
	return false

func _append_carried_exclusions(excluded: Array[RID]) -> void:
	# Manual fitting queries must share the body's authoritative exceptions:
	# the carrier and any unlocked leaf accommodated by EasyDoorMotion.
	# No wall, locked leaf or unrelated body is added here.
	if joint.loose or actor._hand!="hose":return
	for body: PhysicsBody3D in joint.body.get_collision_exceptions():
		var rid: RID=body.get_rid()
		if not excluded.has(rid):excluded.append(rid)

func _refresh_carry_contacts() -> void:
	if not contact.ready:return
	var excluded: Array[RID]=_contact_exclusions.duplicate()
	_append_carried_exclusions(excluded)
	if excluded!=contact.exclusions:contact.set_exclusions(excluded)

func _fitting_probe_clear(space: PhysicsDirectSpaceState3D,query: PhysicsShapeQueryParameters3D,stage: String) -> bool:
	var hits: Array[Dictionary]=space.intersect_shape(query,1)
	if hits.is_empty():return true
	var collider: Object=hits[0].get("collider")
	last_fitting_blocker=stage+": "+(str(collider.get_path()) if collider is Node else str(collider))
	return false

func _receiving_stock_clear(receiver: Transform3D) -> bool:
	var before: Transform3D=actor.global_transform*joint.receiver
	var after: Transform3D=actor.global_transform*receiver
	var excluded: Array[RID]=[actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	_append_carried_exclusions(excluded)
	if not joint.loose:excluded.append(joint.body.get_rid())
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	var space:=get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=excluded
	var bounds:=AABB();var first:=true;var radius:=0.
	var spin:=Transform3D(Basis(Vector3.UP,joint.angle+joint.spin),Vector3.ZERO)
	for row: Dictionary in _receiving_stock:
		var local: AABB=(spin*row.bounds) if row.nut else row.bounds
		radius=maxf(radius,local.position.abs().max(local.end.abs()).length())
		var swept: AABB=(before*local).merge(after*local)
		bounds=swept if first else bounds.merge(swept);first=false
	if first:return false
	var angle: float=before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())
	bounds=bounds.grow(radius*(1.-cos(angle*.5))+.0001)
	_nozzle_box.size=bounds.size;query.shape=_nozzle_box;query.margin=0.;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	if space.intersect_shape(query,1).is_empty():return true
	var steps: int=maxi(1,ceili(angle/.04))
	if steps>64:return false
	query.margin=2.*radius*sin(angle/(4.*steps))+.00002
	for row: Dictionary in _receiving_stock:
		query.shape=row.shape
		var local: Transform3D=spin if row.nut else Transform3D.IDENTITY
		for step in steps:
			var fraction: float=float(step)/steps
			var rotation:=Basis(before.basis.get_rotation_quaternion().slerp(after.basis.get_rotation_quaternion(),(float(step)+.5)/steps))
			query.transform=Transform3D(rotation,before.origin.lerp(after.origin,fraction))*local;query.motion=Vector3.ZERO
			if not _fitting_probe_clear(space,query,"receiver rotation"):return false
			query.motion=(after.origin-before.origin)/steps
			if not _fitting_sweep_clear(space,query,"receiver arc"):return false
	return true

func _extract(value: float) -> void:
	if actor._hand!="hose" or deployed or not is_finite(value):return
	value=clampf(value,0.,EXTRACTION_M)
	var proposed:=_receiver;proposed.origin+=Vector3.BACK*value
	proposed.basis=Basis(_receiver.basis.get_rotation_quaternion().slerp(_extracted_receiver.basis.get_rotation_quaternion(),value/EXTRACTION_M))
	if not visual_follow_enabled and not _nozzle_clear(proposed):error="nozzle extraction obstructed";return
	if value>=EXTRACTION_M-.000001:
		# Representation swap is discrete and authorized. Occupancy is checked
		# afresh; no sweep from a completely different folded topology is faked.
		if not visual_follow_enabled and (not contact.ready or contact.intersects_pose(_placement)):error="unracked placement obstructed";return
		if not rig.apply_points(_placement,water.pressure if visual_follow_enabled else 1.):error="unracked native skin unavailable";return
		rig.strand.points=_placement.duplicate();_show_deployment(true);actor.hose_racked=false
	joint.receiver=proposed;joint.sync();extraction=value;error=""

func _move(value: Vector3) -> void:
	if actor._hand!="hose" or not deployed or not value.is_finite():return
	if visual_follow_enabled:
		var wanted: Transform3D=actor.global_transform*joint.receiver
		wanted.origin=model.to_global(value);_visual_receiver(wanted);return
	_refresh_cover_passage()
	_refresh_carry_contacts()
	tether.collect_profile=profile_motion
	var started: int=Time.get_ticks_usec() if profile_motion else 0
	_last_fitting_usec=0;_last_broad_queries=contact.broad_queries;_last_shell_queries=contact.shell_queries
	var prepared: bool=tether.prepare_endpoint(value)
	_last_prepare_usec=Time.get_ticks_usec()-started if profile_motion else 0
	if not prepared:
		error=tether.error;set_process(tether.pending);_record_motion_profile(started);return
	_commit_motion()
	set_process(tether.pending)
	_record_motion_profile(started)

func _record_motion_profile(started: int) -> void:
	if not profile_motion:return
	last_motion_profile={"total_usec":Time.get_ticks_usec()-started,"prepare_usec":_last_prepare_usec,"fitting_usec":_last_fitting_usec,"tether":tether.profile_usec.duplicate(),"broad_queries":contact.broad_queries-_last_broad_queries,"shell_queries":contact.shell_queries-_last_shell_queries,"responses":tether.responses,"native_iterations":tether.kernel.coupled.iterations,"native_qp_iterations":tether.kernel.coupled.qp_iterations,"local_enabled":local_follow_enabled,"local_join":_local_follow.last_join if local_follow_enabled else -1,"local_usec":_local_follow.last_usec if local_follow_enabled else 0}
	last_motion_profile.physics_frame=Engine.get_physics_frames();last_motion_profile.process_frame=Engine.get_process_frames()
	motion_profile_records.append(last_motion_profile)
	if motion_profile_records.size()>512:motion_profile_records.pop_front()

func _process(_delta: float) -> void:
	if actor._hand!="hose" or not deployed:tether.cancel_motion();set_process(false);return
	_refresh_cover_passage();_refresh_carry_contacts()
	if tether.pending and tether.resume_prepare():_commit_motion()
	set_process(tether.pending)

func _commit_motion() -> void:
	if not tether.has_prepared_endpoint():return
	var points: PackedVector3Array=tether.prepared_endpoint_points()
	if not _physical_bends_clear(points):tether.cancel_motion();error="round hose physical bend bound";return
	var receiver: Transform3D=model.transform*rig.model_frames(points)[0]*_receiver_from_tip
	var started: int=Time.get_ticks_usec() if profile_motion else 0
	var clear: bool=_nozzle_clear(receiver)
	_last_fitting_usec=Time.get_ticks_usec()-started if profile_motion else 0
	if not clear:tether.cancel_motion();error="nozzle obstructed";return
	if not tether.commit_endpoint():error=tether.error;return
	joint.receiver=receiver;joint.sync();error=""

func _release() -> void:
	var holder: Node3D=_carrier.get_ref() if _carrier!=null else null
	# Inspection borrows the hand after setting its active state. Preserve its
	# static mechanism view; an ordinary release instead places the nozzle once.
	if visual_follow_enabled and deployed and not joint.loose and is_instance_valid(holder):
		if holder.has_method("inspecting") and holder.inspecting():_inspection_holder=weakref(holder)
		else:_inspection_holder=null;release_support.place(self,holder)
	_clear_cover_passage();_clear_auxiliary_contacts();_carrier=null
	if contact.ready:contact.set_exclusions(_contact_exclusions)
	tether.cancel_motion();set_process(false);actor._release()

func inspection_control_exclusions() -> Array[RID]:
	# The same pickup bookmark that restores the shared hand authorizes this
	# narrow self-body exclusion. Ordinary cabinet inspection does not.
	var holder: Node3D=_inspection_holder.get_ref() if _inspection_holder!=null else null
	if joint.loose or not is_instance_valid(holder) or not holder.has_method("inspecting") or not holder.inspecting() or holder.inspect_owner!=actor:return []
	var pickup: Dictionary=holder._inspect_pickup
	if pickup.get("owner")!=actor or pickup.get("part")!=actor._play_pipe or holder is not CollisionObject3D:return []
	return [holder.get_rid()]
