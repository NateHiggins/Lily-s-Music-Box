extends RefCounted
## Passage-first door presentation. Locks, angles and durable state stay on DoorProp.
const DELAY_SECONDS := 3.5
const CLOSE_RADIANS_PER_SECOND := .20
var door: Node3D
var holder: WeakRef
var closing := false
var remaining := 0.0
var _excepted: CharacterBody3D
var _added_exception := false
var _held_stock: PhysicsBody3D
var _added_stock_exception := false

func _init(owner_node: Node3D) -> void:
	door=owner_node

func bind_holder(actor: Node3D) -> void:
	stop()
	holder=weakref(actor)
	if door.leaf_state!="locked":_allow_player(actor)

func prepare_motion() -> void:
	if door.leaf_state=='locked':return
	var actor: Node3D=door.get_tree().get_first_node_in_group('player_controller')
	if actor!=null:_allow_player(actor)

func _allow_player(actor: Node3D) -> void:
	if actor is not CharacterBody3D:return
	if _excepted==actor:
		_refresh_held_stock(actor);return
	_restore_collision()
	_excepted=actor
	_added_exception=not actor.get_collision_exceptions().has(door._body)
	if _added_exception:actor.add_collision_exception_with(door._body)
	_refresh_held_stock(actor)

func _refresh_held_stock(actor: Node3D) -> void:
	var stock: PhysicsBody3D=actor.held_stock_body() if actor.has_method("held_stock_body") else null
	if stock==_held_stock:return
	_restore_stock_collision()
	_held_stock=stock
	if stock==null:return
	_added_stock_exception=not stock.get_collision_exceptions().has(door._body)
	if _added_stock_exception:stock.add_collision_exception_with(door._body)

func _restore_stock_collision() -> void:
	if is_instance_valid(_held_stock) and _added_stock_exception and is_instance_valid(door._body):
		_held_stock.remove_collision_exception_with(door._body)
	_held_stock=null;_added_stock_exception=false

func _restore_collision() -> void:
	_restore_stock_collision()
	if is_instance_valid(_excepted) and _added_exception and is_instance_valid(door._body):
		_excepted.remove_collision_exception_with(door._body)
	_excepted=null;_added_exception=false

func accommodate(angle: float) -> void:
	if door.leaf_state=='locked' or holder==null:return
	var actor: Node3D=holder.get_ref()
	if actor==null or not actor is CharacterBody3D:return
	var old: float=door._body.rotation.y
	if absf(old)>.03 or absf(angle)<=absf(old):return
	var at: Vector3=door.to_local(actor.global_position)
	# Only back away if the opening comes toward the player. The ordinary
	# character move retains walls and floors; no door impact query is made.
	if at.x<-.35 or at.x>door.width+.35 or at.z*signf(angle)>=0 or absf(at.z)>=.85:return
	var direction: Vector3=door.global_basis.z.normalized()*(-1.0 if at.z<=0 else 1.0)
	actor.move_and_collide(direction*minf(.45,.85-absf(at.z)))

func stop() -> void:
	closing=false;remaining=0.0
	door.set_physics_process(false)

func schedule() -> void:
	if not door.open or door.leaf_state=='locked':
		if _in_passage():remaining=.75;door.set_physics_process(true);return
		_restore_collision();stop();return
	var actor: Node3D=door.get_tree().get_first_node_in_group('player_controller')
	if actor!=null:_allow_player(actor)
	remaining=DELAY_SECONDS;closing=false;door.set_physics_process(true)

func _in_passage() -> bool:
	if not is_instance_valid(_excepted):return false
	var at: Vector3=door.to_local(_excepted.global_position)
	return at.x>-.40 and at.x<door.width+.40 and absf(at.z)<.50 and at.y>-.2 and at.y<door.height+.2

func update(delta: float) -> void:
	if not is_instance_valid(_excepted):prepare_motion()
	if is_instance_valid(_excepted):_refresh_held_stock(_excepted)
	if door._hand_gripped or door._key_turning or door._moving:return
	if _in_passage():remaining=maxf(remaining,.75);return
	if remaining>0:
		remaining=maxf(0,remaining-delta);return
	if not closing:door.motion_revision+=1
	closing=true
	door._body.rotation.y=move_toward(door._body.rotation.y,0,delta*CLOSE_RADIANS_PER_SECOND)
	door.open=absf(door._body.rotation.y)>.001
	if not door.open:
		door._body.rotation.y=0.0;_restore_collision();stop();door._settled();door.manipulation_changed.emit()

func release() -> void:
	_restore_collision();holder=null
