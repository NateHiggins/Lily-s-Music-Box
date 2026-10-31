extends Node3D
## Presentation only. The command and borrowed sky clock supply every date.
const State := preload("res://scripts/game/prologue_state.gd")
const ASSET := "res://assets/props/companion_time_register.glb"
const OPEN_START := 1.0
const OPEN_END := 68.0 / 24.0
const CLOSE_START := 164.0 / 24.0
const CLOSE_END := 208.0 / 24.0
const FINISHES := {
	"fire_hardware_steel": [.128, .22, .8],
	"brass_dull": [.5, .2, .85],
	"porcelain_fixture": [.4, .1, .7],
	"bakelite_black": [.3, .16, .85],
	"glass_drawn_expressive": [.128, .025, .25],
	"milk_glass": [.128, .1, .3],
	"fabric_warm": [.48, .2, .85],
}
const AMBER := "res://data/device/companion_temporal_amber.json"
const SEGMENTS := [63,6,91,79,102,109,125,7,127,111]
var led: ShaderMaterial
var digit_masks:=PackedInt32Array()
var mask_updates:=0
var row_values: Array[String]=["","",""]
var _profile:Dictionary
var _mechanism:Node3D
var _door_mount:Node3D
var native: Node3D
var hinge: Node3D
var animator: AnimationPlayer
var clip: StringName
var labels: Dictionary = {}
var phase := "idle"
var opening := 0.0
var _owner: WeakRef
var _carrier: Node
var _target: Dictionary = {}
var capacitor: ShaderMaterial
var emission_counts := PackedInt32Array([0, 0, 0, 0])

func configure(mechanism: Node3D, carrier: Node = null) -> bool:
	_carrier = carrier;_mechanism=mechanism
	_profile=JSON.parse_string(FileAccess.get_file_as_string(AMBER))
	if _profile.get("id","")!="companion_temporal_amber.v1":return false
	digit_masks.resize(36);digit_masks.fill(0)
	var packed := load(ASSET) as PackedScene
	if packed == null: return false
	native = packed.instantiate(); add_child(native)
	var mount := native.find_child("TemporalAccessoryMount", true, false)
	if mount == null or not is_equal_approx(float(mount.get_meta("extras", {}).get("baked_reference_scale", 0)), .42): return false
	scale = Vector3.ONE / .42
	var materials := {}
	for key: String in FINISHES:
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		if key == "glass_drawn_expressive": material = preload("res://scripts/building/orison_v2_expressive_glass.gd").make(key)
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(FINISHES[key][0])
		material.normal_scale = FINISHES[key][1]
		material.roughness = FINISHES[key][2]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if key == "bakelite_black": material.albedo_color = Color(.035, .045, .04)
		materials[key] = material
	var count := 0
	var draws:=native.find_children("*", "MeshInstance3D", true, false)
	draws.sort_custom(func(a:Node,b:Node)->bool:return str(a.name)<str(b.name))
	# Capacitor__porcelain sorts ahead of DoorRegisterMount__milk_glass.
	for draw: MeshInstance3D in draws:
		var key := str(draw.get_meta("extras", {}).get("material_key", ""))
		if not materials.has(key): push_error("Temporal finish missing: "+str(draw.name)+" key="+key);return false
		draw.layers = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for surface in draw.mesh.get_surface_count(): draw.set_surface_override_material(surface, materials[key])
		if key == "porcelain_fixture" and not _bind_capacitor(draw, materials[key]):push_error("Temporal native capacitor tag binding refused");return false
		if key == "milk_glass" and not _bind_led(draw,materials[key]):push_error("Temporal native LED tag binding refused");return false
		if str(draw.name)=="DoorRegisterMount__glass_drawn_expressive":
			var pane:=materials[key].duplicate() as StandardMaterial3D
			var tint:Array=_profile.readout_glass_tint_linear_rgb
			pane.albedo_color=Color(tint[0],tint[1],tint[2],pane.albedo_color.a)
			draw.set_surface_override_material(0,pane)
		count += 1
	if count != 14 or led==null or capacitor==null:push_error("Temporal stock count "+str(count));return false
	_door_mount=native.find_child("DoorRegisterMount",true,false)
	if _door_mount==null:push_error("Temporal door mount missing");return false
	hinge = native.find_child("RegisterHinge", true, false)
	var players := native.find_children("*", "AnimationPlayer", true, false)
	if hinge == null or players.size() != 1:push_error("Temporal animation owner missing");return false
	animator = players[0]
	for name: StringName in animator.get_animation_list():
		if str(name).ends_with("RegisterHingeAction"): clip = name
	if clip.is_empty():push_error("Temporal animation clip missing");return false
	animator.play(clip); animator.pause()
	for row: String in ["Departure", "Passing", "Destination"]:
		var anchor := native.find_child("Readout_" + row, true, false) as Node3D
		if anchor == null:push_error("Temporal readout anchor missing "+row);return false
		var label := Label3D.new()
		label.name = "Temporal" + row
		label.font = TelegramStyle.BODY_FONT; label.font_size = 48
		label.pixel_size = .000090 if row == "Passing" else .000070
		# The fixed front panel now faces Godot +Z. Labels only identify rows;
		# dates illuminate native segments, never a second overlaid date string.
		label.position=Vector3(-.0128,0,.000074)
		label.pixel_size=.000022 if row=="Passing" else .000016
		label.modulate=Color("ffa52f")
		label.outline_size = 0; label.no_depth_test = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.layers = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
		anchor.add_child(label); labels[row] = label
		label.text={"Departure":"DEP","Passing":"NOW","Destination":"DST"}[row]
		if row=="Departure":
			var status:=label.duplicate() as Label3D
			status.name="DepartureUnknown";status.text="UNKNOWN";status.position=Vector3(.0031,0,.000074)
			anchor.add_child(status);labels.Unknown=status
	_set_opening(0)
	set_process(false)
	return mechanism != null

## Actual exported composed sweep: garage motion plus safe-stow reveal.
func envelope_in_rig() -> AABB:
	var low:=Vector3(-.039650001,-.067900008,-.051969846)/.42
	var high:=Vector3(.067731307,.033900001,.088665153)/.42
	return AABB(low,high-low)

## Keep the animated native hierarchy intact. Arm animation and manual bench
## seeks call this directly, including while the world is cinematically paused.
func follow_door() -> void:
	if _door_mount==null or _mechanism.typing_arm==null:return
	var hatch:Node3D=_mechanism.typing_arm.native.find_child("Arm_Hatch",true,false)
	if hatch!=null:_door_mount.global_transform=hatch.global_transform*Transform3D(Basis.IDENTITY,Vector3(.0082,-.0146,.00095))

func safe_to_reveal() -> bool:
	return not _mechanism.keyboard_requested and _mechanism.keyboard_open<=.001 and (_mechanism.typing_arm==null or (not _mechanism.typing_arm.active() and _mechanism.typing_arm.case_time<=.00001))

func begin(owner: Node, destination: Dictionary) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or not State.valid_target(destination): return false
	if get_tree().paused or not safe_to_reveal() or (_carrier != null and not _carrier.device.radio_powered): return false
	if _owner != null and is_instance_valid(_owner.get_ref()) and _owner.get_ref() != owner: return false
	_owner = weakref(owner); _target = State.annual_destination(destination)
	_set_charge(1)
	_set_row(0,"") # Never turn a staged death time into an invented date.
	_set_row(1,"")
	_set_row(2,_date(float(_target.utc_unix_seconds),int(_target.local_bias_minutes)))
	phase = "opening"; set_process(true)
	return true

func sample_clock(owner: Node, utc_seconds: float) -> void:
	if _owner == null or _owner.get_ref() != owner or not is_finite(utc_seconds): return
	# The sky's existing UTC projection is EST in the authored year. Never
	# resample OS time or turn this presentation into a campaign clock writer.
	_set_row(1,_date(utc_seconds,-300))

func _set_row(row:int,text:String) -> void:
	if row_values[row]==text:return
	row_values[row]=text
	mask_updates+=1
	var digits:=text.replace("/","").replace(" ","").replace(".","")
	for index in 12:
		digit_masks[row*12+index]=SEGMENTS[int(digits[index])] if digits.length()==12 else 0
	led.set_shader_parameter("digit_masks",digit_masks)
	led.set_shader_parameter("row_valid",Vector3(0.0 if row_values[0].is_empty() else 1.0,0.0 if row_values[1].is_empty() else 1.0,0.0 if row_values[2].is_empty() else 1.0))

func _set_charge(value:float) -> void:
	capacitor.set_shader_parameter("capacitor_charge",value)
	led.set_shader_parameter("capacitor_charge",value)

func release(owner: Node, immediate := false) -> void:
	if _owner == null or _owner.get_ref() != owner: return
	_owner = null; _target.clear()
	_set_charge(0)
	phase = "closing"
	if immediate: _settle()
	else: set_process(true)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused: return
	if _owner != null and (not is_instance_valid(_owner.get_ref()) or (_carrier != null and not _carrier.device.radio_powered)):
		_owner = null; _target.clear(); phase = "closing"
		_set_charge(0)
	if phase == "opening":
		_set_opening(minf(1, opening + delta / (OPEN_END - OPEN_START)))
		if opening >= 1: phase = "open"
	elif phase == "closing":
		_set_opening(maxf(0, opening - delta / (CLOSE_END - CLOSE_START)))
		if opening <= 0: _settle()

func _set_opening(value: float) -> void:
	opening = clampf(value, 0, 1)
	var sample := lerpf(CLOSE_END, CLOSE_START, opening) if phase == "closing" else lerpf(OPEN_START, OPEN_END, opening)
	animator.seek(sample, true)
	# Imported animation optimization slightly rounds held key rotations. The
	# measured absolute mechanical stops remain exact; do not accumulate them.
	if opening == 0: hinge.basis = Basis.IDENTITY
	elif opening == 1: hinge.basis = Basis(Vector3.RIGHT, deg_to_rad(-100))
	follow_door()
	for label: Label3D in labels.values(): label.visible = opening > .98 and led.get_shader_parameter("capacitor_charge")>0

func _settle() -> void:
	_set_opening(0); phase = "idle"; set_process(false)

static func _date(seconds: float, bias: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(seconds) + bias * 60)
	return "%02d/%02d/%04d %02d.%02d" % [date.month, date.day, date.year, date.hour, date.minute]

func _bind_capacitor(draw: MeshInstance3D, source: StandardMaterial3D) -> bool:
	# Godot ignores arbitrary glTF vertex semantics. Read the immutable native
	# tags once, matching positions rather than assuming importer vertex order.
	# Never edit the generated GLB, shared mesh, UVs, normals or tangents.
	var bytes := FileAccess.get_file_as_bytes(ASSET)
	if bytes.size() < 28 or bytes.decode_u32(0) != 0x46546c67: return false
	var json_length := bytes.decode_u32(12)
	var data: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	var binary := bytes.slice(28 + json_length)
	var attributes: Dictionary = {}
	for node: Dictionary in data.nodes:
		if str(node.get("name", "")) == str(draw.name):
			attributes = data.meshes[int(node.mesh)].primitives[0].attributes
	if not attributes.has("_EMISSION_REGION"): return false
	var points := _accessor(data, binary, int(attributes.POSITION), 3)
	var regions := _accessor(data, binary, int(attributes._EMISSION_REGION), 1)
	if points.size() != regions.size() * 3: return false
	var tags := {}
	for index in regions.size():
		var region := int(regions[index])
		if region < 0 or region > 3: return false
		var point := Vector3(points[index * 3], points[index * 3 + 1], points[index * 3 + 2])
		var key := Vector3i((point * 10000000).round())
		if tags.has(key) and int(tags[key]) != region: return false
		tags[key] = region
	var arrays := draw.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray(); colors.resize(vertices.size())
	for index in vertices.size():
		var key := Vector3i((vertices[index] * 10000000).round())
		if not tags.has(key): return false
		var region := int(tags[key])
		emission_counts[region] += 1
		colors[index] = Color(float(region) / 3.0, 0, 0, 1)
	for region in 4:
		if emission_counts[region] == 0: return false
	arrays[Mesh.ARRAY_COLOR] = colors
	var local_mesh := ArrayMesh.new()
	local_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw.mesh = local_mesh
	capacitor = ShaderMaterial.new(); capacitor.shader = preload("res://shaders/companion_capacitor.gdshader")
	capacitor.resource_name = "porcelain_fixture"
	capacitor.set_shader_parameter("albedo_tex", source.albedo_texture)
	capacitor.set_shader_parameter("rough_tex", source.roughness_texture)
	capacitor.set_shader_parameter("normal_tex", source.normal_texture)
	capacitor.set_shader_parameter("mesh_uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	capacitor.set_shader_parameter("normal_scale", source.normal_scale)
	capacitor.set_shader_parameter("roughness_mul", source.roughness)
	capacitor.set_shader_parameter("metallic", source.metallic)
	capacitor.set_shader_parameter("amber_linear",Vector3(_profile.color_linear_rgb[0],_profile.color_linear_rgb[1],_profile.color_linear_rgb[2]))
	capacitor.set_shader_parameter("emission_strength",_profile.capacitor_strength)
	draw.set_surface_override_material(0, capacitor)
	return true

func _bind_led(draw:MeshInstance3D,source:StandardMaterial3D) -> bool:
	var bytes:=FileAccess.get_file_as_bytes(ASSET)
	var length:=bytes.decode_u32(12)
	var data:Dictionary=JSON.parse_string(bytes.slice(20,20+length).get_string_from_utf8())
	var binary:=bytes.slice(28+length)
	var attrs:Dictionary={}
	for node:Dictionary in data.nodes:
		if str(node.get("name",""))==str(draw.name):attrs=data.meshes[int(node.mesh)].primitives[0].attributes
	for key:String in ["POSITION","_LED_ROW","_LED_DIGIT","_LED_SEGMENT","_LED_ELEMENT"]:
		if not attrs.has(key):return false
	var points:=_accessor(data,binary,int(attrs.POSITION),3)
	var rows:=_accessor(data,binary,int(attrs._LED_ROW),1)
	var digits:=_accessor(data,binary,int(attrs._LED_DIGIT),1)
	var segments:=_accessor(data,binary,int(attrs._LED_SEGMENT),1)
	var elements:=_accessor(data,binary,int(attrs._LED_ELEMENT),1)
	if points.size()!=rows.size()*3 or digits.size()!=rows.size() or segments.size()!=rows.size() or elements.size()!=rows.size():return false
	var seen:Dictionary={}
	for element in elements:
		if int(element)<0 or int(element)>=264:return false
		seen[int(element)]=true
	if seen.size()!=264:return false
	# Adjacent glass segments share corner positions. A position-only tag map
	# cannot distinguish them, and importer welding can merge identical corners.
	# Match whole triangles, then split those imported corners once. Physical
	# positions/normals/UVs/tangents and winding remain the loaded source values.
	var source_indices:=_indices(data,binary,int(data.meshes[int(_mesh_index(data,str(draw.name)))].primitives[0].indices))
	var faces:Dictionary={}
	for face in range(0,source_indices.size(),3):
		var ids:PackedInt32Array=source_indices.slice(face,face+3)
		var a:=ids[0];var row:=int(rows[a]);var digit:=int(digits[a]);var segment:=int(segments[a])
		if row<0 or row>2 or digit< -1 or digit>11 or segment<0 or segment>8:return false
		for corner in ids:
			if rows[corner]!=rows[a] or digits[corner]!=digits[a] or segments[corner]!=segments[a]:return false
		var vertices: Array[Vector3]=[]
		for corner in ids:vertices.append(Vector3(points[corner*3],points[corner*3+1],points[corner*3+2]))
		var key:=_triangle_key(vertices[0],vertices[1],vertices[2])
		var tag:=Color(float(row)/2.0,float(digit+1)/12.0,float(segment)/8.0,1)
		if faces.has(key) and faces[key]!=tag:return false
		faces[key]=tag
	var arrays:=draw.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var tan:=PackedFloat32Array();var colors:=PackedColorArray()
	for face in range(0,indices.size(),3):
		var key:=_triangle_key(vertices[indices[face]],vertices[indices[face+1]],vertices[indices[face+2]])
		if not faces.has(key):return false
		for corner in 3:
			var i:=indices[face+corner]
			v.append(vertices[i]);n.append(normals[i]);uv.append(uvs[i]);colors.append(faces[key])
			for axis in 4:tan.append(tangents[i*4+axis])
	arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_NORMAL]=n;arrays[Mesh.ARRAY_TANGENT]=tan;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;var sequential:=PackedInt32Array();sequential.resize(v.size())
	for i in v.size():sequential[i]=i
	arrays[Mesh.ARRAY_INDEX]=sequential
	var local_mesh:=ArrayMesh.new();local_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);draw.mesh=local_mesh
	led=capacitor.duplicate() as ShaderMaterial
	led.resource_name="milk_glass"
	led.set_shader_parameter("albedo_tex",source.albedo_texture)
	led.set_shader_parameter("rough_tex",source.roughness_texture)
	led.set_shader_parameter("normal_tex",source.normal_texture)
	led.set_shader_parameter("mesh_uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y))
	led.set_shader_parameter("normal_scale",source.normal_scale)
	led.set_shader_parameter("roughness_mul",source.roughness)
	led.set_shader_parameter("metallic",source.metallic)
	led.set_shader_parameter("segmented_display",true)
	led.set_shader_parameter("digit_masks",digit_masks)
	led.set_shader_parameter("row_valid",Vector3.ZERO)
	led.set_shader_parameter("emission_strength",_profile.led_strength)
	led.set_shader_parameter("off_lens_tint",Vector3(_profile.off_lens_tint_linear_rgb[0],_profile.off_lens_tint_linear_rgb[1],_profile.off_lens_tint_linear_rgb[2]))
	draw.set_surface_override_material(0,led)
	return true

static func _mesh_index(data:Dictionary,name:String) -> int:
	for node:Dictionary in data.nodes:
		if str(node.get("name",""))==name:return int(node.mesh)
	return -1

static func _triangle_key(a:Vector3,b:Vector3,c:Vector3) -> String:
	var keys:Array[String]=[str(Vector3i((a*10000000).round())),str(Vector3i((b*10000000).round())),str(Vector3i((c*10000000).round()))]
	keys.sort()
	return "|".join(keys)

static func _indices(data:Dictionary,binary:PackedByteArray,index:int) -> PackedInt32Array:
	var spec:Dictionary=data.accessors[index];var view:Dictionary=data.bufferViews[int(spec.bufferView)]
	var width:=2 if int(spec.componentType)==5123 else 4
	if int(spec.componentType) not in [5123,5125] or spec.has("sparse"):return PackedInt32Array()
	var offset:=int(view.get("byteOffset",0))+int(spec.get("byteOffset",0))
	var out:=PackedInt32Array()
	for i in int(spec.count):out.append(binary.decode_u16(offset+i*width) if width==2 else binary.decode_u32(offset+i*width))
	return out

static func _accessor(data: Dictionary, binary: PackedByteArray, index: int, components: int) -> PackedFloat32Array:
	var spec: Dictionary = data.accessors[index]
	if int(spec.componentType) != 5126 or spec.has("sparse"): return PackedFloat32Array()
	var view: Dictionary = data.bufferViews[int(spec.bufferView)]
	var stride := int(view.get("byteStride", components * 4))
	var offset := int(view.get("byteOffset", 0)) + int(spec.get("byteOffset", 0))
	var count := int(spec.count)
	if offset + (count - 1) * stride + components * 4 > binary.size(): return PackedFloat32Array()
	var values := PackedFloat32Array(); values.resize(count * components)
	for vertex in count:
		for axis in components: values[vertex * components + axis] = binary.decode_float(offset + vertex * stride + axis * 4)
	return values
