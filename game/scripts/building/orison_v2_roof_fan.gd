extends ExhaustFanProp
## Keep the production motor/cycle/refusal; bind sound to V2 register anchors.
var fabricated: Node3D

func _build_visual() -> void:
	super._build_visual()
	fabricated=(preload("res://assets/props/roof_ventilator.glb") as PackedScene).instantiate()
	var materials := {
		"Paint":smat("trim",_paint_tint()),
		"Iron":smat("cast_iron",Color(.38,.39,.37)),
		"Panel":smat("trim",_panel_tint()),
		"Brass":smat("brass_dull"),
		"Rubber":smat("rubber_aged",Color(.36,.34,.30)),
		"Rotor":smat("trim",_panel_tint()),
		"Shutter":smat("trim",_panel_tint())}
	get_node("StaticCarcass").hide()
	for pivot in [_rotor,_louver]:
		for old in pivot.get_children():
			if old is MeshInstance3D: old.hide()
	add_child(fabricated)
	for part in fabricated.get_children():
		if not part is MeshInstance3D: continue
		part.material_override=materials[str(part.name)]
		if part.name=="Rotor": part.reparent(_rotor,false)
		elif part.name=="Shutter": part.reparent(_louver,false)

func _build_duct_emitters() -> void:
	# The inherited V1 graph coordinates are not valid in the installed V2 frame.
	pass

func _build_primary_interaction() -> void:
	super._build_primary_interaction()
	get_node("BeltGuardInspection").position.z=-.18

func bind_registers(anchors: Array[Node3D]) -> void:
	for anchor: Node3D in anchors:
		var emitter:=make_emitter("hum_loop",-80.0,false)
		emitter.name="Duct_"+str(anchor.name)
		emitter.position=to_local(anchor.global_position)
		emitter.unit_size=1.6
		emitter.max_distance=6.5
		emitter.pitch_scale=_base_pitch()*.82
		_duct_emitters.append(emitter)
	var body:=StaticBody3D.new()
	body.name="PlantCollision"
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.72,.64,.72)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	collision.position.y=.32
	body.add_child(collision)
	add_child(body)
