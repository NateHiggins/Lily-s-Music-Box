extends "res://scripts/building/orison_v2_arcade_shop_door.gd"
## Two native leaves on the original bodega's one passage and lock owner.

func motion_leaves() -> Array[Dictionary]:
	return [{"body":_body,"width":width*.5,"ratio":1.0},
		{"body":_right_body,"width":width*.5,"ratio":-1.0}]

func passage_swing_radius() -> float:
	return width*.5

func lock_x() -> float:
	return width*.5-.085

func _build_leaf() -> void:
	assert(not swing_out and is_equal_approx(width,2.1) and is_equal_approx(height,2.1))
	_hinge_offset = HINGE_SETBACK
	_body = AnimatableBody3D.new()
	_body.name = "HingedLeaf"
	_right_body = AnimatableBody3D.new()
	_right_body.name = "HingedLeafRight"
	for leaf: Dictionary in motion_leaves():
		var body: AnimatableBody3D = leaf.body
		var sign_x: float = leaf.ratio
		if sign_x < 0.0: body.position.x = width
		body.position.z = -_hinge_offset
		body.sync_to_physics = true
		add_child(body)
		var edge := width*.5-.01
		_collision(body,{"name":"Core","low":[minf(.01*sign_x,edge*sign_x),.02,-.022],
			"high":[maxf(.01*sign_x,edge*sign_x),height-.01,.022]})
		var pull := width*.5-.075
		for face in [-1.0,1.0]:
			_collision(body,{"name":"PullBack" if face < 0.0 else "PullFront",
				"low":[pull*sign_x-.035,.93,minf(.012*face,.059*face)],
				"high":[pull*sign_x+.035,1.38,maxf(.012*face,.059*face)]})
