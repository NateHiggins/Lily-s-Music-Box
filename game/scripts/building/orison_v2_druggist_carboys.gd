extends RefCounted
## Original hero identities; clear shells retain source maps and stoppers use opal glass.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
const OpticalReceivers := preload("res://scripts/lamp/lamp_optical_receivers.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	if not Seating.mount_druggist_carboys(cell,layout):return false
	var model: Node3D=cell.get_node("DruggistCarboys")
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for("Glazing","public") as ShaderMaterial
	if glass==null or glass.shader.resource_path!="res://shaders/lamp_glass_surface.gdshader":return false
	glass.set_shader_parameter("surface_roughness",.06)
	var count:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_carboys_part",""))
		if not part.ends_with("__glassish_shell"):continue
		if draw.mesh.get_surface_count()!=1 or draw.mesh.surface_get_material(0) is not StandardMaterial3D:return false
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		draw.set_meta("glazing_optical_owner","res://scripts/building/orison_v2_architectural_materials.gd")
		draw.material_override=glass
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The existing lamp owner binds and releases this surface automatically.
		# Twelve millimetres matches the shell wall.
		var haze:=OpticalReceivers.add_glass_haze(draw)
		var haze_material:=haze.material_override as ShaderMaterial
		haze_material.set_shader_parameter("thickness_m",.012)
		count+=1
	model.set_meta("optical_material",glass)
	if count!=4:return false
	return _light_show_globes(model)

## The show globes burn as a druggist's window always did: a lamp behind each
## coloured fill throws its colour through the shopfront onto the terrazzo.
## The carboy glass casts no shadow, so the colour comes from these tinted
## spots; the fill itself glows by an emissive override, leaving the shipping
## mesh material untouched.
const GLOBE_TARGET_X := 15.4 # aisle terrazzo, about 1.5 m out from the glass
static func _light_show_globes(model: Node3D) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/druggist_carboys.json"))
	if data is not Dictionary:return false
	var tints: Dictionary={}
	for row: Dictionary in data.cells[0].parts:
		if row.has("tint") and str(row.name).contains("__fill"):tints[str(row.name)]=row.tint
	var lit:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_carboys_part",""))
		if not tints.has(part):continue
		var t: Array=tints[part]
		var tint:=Color(float(t[0]),float(t[1]),float(t[2]))
		var peak:=maxf(tint.r,maxf(tint.g,tint.b))
		var hue:=Color(tint.r/peak,tint.g/peak,tint.b/peak)
		var pose:=draw.transform
		var parent:=draw.get_parent()
		while parent!=model:
			pose=(parent as Node3D).transform*pose;parent=parent.get_parent()
		var centre:=pose*draw.get_aabb().get_center()
		var glow:=(draw.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		glow.emission_enabled=true;glow.emission=hue;glow.emission_energy_multiplier=1.4
		draw.material_override=glow
		var lamp:=SpotLight3D.new()
		lamp.name="ShowGlobeLight%d"%lit
		lamp.light_color=hue;lamp.light_energy=3.2;lamp.spot_range=5.5;lamp.spot_angle=28.;lamp.spot_attenuation=.8
		lamp.shadow_enabled=false
		var target:=Vector3(GLOBE_TARGET_X,0.,centre.z)
		lamp.transform=Transform3D(Basis.looking_at(target-centre,Vector3.UP),centre)
		lamp.set_meta("druggist_show_globe",part)
		model.add_child(lamp)
		lit+=1
	model.set_meta("show_globe_lights",lit)
	return lit==4
