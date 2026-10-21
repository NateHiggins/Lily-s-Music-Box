extends RefCounted
## Shared loaded-stock checks for the small bench and the actual composed world.
const Metrics=preload("res://tests/orison_v2_ceiling_top_closures_test.gd")
const Inventory=preload("res://tests/orison_v2_surface_inventory.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func inspect(root: Node3D,ground: Node3D,footings: Node3D) -> Dictionary:
	var metrics: Node=Metrics.new();var inventory: Node=Inventory.new()
	var model: Node3D=ground.get_child(0)
	var apron: Node3D=model.get_node("DistantApron")
	var manifests: Array=[]
	for spec: Array in [["ground",model,"res://tests/fixtures/orison_ground_construction.json","res://assets/props/orison_ground.glb"],["foundations",footings,"res://tests/fixtures/orison_city_foundations_construction.json","res://assets/props/city_foundations.glb"],["apron",apron,"res://tests/fixtures/orison_city_ground_apron.json","res://assets/props/city_ground_apron.glb"]]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(spec[2]))
		var parts:=0;var triangles:=0;var phase_valid:=true
		for draw: MeshInstance3D in (spec[1] as Node3D).find_children("*","MeshInstance3D",true,false):
			if str(spec[0])=="ground" and apron.is_ancestor_of(draw):continue
			parts+=1;triangles+=draw.mesh.get_faces().size()/3
			metrics._check_planar_mapping(draw.mesh,true)
			var mat: StandardMaterial3D=draw.material_override as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.normal_enabled,"mapped custom normal material: "+str(draw.name))
			if mat!=null:inventory._material(mat)
			if str(spec[0])!="apron":
				var box: AABB=draw.mesh.get_aabb()
				check(maxf(box.size.x,maxf(box.size.y,box.size.z))<=4.00001,"bounded local construction part: "+str(draw.name))
			if str(draw.name).contains("asphalt"):
				var pose: Transform3D=root.global_transform.affine_inverse()*draw.global_transform
				for surface in draw.mesh.get_surface_count():
					var arrays: Array=draw.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
					for index in vertices.size():
						if normals[index].y<.999:continue
						var p: Vector3=pose*vertices[index]
						var d:=Vector2(fposmod(uv[index].x-p.x,2.5),fposmod(uv[index].y-p.z,2.5))
						phase_valid=phase_valid and minf(d.x,2.5-d.x)<.00003 and minf(d.y,2.5-d.y)<.00003
		var expected_parts: int=data.boxes.size() if str(spec[0])=="apron" else data.parts.size()
		var expected_triangles: int=int(data.export_check.triangles) if str(spec[0])=="apron" else int(data.native_faces)*2
		var expected_sha: String=str(data.asset_sha256) if str(spec[0])=="apron" else str(data.source_native_sha256)
		check(parts==expected_parts and triangles==expected_triangles,"complete imported "+str(spec[0])+" stock")
		check(FileAccess.get_sha256(spec[3])==expected_sha,"exact installed "+str(spec[0])+" export")
		check(phase_valid,"registered 2.5 metre asphalt phase: "+str(spec[0]))
		if str(spec[0])=="apron":check(str(data.retained_ground_sha256)==FileAccess.get_sha256("res://assets/props/orison_ground.glb"),"apron binds the rebuilt retained ground")
		manifests.append({"family":spec[0],"parts":parts,"triangles":triangles,"asset_sha256":expected_sha,"phase_valid":phase_valid})
	for failure: String in metrics.failures:check(false,"imported mapping: "+failure)
	checks+=int(metrics.checks)
	for path: String in inventory.texture_rows:
		var row: Dictionary=inventory.texture_rows[path]
		var expected:=int(floor(log(float(maxi(int(row.width),int(row.height))))/log(2.)))
		check(row.mips and int(row.mip_levels)==expected,"full loaded mip chain: "+path)
	var report: Dictionary={"scope":"Three installed ground/foundation/apron assets only; no global qualification","checks":checks,"failures":failures,"families":manifests,"textures":inventory.texture_rows}
	metrics.free();inventory.free();return report
