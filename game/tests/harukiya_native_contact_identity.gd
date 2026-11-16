extends RefCounted
## Technical witness only: semantic source patch against actual loaded collision
## geometry. Never assume canonical glTF triangle IDs equal physics face_index.
const DATA := "res://tests/fixtures/harukiya_native_contact_patches.json"
var source: Dictionary = {}
func load_sources() -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary:return false
	source=decoded
	return FileAccess.get_sha256("res://assets/props/harukiya_drumkit.glb")==str(source.native_asset_sha256)

func match_hit(hit: Dictionary, contact: String) -> Dictionary:
	if hit.is_empty() or not source.get("contacts",{}).has(contact):return {}
	var collider:=hit.get("collider") as PhysicsBody3D
	if collider==null:return {}
	var draw:=collider.get_parent() as MeshInstance3D
	if draw==null:return {}
	var shapes:=collider.find_children("*","CollisionShape3D",true,false)
	if shapes.size()!=1:return {}
	var shape:=shapes[0] as CollisionShape3D
	if shape.shape is not ConcavePolygonShape3D:return {}
	var faces:PackedVector3Array=shape.shape.get_faces()
	var face:int=int(hit.get("face_index",-1))
	if face<0 or face*3+2>=faces.size():return {}
	var actual:Array[Vector3]=[]
	for i in range(3):actual.append(shape.global_transform*faces[face*3+i])
	var identity:String=str(draw.get_meta("harukiya_drum_part",""))
	for row:Dictionary in source.contacts[contact].faces:
		if identity!=str(row.node_name):continue
		var expected:Array[Vector3]=[]
		for p:Array in row.points_local:expected.append(draw.global_transform*Vector3(float(p[0]),float(p[1]),float(p[2])))
		if not _same_triangle(actual,expected):continue
		return {"contact":contact,"semantic_stock":source.contacts[contact].semantic_stock,
			"native_part":identity,"canonical_triangle":row.canonical_triangle,
			"loaded_collision_face":face,"actual_world_triangle":actual,
			"canonical_world_triangle":expected,"geometry_tolerance_m":.00001}
	return {}

func _same_triangle(a:Array[Vector3],b:Array[Vector3]) -> bool:
	# Rotation/winding changes do not change a triangle's physical surface.
	for order:Array in [[0,1,2],[1,2,0],[2,0,1],[0,2,1],[2,1,0],[1,0,2]]:
		if a[0].distance_to(b[order[0]])<=.00001 and a[1].distance_to(b[order[1]])<=.00001 and a[2].distance_to(b[order[2]])<=.00001:return true
	return false
