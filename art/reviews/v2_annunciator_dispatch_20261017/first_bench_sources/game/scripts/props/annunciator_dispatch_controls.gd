extends Node3D
## Momentary mechanical keys. The existing passenger lift owns every journey.
const PATH := "res://data/orison_v2/annunciator_dispatch.json"
var board: OtisProp
var lift: OrisonElevator
var data: Dictionary
var buttons: Array[Node3D]=[]
var springs: Array[MeshInstance3D]=[]
var strokes: Array[float]=[]
var spent: Array[bool]=[]
var levels: Array=[]
var legends: Array[Label3D]=[]
var landing_labels: Array[Label3D]=[]
var held := -1
var _settling := false
var _materials: Dictionary={}

func configure(owner: OtisProp) -> bool:
	if board!=null or owner==null:return false
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version")!=1 or data.size()!=8:return false
	if data.get("centers") is not Array or data.centers.is_empty() or data.centers.size()>owner._lamps.size() or data.get("parts") is not Array:return false
	if not (float(data.travel)>0 and float(data.make)>0 and float(data.make)<=float(data.travel) and float(data.return_speed)>0 and float(data.spring_height)>float(data.travel)):return false
	board=owner
	var packed := load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model := packed.instantiate()
	var meshes: Dictionary={}
	for row: Dictionary in data.parts:
		var source := model.find_child(str(row.name),true,false) as MeshInstance3D
		if source==null:model.free();return false
		meshes[str(row.name)]={"mesh":source.mesh,"key":str(row.key),"normal_scale":float(row.normal_scale),"roughness":float(row.roughness)}
	model.free()
	for key in ["Apron","Guides","ContactBus","BusInsulators","ButtonStem","ButtonCap","ReturnSpring"]:
		if not meshes.has(key):return false
	for key in ["Apron","Guides","ContactBus","BusInsulators"]:_draw(key,meshes[key],self)
	for i in data.centers.size():
		var at: Array=data.centers[i]
		var button := Node3D.new();button.name="DispatchKey_"+str(i);button.position=Vector3(at[0],at[1],at[2]);add_child(button)
		_draw("ButtonStem",meshes.ButtonStem,button);_draw("ButtonCap",meshes.ButtonCap,button)
		buttons.append(button);strokes.append(0.);spent.append(false)
		var spring: MeshInstance3D=_draw("ReturnSpring",meshes.ReturnSpring,self)
		spring.position=button.position+Vector3(0,0,-.022);springs.append(spring)
		preload("res://scripts/props/manipulation_area.gd").install(button,grip.bind(i))
		var label := Label3D.new();label.name="DispatchLegend_"+str(i)
		label.font_size=48;label.pixel_size=.00013
		label.position=Vector3(at[0],at[1]-.011,.054);label.modulate=Color(.82,.77,.65);label.outline_size=0;add_child(label)
		legends.append(label)
		var landing := Label3D.new();landing.name="CarLanding_"+str(i)
		landing.font_size=48;landing.pixel_size=.00017;landing.outline_size=0;landing.modulate=label.modulate
		landing.position=Vector3(-.094,.235-(board._lamps.size()-1-i)*.063,.049);add_child(landing)
		landing_labels.append(landing)
	apply_pose();return true

func bind_lift(car: OrisonElevator) -> bool:
	if lift!=null or car==null or car.stop_order.size()!=buttons.size():return false
	lift=car;levels=car.stop_order.duplicate()
	for i in levels.size():
		buttons[i].name="DispatchKey_"+str(levels[i])
		legends[i].text=OrisonElevator.PLATE_LEGEND.get(levels[i],levels[i])
		landing_labels[i].text=legends[i].text
	for i in board._lamps.size()-levels.size():
		var spare := Label3D.new();spare.text="—";spare.font_size=48;spare.pixel_size=.00017;spare.outline_size=0
		spare.position=Vector3(-.094,.235-i*.063,.049);spare.modulate=Color(.82,.77,.65);add_child(spare)
	drive_indicators();return true

func _draw(label: String,spec: Dictionary,parent: Node3D) -> MeshInstance3D:
	var draw := MeshInstance3D.new();draw.name=label;draw.mesh=spec.mesh
	var key: String=spec.key
	if not _materials.has(key):
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;material.normal_scale=spec.normal_scale;material.roughness=spec.roughness;_materials[key]=material
	draw.material_override=_materials[key];draw.set_meta("material_key",key)
	draw.set_meta("native_annunciator_dispatch_part",label);parent.add_child(draw);return draw

func grip(i: int) -> Dictionary:
	if not is_instance_valid(lift):return {}
	return {"owner":board,"part":buttons[i],"frame":board,"kind":"slider","axis":Vector3.FORWARD,
		"minimum":0.,"maximum":float(data.travel),"read":func():return strokes[i],
		"begin":func():
			if held>=0 or board._native_service.held!=null or RealityState.save_write_blocked:return false
			held=i;return true,
		"owns":func():return held==i,
		"write":func(value: float):
			if held!=i:return
			strokes[i]=clampf(value,0,float(data.travel))
			if strokes[i]<=float(data.travel)*.1:spent[i]=false
			if strokes[i]>=float(data.make) and not spent[i]:
				spent[i]=true
				# Contact service owns circuit continuity; never repair it by dispatch.
				if not board.stuck_flag and absf(board.contact_alignment-board._native_service._contact_home)<=.07 and board.bank_reset==1.:
					lift.npc_request(str(levels[i]))
				if board._clack!=null:board._clack.play()
			apply_pose(),
		"end":func():held=-1;_settling=true;board.manipulation_changed.emit()}

func apply_pose() -> void:
	for i in buttons.size():
		buttons[i].position.z=float(data.centers[i][2])-strokes[i]
		springs[i].scale.z=1.-strokes[i]/float(data.spring_height)

func _physics_process(delta: float) -> void:
	var moving := false
	for i in strokes.size():
		if held==i:continue
		strokes[i]=move_toward(strokes[i],0.,float(data.return_speed)*delta)
		if strokes[i]<=float(data.travel)*.1:spent[i]=false
		moving=moving or strokes[i]>0.
	apply_pose()
	if _settling and not moving and held<0:_settling=false;board.manipulation_changed.emit()

func drive_indicators() -> void:
	if not is_instance_valid(lift) or lift._cabin==null:return
	var height: float=lift._cabin.position.y
	var weights: Array[float]=[];weights.resize(levels.size());weights.fill(0.)
	for i in levels.size():
		var y: float=lift.stops[levels[i]]
		if is_equal_approx(height,y):weights[i]=1.;break
		if i<levels.size()-1 and height>y and height<float(lift.stops[levels[i+1]]):
			var t: float=(height-y)/(float(lift.stops[levels[i+1]])-y)
			weights[i]=1.-t;weights[i+1]=t;break
	for lamp: StandardMaterial3D in board._lamps:
		lamp.albedo_color=Color(.30,.26,.16);lamp.emission_enabled=false;lamp.emission_energy_multiplier=0.
	for i in levels.size():
		var lamp: StandardMaterial3D=board._lamps[board._lamps.size()-1-i]
		lamp.albedo_color=Color(.30,.26,.16).lerp(Color(.95,.72,.34),weights[i])
		lamp.emission_enabled=weights[i]>0.;lamp.emission=Color(.95,.72,.34);lamp.emission_energy_multiplier=1.6*weights[i]

func snapshot() -> Dictionary:return {"strokes":strokes.duplicate(),"spent":spent.duplicate()}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2 or value.get("strokes") is not Array or value.get("spent") is not Array:return false
	if value.strokes.size()!=buttons.size() or value.spent.size()!=buttons.size():return false
	for i in buttons.size():
		var v: Variant=value.strokes[i]
		if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)) or v<0 or v>float(data.travel)+.000000001 or value.spent[i] is not bool:return false
		if v>=float(data.make) and not value.spent[i]:return false
	return true

func restore(value: Dictionary) -> void:
	held=-1;strokes.assign(value.strokes);spent.assign(value.spent)
	for i in strokes.size():strokes[i]=clampf(strokes[i],0.,float(data.travel))
	_settling=true;apply_pose()

func rest_snapshot() -> Dictionary:
	var values: Array[float]=strokes.duplicate();values.fill(0.)
	var done: Array[bool]=spent.duplicate();done.fill(false)
	return {"strokes":values,"spent":done}
