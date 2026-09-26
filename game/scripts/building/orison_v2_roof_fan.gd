extends ExhaustFanProp
## Keep the production motor/cycle/refusal; bind sound to V2 register anchors.

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
