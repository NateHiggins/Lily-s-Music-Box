extends Node
## INERT source-geometry and chart contract, without a composed world boot.
var failures := 0
var checks := 0

func _ready() -> void:
	var exterior := OrisonV2ExteriorCell.new()
	var size := Vector3(.16,3.2,10.42)
	var origin := Vector3(2.2,1.6,-5.27)
	var blank := BoxMesh.new();blank.size=size
	var charted := exterior._box_mesh(size,origin)
	_check(charted==exterior._box_mesh(size,origin),"identical stock and installation phase share their mesh")
	var shifted := exterior._box_mesh(size,origin+Vector3.UP*.4)
	_check(charted!=shifted,"a different installation phase owns a different UV chart")
	var source := blank.surface_get_arrays(0)
	var arrays := charted.surface_get_arrays(0)
	for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_INDEX]:
		_check(source[channel]==arrays[channel],"charting preserves non-UV source buffer: "+str(channel))
	_check(_metric(charted),"asymmetric wall's UV edge lengths equal physical edge lengths")
	_check(not _metric(blank),"raw normalized box atlas fails the same physical scale check")
	_check(_metric(shifted),"installation phase retains exact physical density")
	var next := exterior._box_mesh(size,origin+Vector3.UP*size.y)
	var next_arrays := next.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var later_points: PackedVector3Array=next_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var later_uv: PackedVector2Array=next_arrays[Mesh.ARRAY_TEX_UV]
	var joins := 0
	for i in points.size():
		for j in later_points.size():
			if absf(normals[i].y)>.01 or not normals[i].is_equal_approx(normals[j]):continue
			if (points[i]+origin).distance_to(later_points[j]+origin+Vector3.UP*size.y)<.00001:
				joins+=1;_check(uv[i].distance_to(later_uv[j])<.00001,"adjacent vertical wall stocks meet at one grout phase")
	_check(joins>0,"shared-phase control actually samples adjoining faces")
	_check(OrisonV2ExteriorCell.SURFACE_STOCK.cream_tile=="bath_wall_tile"
		and preload("res://scripts/building/orison_v2_bodega_fittings.gd").MAPPED.cream_tile=="bath_wall_tile","construction and final fittings agree on the custom periodic glaze")
	for key: String in OrisonV2ExteriorCell.SURFACE_STOCK.values():
		_check(MatLib.SETS.has(key),"every exterior alias resolves to registered runtime PBR stock: "+key)
	_partition(exterior)
	exterior.free()
	print("STREET UV BENCH: %s; %d checks; %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _metric(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else points.size()
	if count==0 or count%3!=0:return false
	for index in range(0,count,3):
		for edge in 3:
			var a: int=indices[index+edge] if not indices.is_empty() else index+edge
			var b: int=indices[index+(edge+1)%3] if not indices.is_empty() else index+(edge+1)%3
			var distance := points[a].distance_to(points[b])
			if absf(uv[a].distance_to(uv[b])-distance)>maxf(.000002,distance*.00001):return false
	return true

func _partition(exterior: OrisonV2ExteriorCell) -> void:
	var cell := Node3D.new()
	var wall := MeshInstance3D.new();wall.set_meta("authored_record_id","back_wall_right")
	wall.position=Vector3(0,1.6,0);wall.mesh=exterior._box_mesh(Vector3(1.025,3.2,.16),wall.position);cell.add_child(wall)
	var body := StaticBody3D.new();body.name="Collision";cell.add_child(body)
	var shape := CollisionShape3D.new();shape.position=wall.position;shape.set_meta("authored_record_id","back_wall_right")
	var solid := BoxShape3D.new();solid.size=Vector3(1.025,3.2,.16);shape.shape=solid;body.add_child(shape)
	var power := preload("res://scripts/building/orison_v2_bodega_power.gd").new();power._cell=cell
	var good := wall.mesh
	var arrays := good.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];points[0]+=Vector3(.01,0,0);arrays[Mesh.ARRAY_VERTEX]=points
	var damaged := ArrayMesh.new();damaged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);wall.mesh=damaged
	_check(not power._cut_partition(Vector3(0,1.8,0)),"partition rejects distorted triangles even with the original bounds")
	wall.mesh=good;solid.size.x+=.02
	_check(not power._cut_partition(Vector3(0,1.8,0)),"partition rejects a visual/collision mismatch")
	solid.size.x-=.02
	_check(power._cut_partition(Vector3(0,1.8,0)),"original collision authority accepts an exactly equivalent metre-charted solid")
	_check(_metric(wall.mesh),"sleeve cut pieces retain physical density and common grout phase")
	power.free();cell.free()

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("STREET UV CHECK: ",label," = ",ok)
