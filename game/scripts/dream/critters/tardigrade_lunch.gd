extends RefCounted
## A bounded resource-transfer pantomime between two private Dream organelles.
## Local surface movement and actual mouth contact own success, never a timer kill.
var _owner: WeakRef
var owner:
	get: return _owner.get_ref() if _owner != null else null
	set(value): _owner = weakref(value)
var prey_id := -1
var state := "hungry"
var clock := 0.0
var cooldown := 6.0
var encounter := 0.0
var attempts := 0
var meals := 0
var misses := 0
var escapes := 0
var dodge := Vector3.ZERO
var strike := Vector3.ZERO
var events: Array[String] = []
var enabled := true

func specimen(controller, id: int) -> Dictionary:
	for c in controller.critters:
		if int(c.id) == id: return c
	return {}

func _enter(next: String) -> void:
	state = next
	clock = 0.0
	events.append(next)
	if events.size()>64: events.pop_front()

func mouth(c: Dictionary) -> Vector3:
	return (c.pos as Vector3)+(c.fwd as Vector3)*float(c.morph.length)*.48-(c.up as Vector3)*float(c.morph.tall)*.28

func _clear(controller, consumed: bool) -> void:
	for i in range(controller.critters.size()-1,-1,-1):
		if int(controller.critters[i].id)==prey_id:
			controller.critter_died.emit(prey_id)
			controller.critters.remove_at(i)
	prey_id = -1
	if consumed: meals += 1
	else: escapes += 1
	cooldown = 45.0 if consumed else 24.0
	_enter("groom" if consumed else "hungry")

func advance(controller, delta: float) -> void:
	if not enabled: return
	clock += delta
	cooldown = maxf(0.0,cooldown-delta)
	var t := specimen(controller,owner.specimen_id)
	if t.is_empty(): return
	t.meal = Vector4.ZERO
	var p := specimen(controller,prey_id)
	if prey_id>=0 and p.is_empty():
		prey_id = -1
		cooldown = 12.0
		_enter("hungry")
	if p.is_empty():
		if state=="groom" and clock>1.8: _enter("sated")
		if cooldown<=0.0: _spawn(controller,t)
		return
	p.meal = Vector4.ZERO
	encounter += delta
	# A failed hunt must never suppress the hint system indefinitely.
	if encounter>32.0 or (t.pos as Vector3).distance_to(owner.player.global_position)>4.0:
		_clear(controller,false)
		return
	if owner.near_resident(t.pos) != Vector3.INF:
		# A frightening resident interrupts lunch as well as repairs.
		if state=="feed": _enter("chase")
		return
	var gap := mouth(t).distance_to(p.pos)
	if state=="stalk" and clock>1.1: _enter("chase")
	elif state=="chase" and gap<.38:
		attempts += 1
		strike=(p.pos as Vector3)-(t.pos as Vector3)
		dodge = (t.up as Vector3).cross(t.fwd).normalized() * (-1.0 if attempts%2==0 else 1.0)
		_enter("windup")
	elif state=="windup" and clock>.5: _enter("pounce")
	elif state=="pounce":
		if gap<.16 and _clear_contact(controller,mouth(t),p.pos):
			_enter("feed")
		elif clock>.65:
			misses += 1
			_enter("miss")
	elif state=="miss" and clock>.8: _enter("chase")
	elif state=="feed":
		# Contact is rechecked; no aspiration through walls or across a room.
		if gap>.24 or not _clear_contact(controller,mouth(t),p.pos):
			_enter("chase")
		else:
			t.meal = Vector4(.5+.5*sin(clock*16.0),0,0,0)
			p.meal = Vector4(0,clampf(clock/2.6,0,1),0,0)
			if clock>=2.6: _clear(controller,true)

func _clear_contact(controller, a: Vector3, b: Vector3) -> bool:
	if controller._space==null: return false
	return controller._space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b)).is_empty()

func _spawn(controller, t: Dictionary) -> void:
	if controller._space==null or controller.critters.size()>=controller.MAX_LIVE: return
	if owner.near_resident(t.pos)!=Vector3.INF: return
	var up: Vector3 = t.up
	var at: Vector3 = t.pos + (t.fwd as Vector3)*.85 + up.cross(t.fwd)*.18
	var hit: Dictionary = controller._space.intersect_ray(PhysicsRayQueryParameters3D.create(at+up*.4,at-up*.8))
	if hit.is_empty() or not _clear_contact(controller,t.pos,at):
		cooldown=3.0
		return
	var morph: Dictionary = controller.GeneratorScript.generate(7,240307+meals+escapes)
	var p: Dictionary = controller._spawn_specimen(morph,hit.position+hit.normal*float(morph.tall)*.5,hit.normal,INF,null,{})
	p.fwd = t.fwd
	prey_id = int(p.id)
	encounter = 0.0
	attempts = 0
	_enter("stalk")

func steer_tardi(c: Dictionary, controller, delta: float) -> bool:
	if not enabled: return false
	var p := specimen(controller,prey_id)
	if p.is_empty():
		if state!="groom": return false
		c.moving=false
		c.spin=float(c.age)*4.0
		return true
	c.moving = state in ["stalk","chase","pounce"]
	c.lunch_speed = .45 if state=="stalk" else (2.8 if state=="pounce" else 1.35)
	c.pause = .5
	if c.moving:
		controller._turn_toward(c,strike if state=="pounce" else (p.pos as Vector3)-(c.pos as Vector3),delta*(3.0 if state=="pounce" else 1.4))
	c.companion_state = state
	c.companion_target = "lunch:euplotes"
	return true

func steer_prey(c: Dictionary, controller, delta: float) -> void:
	var t := specimen(controller,owner.specimen_id)
	if t.is_empty(): c.moving=false; return
	var away: Vector3 = (c.pos as Vector3)-(t.pos as Vector3)
	var want := away
	c.moving = true
	c.pause = .5
	c.lunch_speed = .55
	if owner.near_resident(c.pos)!=Vector3.INF:
		want=(c.pos as Vector3)-owner.near_resident(c.pos)
		c.lunch_speed=1.5
	elif state in ["feed","stalk","miss"]:
		# The still 'did you get me?' beat makes the following reversal readable.
		c.moving=false
	elif state in ["windup","pounce"] and attempts<3:
		want=dodge+away.normalized()*.22
		c.lunch_speed=3.8
	elif attempts>=3:
		c.lunch_speed=.1 # finite escape stamina; catch still requires real contact
	else:
		want=away.rotated(c.up,sin(clock*3.0)*.65)
	if c.moving: controller._turn_toward(c,want,delta*12.0)
