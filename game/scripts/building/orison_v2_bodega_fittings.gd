extends RefCounted
## Source-owned mesh nodes retain stock visibility, transforms and collision.
const ASSET := preload("res://assets/props/bodega_fittings.glb")
const FABRICATION := preload("res://scripts/generated/v2_bodega_fittings.gd")
const MAPPED := {
	"terrazzo":"terrazzo", "brick":"brick", "limestone":"concrete",
	"bodega_enamel":"enamel", "aged_green":"enamel", "cream_tile":"subway_tile",
	"oak_dark":"wood_dark", "iron":"iron_blackened", "shelf_steel":"zinc_liner",
	"cooler_enamel":"enamel_appliance", "crate_wood":"timber",
	"pavement_wet":"concrete", "paving_joint":"rubber_aged"}

static func mount(exterior: OrisonV2ExteriorCell, architecture: RefCounted) -> Node3D:
	var shop:=exterior.instance_node("SHOP_BODEGA")
	if shop==null:push_error("Bodega fittings: source shop missing");return null
	if FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH).replace("\r\n","\n").sha256_text()!=FABRICATION.SOURCE_GEOMETRY_SHA256_LF:push_error("Bodega fittings: source template digest changed");return null
	var native:=ASSET.instantiate() as Node3D
	var owner:=Node3D.new();owner.name="FittedRetailFabric";shop.add_child(owner)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH))
	var template: Dictionary={}
	for row: Dictionary in source.templates:
		if row.id=="TEMPLATE_BODEGA_CELL_V1":template=row
	var records: Dictionary={}
	for row: Dictionary in template.boxes:records[str(row.id)]=row
	var retained: Dictionary={}
	for identity: String in FABRICATION.REPLACE_IDS:
		var row: Dictionary=records[identity]
		var draw:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,identity)
		var replacement:=native.get_node_or_null(identity) as MeshInstance3D
		if draw==null or replacement==null or draw.position.distance_to(Vector3(row.position_m[0],row.position_m[1],row.position_m[2]))>.000001 or draw.mesh.get_aabb().size.distance_to(Vector3(row.size_m[0],row.size_m[1],row.size_m[2]))>.000001:
			push_error("Bodega fittings: invalid source/native binding: "+identity+" source="+str(draw)+" native="+str(replacement))
			native.free();owner.free();return null
		for surface in replacement.mesh.get_surface_count():
			if not MatLib.SETS.has(replacement.mesh.surface_get_material(surface).resource_name):
				push_error("Bodega fittings: unknown native material: "+replacement.mesh.surface_get_material(surface).resource_name)
				native.free();owner.free();return null
		retained[identity]={"mesh":draw.mesh,"transform":draw.transform,"material":draw.material_override,"role":draw.get_meta("presentation_role"),"visible":draw.visible}
	for identity: String in FABRICATION.REPLACE_IDS:
		var draw:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,identity)
		var replacement:=native.get_node(identity) as MeshInstance3D
		draw.mesh=replacement.mesh
		draw.material_override=null
		for surface in draw.mesh.get_surface_count():
			var key: String=draw.mesh.surface_get_material(surface).resource_name
			if not MatLib.SETS.has(key):native.free();owner.free();return null
			var mat:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/float(MatLib.SETS[key][3])
			mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false
			var old: Material=retained[identity].material
			if (identity=="cooler_inner_glow" or (identity.begins_with("ceiling_practical_") and key=="milk_glass")) and old is StandardMaterial3D:
				mat.emission_enabled=old.emission_enabled;mat.emission=old.emission;mat.emission_energy_multiplier=old.emission_energy_multiplier
			draw.set_surface_override_material(surface,mat)
	# Architectural planar stocks keep their exact primitive geometry. Finish
	# them locally with existing catalogue maps and their physical tile scales.
	for identity: String in records:
		if retained.has(identity):continue
		var row: Dictionary=records[identity]
		var draw:=preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop,identity)
		if draw==null:continue
		if str(row.material_id) in ["glass","cooler_glass"]:
			draw.material_override=architecture.material_for("Glazing","public")
		elif MAPPED.has(str(row.material_id)):
			var mat:=MatLib.get_mat(str(MAPPED[str(row.material_id)])).duplicate() as StandardMaterial3D
			mat.uv1_triplanar=true
			if str(row.material_id) in ["bodega_enamel","aged_green"]:
				var tint: Array=[]
				for spec: Dictionary in source.materials:
					if str(spec.id)==str(row.material_id):tint=spec.albedo_rgba
				mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			draw.material_override=mat
	owner.set_meta("retained",retained)
	var collision_fabric: Array[Dictionary]=[]
	for shape: CollisionShape3D in shop.get_node("Collision").get_children():
		collision_fabric.append({"node":shape,"transform":shape.transform,"size":shape.shape.size,"disabled":shape.disabled})
	owner.set_meta("retained_collision",collision_fabric)
	owner.set_meta("source_geometry_sha256_lf",FABRICATION.SOURCE_GEOMETRY_SHA256_LF)
	native.free()
	return owner
