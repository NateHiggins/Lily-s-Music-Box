extends Node
## Source discovery only, never production or acceptance evidence.
func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	var station := FireLineCabinetProp.new()
	station.prop_type = "fire_line_cabinet"
	add_child(station)
	await get_tree().process_frame
	await get_tree().process_frame
	var parts: Array = []
	for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false):
		var shape := draw.mesh
		var mat := draw.get_active_material(0) as StandardMaterial3D
		var row := {"index":parts.size(),"name":str(draw.name),"path":str(station.get_path_to(draw)),"type":shape.get_class(),"position":[draw.position.x,draw.position.y,draw.position.z],"rotation":[draw.rotation.x,draw.rotation.y,draw.rotation.z],"color":[mat.albedo_color.r,mat.albedo_color.g,mat.albedo_color.b,mat.albedo_color.a]}
		row.pose_position=[draw.global_position.x,draw.global_position.y,draw.global_position.z]
		row.pose_basis=[[draw.global_basis.x.x,draw.global_basis.x.y,draw.global_basis.x.z],[draw.global_basis.y.x,draw.global_basis.y.y,draw.global_basis.y.z],[draw.global_basis.z.x,draw.global_basis.z.y,draw.global_basis.z.z]]
		if shape is BoxMesh: row.size=[shape.size.x,shape.size.y,shape.size.z]
		elif shape is CylinderMesh: row.radius=shape.bottom_radius;row.top=shape.top_radius;row.height=shape.height
		elif shape is TorusMesh: row.inner=shape.inner_radius;row.outer=shape.outer_radius
		else: push_error("Unclassified fire stock");get_tree().quit(1);return
		parts.append(row)
	if parts.is_empty(): push_error("Fire source has no built stock");get_tree().quit(1);return
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("source_plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated source shape discovery; no production, route or maintenance acceptance.","source_sha256":FileAccess.get_file_as_string(station.get_script().resource_path).replace("\r\n","\n").sha256_text(),"parts":parts},"\t"))
	station.free()
	print("FIRE SOURCE: ",parts.size()," stock partitions captured")
	get_tree().quit(0)
