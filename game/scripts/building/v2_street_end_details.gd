extends ExteriorDetailPass
## V2 keeps the actual pavement works. Road-end weather cards, their framing
## gantries and their matching invisible road collision do not enter play.
func _build_street_ends(parent: Node3D,open_east_north: bool=false) -> void:
	var body:=StaticBody3D.new()
	body.name="StreetEndConstructionBoundary"
	body.collision_layer=1|STREET_END_PROBE_LAYER
	body.add_to_group("street_end_boundary")
	body.set_meta("visible_owner","construction_hoarding")
	parent.add_child(body)
	for side: Array in [["West",-20.10],["East",20.60]]:
		var label: String=side[0]
		var x: float=side[1]
		for walk: Array in [[-12.10,5.30,"north"],[-26.105,4.422,"south"]]:
			if open_east_north and label=="East" and walk[2]=="north":continue
			var center: float=walk[0]
			var depth: float=walk[1]
			_add_boundary_shape(body,label+str(walk[2]).capitalize()+"Works",[x,center,1.20],[.36,depth,2.40],"construction_hoarding")
			_box([x,center,1.20],[.36,depth,2.40],Color(.20,.145,.075))
			for i in 5:
				var along:=center-depth*.5+.24+(depth-.48)*float(i)/4.0
				_box([x-signf(x)*.22,along,1.30],[.10,.12,2.60],Color(.68,.43,.15))
			boundary_visible_spans.append({"side":label.to_lower(),"part":walk[2],"owner":"construction_hoarding","centre":center,"depth":depth})
	_build_street_end_hoarding_faces(parent,open_east_north)
	_build_street_end_marker_lamps(parent,open_east_north)
	boundary_count=body.get_child_count()
