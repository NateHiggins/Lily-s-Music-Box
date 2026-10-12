extends RefCounted
## Deform the authored curtain along its existing U rail; keep its UVs/materials.
const LENGTH := 1.96
const TRAVEL := 1.78
var owner: Node3D
var cloth: Node3D
var area: Area3D
var hand: Node3D
var held := false
var travel := 0.0
var hand_u := .5
var hand_y := 1.2
var draws: Array[Dictionary] = []
var prepared := false

func _init(fixture: Node3D) -> void:
	owner=fixture;cloth=owner._curtain_closed;area=owner._curtain_area
	# Ray selection needs a layer, not overlap monitoring against solid bowls.
	area.monitoring=false;area.monitorable=false;area.collision_mask=0
	hand=Node3D.new();hand.name="CurtainHandContact";owner.add_child(hand)
	for draw: MeshInstance3D in cloth.find_children("*","MeshInstance3D",true,false):
		var pose: Transform3D=owner.global_transform.affine_inverse()*draw.global_transform
		var surfaces: Array[Dictionary]=[]
		var rings: bool=(pose*draw.get_aabb()).position.y>1.9
		for surface in draw.mesh.get_surface_count():
			var arrays:=draw.mesh.surface_get_arrays(surface)
			var source: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var coordinates: Array[Vector3]=[]
			for vertex: Vector3 in source:
				var at: Vector3=pose*vertex
				var distance:=rail_distance(at)
				if rings: distance=roundf(distance/(LENGTH/18.0))*(LENGTH/18.0)
				coordinates.append(Vector3(distance,at.y,0))
			surfaces.append({"arrays":arrays,"coordinates":coordinates,"material":draw.get_active_material(surface)})
		draws.append({"draw":draw,"pose":pose,"surfaces":surfaces,"rings":rings})
	for child in area.get_children(): child.free()
	owner._curtain_gathered.visible=false
	_update_hand()

static func rail_point(distance: float) -> Vector3:
	if distance<.64: return Vector3(-.34,0,.32-distance)
	if distance<1.32: return Vector3(-.34+distance-.64,0,-.32)
	return Vector3(.34,0,-.32+distance-1.32)

static func rail_axis(distance: float) -> Vector3:
	if distance<.64: return Vector3.FORWARD
	if distance<1.32: return Vector3.RIGHT
	return Vector3.BACK

static func rail_distance(at: Vector3) -> float:
	var candidates: Array[float]=[clampf(.32-at.z,0,.64),clampf(at.x+.34,0,.68)+.64,clampf(at.z+.32,0,.64)+1.32]
	var best:=0.0;var nearest:=INF
	for distance in candidates:
		var point:=rail_point(distance)
		var error:=Vector2(point.x-at.x,point.z-at.z).length_squared()
		if error<nearest: nearest=error;best=distance
	return best

func mapped(distance: float) -> float:
	return travel+distance/LENGTH*(LENGTH-travel)

func set_travel(value: float) -> void:
	if not is_finite(value): return
	if prepared and is_equal_approx(clampf(value,0,TRAVEL),travel): return
	prepared=true
	travel=clampf(value,0,TRAVEL)
	cloth.visible=true
	owner._curtain_gathered.visible=false
	owner._curtain_is_open=travel>TRAVEL*.8
	for child in area.get_children(): child.free()
	for record: Dictionary in draws:
		var result:=ArrayMesh.new()
		var pose: Transform3D=record.pose
		var inverse_pose:=pose.affine_inverse()
		for surface: Dictionary in record.surfaces:
			var arrays: Array=surface.arrays.duplicate(true)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var original: Vector3=pose*vertices[i]
				var distance: float=surface.coordinates[i].x
				var offset: Vector3=original-rail_point(distance)
				var old_axis:=rail_axis(distance)
				var new_distance:=mapped(distance)
				var new_axis:=rail_axis(new_distance)
				var old_normal:=Vector3(-old_axis.z,0,old_axis.x)
				var new_normal:=Vector3(-new_axis.z,0,new_axis.x)
				var depth: float=offset.dot(old_normal)
				if not record.rings: depth*=lerpf(1.0,1.8,travel/TRAVEL)
				var at:=rail_point(new_distance)+new_normal*depth+Vector3.UP*original.y
				if record.rings: at+=new_axis*offset.dot(old_axis)
				vertices[i]=inverse_pose*at
			arrays[Mesh.ARRAY_VERTEX]=vertices
			var source_mesh:=ArrayMesh.new();source_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var rebuild:=SurfaceTool.new();rebuild.create_from(source_mesh,0)
			rebuild.generate_normals()
			if arrays[Mesh.ARRAY_TEX_UV]!=null: rebuild.generate_tangents()
			rebuild.set_material(surface.material);rebuild.commit(result)
		var draw: MeshInstance3D=record.draw
		draw.mesh=result
		var shape:=CollisionShape3D.new();shape.shape=result.create_trimesh_shape()
		area.add_child(shape);shape.global_transform=draw.global_transform
	_update_hand()

func _update_hand() -> void:
	hand.position=rail_point(mapped(hand_u*LENGTH))+Vector3.UP*hand_y

func grip(at: Vector3) -> Dictionary:
	var local: Vector3=owner.to_local(at)
	var fraction:=clampf((rail_distance(local)-travel)/maxf(.18,LENGTH-travel),0,1)
	return {"owner":owner,"part":hand,"frame":owner,"kind":"slide",
		"axis":func(): return rail_axis(mapped(hand_u*LENGTH)),
		"minimum":0.0,"maximum":TRAVEL,
		"read":func(): return travel,
		"write":func(value: float):
			if held: set_travel(value),
		"owns":func(): return held,
		"begin":func():
			if held or owner._held_valve!=-1: return false
			held=true;hand_u=fraction;hand_y=local.y;_update_hand()
			return true,
		"end":func(): held=false;owner.manipulation_changed.emit()}
