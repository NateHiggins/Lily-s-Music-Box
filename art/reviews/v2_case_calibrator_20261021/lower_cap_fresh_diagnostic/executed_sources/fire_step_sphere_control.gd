extends PlayerController
## Test-only eligibility probe. Original full-body lift/raised-motion tests and
## slide stay authoritative. The sphere is the capsule's exact lower cap.
var foot_step_candidate:=false
var _foot: CharacterBody3D
var cost_phase:="startup"
var measured_ticks: Array=[]
func _ready() -> void:
	super._ready()
	_foot=CharacterBody3D.new();_foot.name="DiagnosticStepCap";_foot.collision_layer=0
	var sphere:=SphereShape3D.new();sphere.radius=BODY_RADIUS
	var collision:=CollisionShape3D.new();collision.shape=sphere;_foot.add_child(collision)
	add_child(_foot);_foot.add_collision_exception_with(self)
func _physics_process(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	var before: int=physics_profile_records.size()
	super._physics_process(delta)
	if profile_physics:
		var row: Dictionary={"phase":cost_phase,"total_ms":(Time.get_ticks_usec()-start)/1000.}
		if physics_profile_records.size()>before:row.merge(physics_profile_records.back())
		measured_ticks.append(row);physics_profile_records.clear()
func _try_step_up(delta: float) -> void:
	if not foot_step_candidate:super._try_step_up(delta);return
	if not is_on_floor():return
	var motion:=Vector3(velocity.x,0,velocity.z)*delta
	if motion.length()<.0005:return
	if not _profile_disable_step_guard and _blocked_above_step(motion):
		if profile_physics:step_guard_rejections+=1
		return
	var probe:=motion.normalized()*maxf(motion.length(),.06)
	_foot.collision_mask=collision_mask
	var lower_cap: Transform3D=global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*BODY_RADIUS)
	if not _foot.test_move(lower_cap,probe):return
	var lift:=Vector3.UP*.30
	if test_move(global_transform,lift):return
	if test_move(global_transform.translated(lift),probe):return
	global_position.y+=.30
