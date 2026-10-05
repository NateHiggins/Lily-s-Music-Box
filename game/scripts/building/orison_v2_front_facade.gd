extends RefCounted
## Source-fitted exterior dress. No new layout, service, key or save authority.
const ASSET:=preload("res://assets/props/front_facade.glb")
const EntryDoor:=preload("res://scripts/props/orison_v2_entry_door.gd")
const Marquee:=preload("res://scripts/props/orison_v2_marquee_dress.gd")
static func mount(world: Node3D) -> bool:
	var root: Node3D=world.adapter.root
	var anchor:=world.adapter.resolve("F01_DOOR_06") as Node3D
	if anchor==null or anchor.get_node_or_null("Hinge")==null:return false
	var record: Dictionary={}
	for row: Dictionary in world.layout.doors:
		if row.id=="F01_DOOR_06":record=row
	if record.is_empty() or record.hinge!="left" or record.swing!="out":return false
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var markers: Dictionary={}
	for floor: Dictionary in source.floors:
		if floor.id!="F01":continue
		for marker: Dictionary in floor.markers:
			if marker.id in ["F01_DOOR_06","F01_NEON_BLADE"]:markers[marker.id]=marker
	if markers.size()!=2:return false
	var model:=ASSET.instantiate() as Node3D;model.name="FrontFacade"
	var movable:=model.get_node("EntryLeaf") as Node3D;movable.owner=null
	for node: Node in movable.find_children("*","",true,false):node.owner=null
	model.remove_child(movable)
	var reach: float=root.layout.dimensions.outer_wall-root.layout.dimensions.partition_wall*.5
	model.position=anchor.position+Vector3(0,0,-reach);model.rotation.y=PI;root.add_child(model)
	var legacy: Node3D=(preload("res://assets/building/floor_01.gltf") as PackedScene).instantiate()
	var stone: StandardMaterial3D
	for draw: MeshInstance3D in legacy.find_children("*","MeshInstance3D",true,false):
		for i in draw.mesh.get_surface_count():
			var original:=draw.mesh.surface_get_material(i)
			if original is StandardMaterial3D and original.resource_name=="M_limestone_b":stone=original.duplicate()
	legacy.free()
	if stone==null:movable.free();return false
	stone.uv1_triplanar=false;stone.uv1_scale=Vector3.ONE/SurfacePass.TILE_M.limestone
	var materials: Dictionary={"limestone_b":stone}
	var glass:=ShaderMaterial.new();glass.shader=preload("res://shaders/lamp_glass_surface.gdshader");materials.glass=glass
	for branch: Node3D in [model,movable]:
		for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			var key:=str(draw.name).split("__")[1]
			if not materials.has(key):
				var tint: Color={"oak_quartered":Color(.30,.22,.15),"cast_iron":Color(.12,.13,.12),"metal":Color(.24,.25,.23),"brass":Color(.72,.63,.46)}.get(key,Color.WHITE)
				var material:=MatLib.get_mat(key,tint).duplicate() as StandardMaterial3D
				if key=="oak_quartered":material.normal_scale=.18
				material.uv1_triplanar=false;materials[key]=material
			draw.material_override=materials[key];draw.set_meta("facade_material_key",key)
			if branch==movable:continue
			var body:=StaticBody3D.new();body.name="FacadeCollision"
			var collision:=CollisionShape3D.new();collision.shape=draw.mesh.create_trimesh_shape()
			draw.add_child(body);body.add_child(collision)
	var placeholder:=anchor.get_node("Hinge");anchor.remove_child(placeholder);placeholder.free()
	for part: String in ["FrameLeft","FrameRight","FrameHead"]:anchor.get_node(part).hide()
	var door:=EntryDoor.new();door.name="F01_DOOR_06_Leaf";door.native_leaf=movable
	door.width=float(record.width);door.height=float(record.height);door.door_kind=str(markers.F01_DOOR_06.subtype)
	door.leaf_state=str(markers.F01_DOOR_06.leaf);door.swing_out=false
	door.position=Vector3(-door.width*.5,0,-reach-.035)
	door.set_meta("semantic_id","F01_DOOR_06");anchor.add_child(door)
	var dress:=Marquee.new();model.add_child(dress)
	var plaque:=BuildingEntrySign.new();plaque.position=Vector3(.79,1.58,.032)
	# The narrow fitted pier receives the original plaque through a smaller
	# supported face, keeping it clear of both the leaf and broad stone pilaster.
	plaque.scale=Vector3.ONE*.60;model.add_child(plaque)
	var title:=Label3D.new();title.text="THE ORISON  ·  1928";title.font_size=26;title.pixel_size=.00115
	title.position=Vector3(0,door.height+.15,.058);title.modulate=Color(.73,.50,.20);model.add_child(title)
	var blade:=NeonSignProp.new();var marker: Dictionary=markers.F01_NEON_BLADE
	blade.name=str(marker.id);blade.prop_type="neon_sign";blade.sign_text=str(marker.text);blade.vertical=bool(marker.vertical)
	blade.tint=Color(marker.tint[0],marker.tint[1],marker.tint[2])
	if float(marker.pos[0])<=0:return false
	var seats: Array[Vector2]=[]
	for level: String in ["F02","F03"]:
		var front:=INF;var pier:=-INF
		for space: Dictionary in world.layout.spaces:
			if space.level!=level or space.get("open_shell",false) or not "south" in space.get("wall_sides",["south","north","west","east"]):continue
			if float(space.rect[2])>=-door.width*.5 or float(space.rect[1])>float(record.center[1]):continue
			if float(space.rect[2])>pier:pier=float(space.rect[2]);front=float(space.rect[1])-reach
		if is_inf(front):return false
		seats.append(Vector2(pier-.25,front))
	if not seats[0].is_equal_approx(seats[1]):return false
	blade.position=Vector3(seats[0].x,float(marker.pos[2]),seats[0].y);blade.rotation.y=PI
	blade.graph_node_id=str(marker.id);root.add_child(blade)
	if not world.adapter.install_acoustic_overrides([str(marker.id)]):return false
	# Retire only the composed proxy; standalone exterior fixtures remain intact.
	var street: Node3D=world.exterior_cell.instance_node("STREET_ORISON_01")
	for child: Node in street.get_children():
		if str(child.get_meta("authored_record_id","")) in ["orison_portal_left","orison_portal_right","orison_portal_head",
				"orison_canopy","orison_canopy_underlight","orison_canopy_tie_left","orison_canopy_tie_right",
				"orison_name","orison_address","orison_sconce_left","orison_sconce_right","orison_canopy_pool","orison_facade_wash"]:
			street.remove_child(child);child.free()
	print("[V2 FRONT FACADE] native entrance, original landmark hardware, glazed marquee and fitted blade")
	return true
