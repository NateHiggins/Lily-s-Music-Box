extends TapProp
## 4B's native vessel. TapProp remains the water/boiler and valve authority.
const CurtainMotion=preload("res://scripts/props/clawfoot_curtain_motion.gd")
const Cloth=preload("res://shaders/clawfoot_curtain.gdshader")
const Target=preload("res://scripts/props/manipulation_area.gd")
const Controls=preload("res://scripts/building/orison_v2_water_controls.gd")
const FINISHES={"Tub_enamel":"porcelain_fixture","Tub_iron":"enamel_appliance",
	"Tub_nickel":"nickel_plated","Tub_brass":"brass_dull","Tub_cloth":"shower_duck"}
var native_ready:=false
var model:Node3D
var cloth_material:ShaderMaterial
var diverter:Node3D
var diverter_rest:=Vector3.ZERO
var shower_fraction:=1.0
var filler:Node3D
var chain:MultiMesh
var last_chain_position:=Vector3.INF
var plug_seat:=Vector3.ZERO
var plug_parked:=Vector3.ZERO

class BathBody extends Controls.FixtureBody:
	var bath:Node3D
	func step_height_for(player:Node3D,motion:Vector3) -> float:
		# Only the open front of this vessel offers a step-over. The player
		# still tests the entire upward and forward capsule against the world.
		if not bath.is_curtain_open():return .30
		var at:Vector3=bath.model.to_local(player.global_position)
		var direction:Vector3=bath.model.global_basis.inverse()*motion
		if absf(at.x)>.42 or at.z< -1.10 or at.z>.16 or absf(direction.z)<.0001:return .30
		return clampf(.64-at.y,.30,.64)

class SnapPlug extends RefCounted:
	var owner:Node3D
	var part:Node3D
	var seat:Vector3
	var parked:Vector3
	var committed:Vector3
	var held:=false
	func _init(fixture:Node3D,plug:Node3D,drain:Vector3,rest:Vector3) -> void:
		owner=fixture;part=plug;seat=drain;parked=rest;committed=rest
		Target.install(part,grip);_snap(rest)
	func process(_delta:float) -> void:pass
	func _snap(at:Vector3) -> void:
		part.position=at;committed=at;owner._stopper=at.is_equal_approx(seat)
	func set_closed(closed:bool) -> void:
		if not held:_snap(seat if closed else parked)
	func valid_position(value:Variant) -> bool:
		if value is not Array or value.size()!=3:return false
		for component:Variant in value:
			if typeof(component) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(component)):return false
		var at:=Vector3(float(value[0]),float(value[1]),float(value[2]))
		return at.distance_to(seat)<.00001 or at.distance_to(parked)<.00001
	func restore(value:Array) -> void:
		if not valid_position(value):return
		held=false
		var at:=Vector3(float(value[0]),float(value[1]),float(value[2]))
		_snap(seat if at.distance_to(seat)<at.distance_to(parked) else parked)
	func grip() -> Dictionary:
		return {"owner":owner,"part":part,"frame":part.get_parent(),"kind":"free","pickup":false,
			"read":func():return part.position,
			"write":func(value:Vector3):
				if not held or not value.is_finite():return
				part.position=Vector3(clampf(value.x,seat.x-.15,seat.x+.15),clampf(value.y,seat.y,seat.y+.18),clampf(value.z,seat.z-.10,seat.z+.10))
				owner._stopper=false,
			"owns":func():return held,
			"begin":func():
				if held or owner._held_valve!=-1 or owner._curtain_hand.held:return false
				held=true;return true,
			"end":func():
				held=false;_snap(seat if part.position.distance_to(seat)<part.position.distance_to(parked) else parked)
				owner.manipulation_changed.emit()}

func _build_visual() -> void:
	model=load("res://assets/props/clawfoot_bath.glb").instantiate() as Node3D
	model.name="StaticFixture";add_child(model)
	var datum:=model.find_child("SemanticShowerAnchor",true,false) as Node3D
	model.position=-datum.position
	for draw:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var source:=draw.mesh.surface_get_material(surface)
			if source==null or not FINISHES.has(str(source.resource_name)):
				push_error("Clawfoot bath refuses an unregistered finish");return
			var slot:=str(source.resource_name)
			var material:=MatLib.get_mat(FINISHES[slot]).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;material.normal_scale=.08
			if slot=="Tub_iron":
				material.albedo_color=Color(.21,.29,.25);material.metallic=0;material.roughness=.78
			if slot=="Tub_cloth":
				cloth_material=ShaderMaterial.new();cloth_material.shader=Cloth
				cloth_material.set_shader_parameter("albedo_tex",material.albedo_texture)
				cloth_material.set_shader_parameter("rough_tex",material.roughness_texture)
				cloth_material.set_shader_parameter("normal_tex",material.normal_texture)
				draw.set_surface_override_material(surface,cloth_material)
			else:draw.set_surface_override_material(surface,material)
	for label:String in ["HotValve","ColdValve"]:
		_handles.append(model.find_child(label,true,false) as Node3D)
		_handle_turns.append(0.0);_handle_wall_mounted.append(true)
	_curtain_closed=model.find_child("CurtainDrawn",true,false) as Node3D
	_curtain_area=Area3D.new();_curtain_area.name="CurtainInteraction"
	_curtain_area.set_meta("shower_curtain",true);model.add_child(_curtain_area)
	_bath_plug=model.find_child("BathPlug",true,false) as Node3D
	plug_parked=_bath_plug.position
	plug_seat=(model.find_child("DrainOpening",true,false) as Node3D).position+Vector3.UP*.004
	diverter=model.find_child("BathShowerDiverter",true,false) as Node3D
	diverter_rest=diverter.position
	_stream=_make_stream(_datum("SprayOrigin"),1.7,.017)
	filler=_make_stream(_datum("BathFillerMouth"),.52,.012);filler.name="BathFillerStream"
	_water_empty_y=_datum("BasinWaterEmpty").y;_water_full_y=_datum("BasinWaterFull").y
	_basin_water=_make_water_surface(Vector3(model.position.x,_water_empty_y,model.position.z),Vector2(1.40,.62),true)
	_water=make_emitter("shower_water",-21.0,true)
	if _water:_water.stream_paused=true
	_tick=make_emitter("tick",-27.0)
	native_ready=true

func _datum(label:String) -> Vector3:
	return model.position+(model.find_child(label,true,false) as Node3D).position

func _build_primary_interaction() -> void:
	if not native_ready:return
	var cloth:=model.find_child("TubMesh__CurtainDrawn",true,false) as MeshInstance3D
	var ring_template:=model.find_child("CurtainRingTemplate",true,false) as MeshInstance3D
	_curtain_hand=CurtainMotion.new(self,model,cloth,cloth_material,ring_template)
	_plug_hand=SnapPlug.new(self,_bath_plug,plug_seat,plug_parked)
	for index in 2:Target.install(_handles[index],func():return valve_grip(index))
	Target.install(diverter,diverter_grip)
	var template:=model.find_child("StopperChainTemplate",true,false) as MeshInstance3D
	template.visible=false;chain=MultiMesh.new();chain.transform_format=MultiMesh.TRANSFORM_3D
	chain.mesh=template.mesh;chain.instance_count=64
	var draw:=MultiMeshInstance3D.new();draw.name="StopperChain";draw.multimesh=chain
	draw.material_override=template.get_surface_override_material(0);model.add_child(draw)
	set_curtain_open(warehouse_curtain_open);set_shower_fraction(1.0);_update_bath_plug(0)

func mount_fixture_collision() -> bool:
	if not native_ready or get_node_or_null("FixtureBody")!=null:return false
	var draw:=model.find_child("TubMesh__TubFixed",true,false) as MeshInstance3D
	var faces:=PackedVector3Array()
	var pose:=global_transform.affine_inverse()*draw.global_transform
	for surface in draw.mesh.get_surface_count():
		if str(draw.mesh.surface_get_material(surface).resource_name) not in ["Tub_iron","Tub_enamel"]:continue
		var arrays:=draw.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for index in indices:faces.append(pose*vertices[index])
	if faces.is_empty():return false
	var body:=BathBody.new();body.bath=self;body.name="FixtureBody"
	var shape:=CollisionShape3D.new();var hull:=ConcavePolygonShape3D.new()
	hull.set_faces(faces);shape.shape=hull;body.add_child(shape);add_child(body)
	return true

func diverter_grip() -> Dictionary:
	return {"owner":self,"part":diverter,"frame":model,"kind":"slide",
		"axis":Vector3.FORWARD,"minimum":0.0,"maximum":.012,"gesture_travel_px":180.0,
		"read":func():return shower_fraction*.012,
		"write":func(value:float):
			if _held_valve==2:set_shower_fraction(value/.012),
		"owns":func():return _held_valve==2,
		"begin":func():
			if _held_valve!=-1 or _curtain_hand.held or _plug_hand.held:return false
			_held_valve=2;return true,
		"end":func():
			_held_valve=-1;set_shower_fraction(1.0 if shower_fraction>=.5 else 0.0);manipulation_changed.emit()}

func set_shower_fraction(value:float) -> void:
	if not is_finite(value):return
	shower_fraction=clampf(value,0,1)
	diverter.position=diverter_rest+Vector3.FORWARD*shower_fraction*.012
	_update_flow()

func spray_flow_amount() -> float:
	return float(super.get_flow_state().flow)*shower_fraction

func _update_flow() -> void:
	super._update_flow()
	if not native_ready:return
	_stream.visible=spray_flow_amount()>.0001
	filler.visible=float(super.get_flow_state().flow)*(1.0-shower_fraction)>.0001

func _update_bath_plug(_delta:float) -> void:
	if chain==null or _bath_plug.position.is_equal_approx(last_chain_position):return
	last_chain_position=_bath_plug.position
	var start:=_bath_plug.position+Vector3.UP*.010
	var finish:=Vector3(-.727,.51,0)
	for i in chain.instance_count:
		var a:=float(i)/chain.instance_count;var b:=float(i+1)/chain.instance_count
		var p:=start.lerp(finish,a)-Vector3.UP*sin(a*PI)*.045
		var q:=start.lerp(finish,b)-Vector3.UP*sin(b*PI)*.045
		var y:=(p-q).normalized();var x:=Vector3.RIGHT-y*y.x
		if x.length_squared()<.001:x=Vector3.FORWARD-y*Vector3.FORWARD.dot(y)
		x=x.normalized()
		chain.set_instance_transform(i,Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(1,p.distance_to(q)/.006,1)),p))

func _process(delta:float) -> void:
	super._process(delta)
	if not native_ready:return
	if filler.visible:
		var drop:=maxf(.005,filler.position.y-lerpf(_water_empty_y,_water_full_y,_water_level))
		var column:=filler.get_child(0) as MeshInstance3D
		(column.mesh as CylinderMesh).height=drop;column.position.y=-drop*.5

func mechanism_snapshot() -> Dictionary:
	var at:Vector3=_plug_hand.committed
	return {"hot":_valve_openings.x,"cold":_valve_openings.y,"curtain":_curtain_hand.travel,
		"plug":[at.x,at.y,at.z],"water":_water_level,"diverter":shower_fraction}

static func _number(value:Variant,maximum:float=1.0) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and float(value)>=0 and float(value)<=maximum

func valid_mechanism(value:Variant) -> bool:
	if value is not Dictionary:return false
	var keys:Array=value.keys();keys.sort()
	if keys not in [["cold","hot"],["cold","curtain","hot"],["cold","curtain","diverter","hot","plug","water"]]:return false
	if not _number(value.hot) or not _number(value.cold):return false
	if value.has("curtain") and not _number(value.curtain,CurtainMotion.TRAVEL):return false
	if value.size()==6:
		if not _number(value.water) or not _number(value.diverter) or not _plug_hand.valid_position(value.plug):return false
	return true

func restore_mechanism(value:Dictionary) -> void:
	if not valid_mechanism(value):return
	_held_valve=-1;_curtain_hand.held=false;_plug_hand.held=false
	_curtain_hand.set_travel(float(value.get("curtain",0.0)))
	if value.has("plug"):_plug_hand.restore(value.plug)
	else:_plug_hand.set_closed(false)
	_water_level=float(value.get("water",0.0));set_shower_fraction(float(value.get("diverter",1.0)))
	set_valve_opening(0,float(value.hot));set_valve_opening(1,float(value.cold))
	for index in 2:_handle_turns[index]=_valve_openings[index]
	_update_bath_plug(0)
