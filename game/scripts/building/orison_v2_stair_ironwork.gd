extends RefCounted
## Blender dressing and semantic guard barriers. Steps and ramps remain owned
## by the blockout; collision is never inferred from imported visual triangles.
const PUBLIC := preload("res://assets/props/stair_ironwork_public.glb")
const SERVICE := preload("res://assets/props/stair_ironwork_service.glb")

func mount(parent: Node3D, stair: Dictionary, base_y: float) -> bool:
	var public := is_equal_approx(float(stair.width),1.2)
	var width := 1.2 if public else 1.05
	if not is_equal_approx(float(stair.width),width) \
		or not is_equal_approx(float(stair.tread),.285 if public else .275) \
		or not is_equal_approx(float(stair.landing_depth),width) \
		or not is_equal_approx(float(stair.rise),.16) or int(stair.risers_per_flight)!=10 \
		or not is_equal_approx(float(stair.gap),.3) or not is_equal_approx(float(stair.guard_height),.91):
		return false
	var model := (PUBLIC if public else SERVICE).instantiate() as Node3D
	model.name = "Ironwork"
	parent.add_child(model)
	model.position = Vector3(float(stair.origin[0]),base_y,float(stair.origin[1]))
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var source := part.mesh.surface_get_material(surface)
			part.set_surface_override_material(surface,MatLib.get_mat(source.resource_name))
	_mount_guards(parent,model.position,stair)
	return true

func _mount_guards(parent: Node3D, origin: Vector3, stair: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "StairGuards"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.position = origin
	var width := float(stair.width)
	var tread := float(stair.tread)
	var rise := float(stair.rise)
	var count := int(stair.risers_per_flight)
	var run := tread*count
	var half := rise*count
	var landing := float(stair.landing_depth)
	var gap := float(stair.gap)
	var height := float(stair.guard_height)-.025
	var right := width*2+gap-.025
	var rear := run+landing+.7-.025
	for returning in [false,true]:
		var low_z := run+landing-tread*.5 if returning else tread*.5
		var high_z := run+landing-tread*(count-.5) if returning else tread*(count-.5)
		var low_y := half+rise if returning else rise
		var high_y := half*2 if returning else half
		var outer := right if returning else .025
		var inner := width+gap+.025 if returning else width-.025
		for x in [outer,inner]:
			_guard(body,Vector3(x,low_y,low_z),Vector3(x,high_y,high_z),height)
		var end_z := low_z if returning else high_z
		var end_y := low_y if returning else high_y
		_guard(body,Vector3(outer,end_y,end_z),Vector3(outer,half,rear),height)
		if not returning:
			_guard(body,Vector3(inner,end_y,end_z),Vector3(inner,half,run),height)
	_guard(body,Vector3(.025,half,rear),Vector3(right,half,rear),height)

func _guard(body: StaticBody3D, a: Vector3, b: Vector3, height: float) -> void:
	var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()*.0225
	var points := PackedVector3Array()
	for end in [a,b]:
		for side in [-1.0,1.0]:
			points.append(end+normal*side-Vector3.UP*.02)
			points.append(end+normal*side+Vector3.UP*height)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
