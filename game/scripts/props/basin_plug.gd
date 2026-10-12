extends RefCounted
## Loose plug constrained by the visible basin and its short working reach.
var owner: Node3D
var part: Node3D
var seat: Vector3
var parked: Vector3
var held := false
var falling_speed := 0.0
var triangles: Array[Vector3] = []
var ceiling := 0.0
var resting := true

func _init(fixture: Node3D, plug: Node3D, drain: Vector3, rest: Vector3) -> void:
	owner=fixture;part=plug;seat=drain;parked=rest
	ceiling=owner._water_full_y+.05
	# Cache nonvertical casting triangles within the vessel's working
	# envelope. Pipes, water, valves and the plug itself cannot support it.
	var fixed := owner.get_node("StaticFixture")
	for draw: MeshInstance3D in fixed.find_children("*","MeshInstance3D",true,false):
		var faces := draw.mesh.get_faces()
		var pose: Transform3D = owner.global_transform.affine_inverse()*draw.global_transform
		for i in range(0,faces.size(),3):
			var a: Vector3=pose*faces[i];var b: Vector3=pose*faces[i+1];var c: Vector3=pose*faces[i+2]
			if maxf(a.y,maxf(b.y,c.y))<seat.y-.04 or minf(a.y,minf(b.y,c.y))>ceiling: continue
			if absf((b-a).cross(c-a).y)<.0000001: continue
			triangles.append_array([a,b,c])
	part.position.y=maxf(part.position.y,support(part.position))
	preload("res://scripts/props/manipulation_area.gd").install(part,func(): return grip())
	update_seal()

func support(at: Vector3) -> float:
	# The drain ferrule is an intentional opening in the casting.
	if Vector2(at.x-seat.x,at.z-seat.z).length()<.018: return seat.y
	var height := _surface_height(at)
	# A flat disc must clear the whole curved bowl beneath its rim.
	for i in 8:
		var angle: float=TAU*float(i)/8.0
		height=maxf(height,_surface_height(at+Vector3(cos(angle)*.018,0,sin(angle)*.018)))
	return height

func _surface_height(at: Vector3) -> float:
	var height := seat.y
	for i in range(0,triangles.size(),3):
		var a:=triangles[i];var b:=triangles[i+1];var c:=triangles[i+2]
		var den: float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		var u: float=((b.z-c.z)*(at.x-c.x)+(c.x-b.x)*(at.z-c.z))/den
		var v: float=((c.z-a.z)*(at.x-c.x)+(a.x-c.x)*(at.z-c.z))/den
		if u<0 or v<0 or u+v>1: continue
		var y: float=u*a.y+v*b.y+(1-u-v)*c.y
		if y<=ceiling: height=maxf(height,y+.006)
	return height

func update_seal() -> void:
	owner._stopper=Vector2(part.position.x-seat.x,part.position.z-seat.z).length()<.012 and absf(part.position.y-seat.y)<.003

func write_position(value: Vector3) -> void:
	if not value.is_finite(): return
	# Keep the loose plug in its own basin; bath chains cannot reach the floor.
	value.x=clampf(value.x,seat.x-.15,seat.x+.15)
	value.z=clampf(value.z,seat.z-.075,seat.z+.075)
	value.y=clampf(value.y,support(value),seat.y+.18)
	part.position=value
	falling_speed=0.0;resting=false
	update_seal()

func process(delta: float) -> void:
	if held or resting: return
	var floor_y:=support(part.position)
	falling_speed+=9.8*delta
	part.position.y=maxf(floor_y,part.position.y-falling_speed*delta)
	update_seal()
	if part.position.y<=floor_y+.00001:
		resting=true;falling_speed=0.0
		owner.manipulation_changed.emit()

func set_closed(closed: bool) -> void:
	if held: return
	write_position(seat if closed else parked)

func grip() -> Dictionary:
	return {"owner":owner,"part":part,"frame":owner,"kind":"free",
		"read":func(): return part.position,
		"write":func(value: Vector3):
			if held: write_position(value),
		"owns":func(): return held,
		"begin":func():
			if held or owner._held_valve!=-1: return false
			held=true;falling_speed=0.0
			return true,
		"end":func(): held=false;resting=false;owner.manipulation_changed.emit()}

func valid_position(value: Variant) -> bool:
	if value is not Array or value.size()!=3: return false
	for component: Variant in value:
		if typeof(component) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(component)): return false
	return absf(float(value[0])-seat.x)<=.15001 and absf(float(value[2])-seat.z)<=.07501 and float(value[1])>=seat.y-.00001 and float(value[1])<=seat.y+.18001

func restore(value: Array) -> void:
	if not valid_position(value): return
	held=false
	write_position(Vector3(float(value[0]),float(value[1]),float(value[2])))
