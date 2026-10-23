extends RefCounted
## Fixed cabinet hinge travel with player priority, no environment sweep.
## Cabinet remains the sole angle, hand and household-save authority.
var actor: Node3D
var holder: PlayerController
var remaining:=-1.
var closing:=false
var exceptions: Array[PhysicsBody3D]=[]

func _init(owner_actor: Node3D) -> void:actor=owner_actor
func bind_holder(player: Node3D) -> void:
	if player is not PlayerController:return
	if holder!=player:release()
	holder=player;remaining=-1.;closing=false
	var bodies: Array[PhysicsBody3D]=[actor._bodies.door]
	for body: PhysicsBody3D in actor._bodies.door.find_children("*","PhysicsBody3D",true,false):bodies.append(body)
	for body: PhysicsBody3D in bodies:
		if not holder.get_collision_exceptions().has(body):holder.add_collision_exception_with(body);exceptions.append(body)

func accommodate(angle: float) -> void:
	if not is_instance_valid(holder) or actor._door_angle>.03 or angle<=actor._door_angle:return
	var at: Vector3=actor.to_local(holder.global_position)
	if absf(at.x)>.8 or at.z<0. or at.z>=.85:return
	# Normal character motion still respects floors and walls. The cabinet
	# leaf itself never blocks opening or requires a geometry sweep.
	holder.move_and_collide(actor.global_basis.z.normalized()*minf(.35,.85-at.z))

func schedule() -> void:remaining=3.5 if actor.door_open else 0.;closing=false

func tick(delta: float) -> void:
	if remaining<0. or not actor._hand.is_empty():return
	if is_instance_valid(holder):
		var at: Vector3=actor.to_local(holder.global_position)
		if absf(at.x)<.8 and at.z>-.25 and at.z<1. and at.y>-2. and at.y<1.:
			remaining=maxf(remaining,.75);return
		if holder.inspecting() and holder.inspect_owner==actor:return
	if remaining>0.:
		remaining=maxf(0.,remaining-delta);return
	if not actor.door_open and not closing:release();return
	closing=true
	var stop: float=actor._minimum("door")
	actor._move_hand_part("door",move_toward(actor._door_angle,stop,delta*.20))
	# The maintenance-access threshold is .8 rad; keep closing the physical
	# leaf all the way to zero after that logical threshold is crossed.
	if actor._door_angle>0.:actor.door_open=actor._door_angle>=.8
	if actor._door_angle<=stop+.000001:
		actor._move_hand_part("door",stop);release();actor.manipulation_changed.emit()

func release() -> void:
	if is_instance_valid(holder):
		for body: PhysicsBody3D in exceptions:
			if is_instance_valid(body):holder.remove_collision_exception_with(body)
	exceptions.clear();holder=null;remaining=-1.;closing=false
