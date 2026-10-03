extends "res://tests/orison_v2_light_court_skylight_test.gd"
## Installed cover contacts, open outlet, native fall and flashing pockets.
var weather_native := PackedVector3Array()

func _init() -> void: route_label = "ROOF PUBLIC WEATHERING"

func _route() -> void:
	await super._route()
	if not failures.is_empty():return
	var root: Node3D=world.adapter.root
	var model: Node3D=root.get_node("RoofPublicWeathering")
	var sky: Node3D=root.get_node("LightCourtSkylight")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_public_weathering.json"))
	var bodies: Array[RID]=[player.get_rid()]
	var space:=world.get_world_3d().direct_space_state
	var parts:=0;var triangles:=0
	for body: StaticBody3D in model.find_children("*","StaticBody3D",true,false):bodies.append(body.get_rid())
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var key: String=draw.get_meta("material_key")
		_require(draw.material_override==MatLib.get_mat(key),"public roof uses actual mapped material "+key)
		_check_planar_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bound: AABB=pose*draw.mesh.get_aabb()
		_require(maxf(maxf(bound.size.x,bound.size.y),bound.size.z)<4.00001,"public weather uses bounded native partitions")
		weather_native.append_array(pose*draw.mesh.get_faces())
	_require(parts==int(fixture.parts) and triangles==int(fixture.native_triangles),"public weather matches native build inventory")
	var roof_contacts:=0;var valley_contacts:=0;var grooves:=0
	for x: float in [-1.8,0,1.8,2.95,4.4,5.3]:
		for z: float in [-3.5,-2.5,-1.65,-.8,.3,2.7,3.5]:
			if _inside_rect(Vector2(x,z),fixture.curb_outer_rect) or _inside_rect(Vector2(x,z),fixture.cricket_rect):continue
			var y: float=fixture.retained_cap_top+fixture.bearing_toe+fixture.roof_fall*(fixture.cap_outer_rect[2]-x)+fixture.sheet_thickness
			var at:=Vector3(x,y,z)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.05),root.to_global(at-Vector3.UP*.12),1,[player.get_rid()]))
			_require(not hit.is_empty() and hit.collider.get_parent()==model and root.to_local(hit.position).distance_to(at)<.00005,"real public weather field contact "+str(Vector2(x,z)))
			hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.05),root.to_global(at-Vector3.UP*.12),1,bodies))
			_require(not hit.is_empty() and "RoofBulkheadCaps" in str(hit.collider.get_path()) and absf(root.to_local(hit.position).y-fixture.retained_cap_top)<.00005,"weather retains original public cap below its bearing")
			roof_contacts+=1
	for facet: Dictionary in fixture.cricket_facets:
		var centre:=Vector3.ZERO
		for p: Array in facet.points:centre+=Vector3(p[0],p[1],p[2])/3
		var native_hit:=_weather_hit(centre+Vector3.UP*.05,centre-Vector3.UP*.05)
		_require(not native_hit.is_empty(),"native cricket facet exists "+facet.id)
		if native_hit.is_empty():continue
		var normal: Vector3=native_hit.normal
		var gradient:=Vector2(-normal.x/normal.y,-normal.z/normal.y)
		if "SouthCricket"==str(facet.id):_require(gradient.y>.025,"actual south cricket sends runoff toward south valley")
		elif "NorthCricket"==str(facet.id):_require(gradient.y<-.025,"actual north cricket sends runoff toward north valley")
		else:_require(absf(gradient.x+float(fixture.roof_fall))<.0001 and absf(gradient.y)<.0001,"actual outer filler retains original downhill fall")
	var cr: Array=fixture.cricket_rect
	var mid: float=(cr[1]+cr[3])*.5
	for end_z: float in [cr[1],cr[3]]:
		var last:=INF
		for fraction: float in [.1,.2,.3,.4,.5,.6,.7,.8,.9]:
			var x:=lerpf(cr[0],cr[2],fraction);var z:=lerpf(mid,end_z,fraction)
			var base_y: float=fixture.retained_cap_top+fixture.bearing_toe+fixture.roof_fall*(fixture.cap_outer_rect[2]-x)+fixture.sheet_thickness
			var at:=Vector3(x,base_y,z)
			var native_hit:=_weather_hit(at+Vector3.UP*.04,at-Vector3.UP*.04)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.04),root.to_global(at-Vector3.UP*.04),1,[player.get_rid()]))
			_require(not native_hit.is_empty() and absf(native_hit.position.y-base_y)<.00005,"native valley has a flush falling surface")
			_require(not hit.is_empty() and hit.collider.get_parent()==model and absf(root.to_local(hit.position).y-base_y)<.00005,"physics valley follows native skin")
			if not native_hit.is_empty():
				_require(native_hit.position.y<last-.0001,"actual valley descends toward curb corner")
				last=native_hit.position.y
			valley_contacts+=1
	var sky_native:=PackedVector3Array()
	for draw: MeshInstance3D in sky.find_children("*","MeshInstance3D",true,false):sky_native.append_array((root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces())
	for point: Vector3 in [Vector3(2.3694,22.681,-1.075),Vector3(3.5306,22.681,-1.075),Vector3(2.95,22.681,-1.9806),Vector3(2.95,22.681,-.1694)]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(point),root.to_global(point+Vector3.UP*.01),1,bodies))
		_require(not hit.is_empty() and "CurbCap" in str(hit.collider.get_parent().name) and absf(root.to_local(hit.position).y-22.684)<.00005,"actual underside pocket has 4mm depth")
		_require(_native_segment_hits(sky_native,point,point+Vector3.UP*.004),"native cap recess accompanies physical flashing pocket")
		grooves+=1
	for edge: Dictionary in [
		{"a":Vector3(2.3668,22.66,-1.075),"b":Vector3(2.372,22.66,-1.075),"from":2.3688,"to":2.37,"axis":0},
		{"a":Vector3(3.527,22.66,-1.075),"b":Vector3(3.534,22.66,-1.075),"from":3.53,"to":3.5312,"axis":0},
		{"a":Vector3(2.95,22.66,-1.984),"b":Vector3(2.95,22.66,-1.977),"from":-1.9812,"to":-1.98,"axis":2},
		{"a":Vector3(2.95,22.66,-.173),"b":Vector3(2.95,22.66,-.166),"from":-.17,"to":-.1688,"axis":2}]:
		var near:=_weather_hit(edge.a,edge.b);var far:=_weather_hit(edge.b,edge.a)
		_require(not near.is_empty() and not far.is_empty() and absf(near.position[edge.axis]-float(edge.from))<.00005 and absf(far.position[edge.axis]-float(edge.to))<.00005,"actual flashing has a 1.2mm closed wall")
	for y: float in fixture.leader_wall_plates:
		var at:=Vector3(fixture.cap_outer_rect[2],y,fixture.outlet_z)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.RIGHT*.02),root.to_global(at-Vector3.RIGHT*.07),1,bodies))
		_require(not hit.is_empty() and "ROOF_PUBLIC_CORE/Wall" in str(hit.collider.get_path()) and root.to_local(hit.position).distance_to(at)<.00005,"public leader plate seats on retained wall")
	var fluid:=Vector3(fixture.gutter_x,fixture.gutter_low_y-fixture.gutter_radius+fixture.gutter_wall+.004,fixture.outlet_z)
	var native_outlet:=_weather_hit(fluid,Vector3(fluid.x,fixture.leader_y[0]-.01,fluid.z))
	_require(native_outlet.is_empty(),"actual gutter and leader have an unplugged throat")
	var outlet:=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(fluid),root.to_global(Vector3(fluid.x,19.19,fluid.z)),1,[player.get_rid()]))
	_require(not outlet.is_empty() and "RoofBaseFlashings/" in str(outlet.collider.get_path()) and absf(root.to_local(outlet.position).y-19.2012)<.00005,"actual open outlet reaches the fitted base flashing foot")
	var outlet_exclude: Array[RID]=[player.get_rid()]
	for body: CollisionObject3D in root.get_node("RoofBaseFlashings").find_children("*","CollisionObject3D",true,false):outlet_exclude.append(body.get_rid())
	outlet=space.intersect_ray(PhysicsRayQueryParameters3D.create(root.to_global(fluid),root.to_global(Vector3(fluid.x,19.19,fluid.z)),1,outlet_exclude))
	_require(not outlet.is_empty() and "ROOF_DECK_MIDDLE/Floor" in str(outlet.collider.get_path()) and absf(root.to_local(outlet.position).y-19.2)<.00005,"flashing foot retains the original unfinished main roof field below")
	for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var at:=Vector3(fixture.gutter_x,21.,fixture.outlet_z)
		var hit:=_weather_hit(at,at+direction*.05)
		_require(not hit.is_empty() and absf(at.distance_to(hit.position)-float(fixture.leader_bore_radius))<.00005,"actual public leader retains 76.2mm bore")
	for view: Dictionary in [
		{"id":"public_weather_oblique", "at":Vector3(6.5,23.4,-4.3),"look":Vector3(2.6,22.65,-1.1)},
		{"id":"public_cricket_west", "at":Vector3(1.65,22.75,-2.2),"look":Vector3(2.32,22.52,-1.08)},
		{"id":"public_flashing_pocket", "at":Vector3(2.25,22.52,-1.0),"look":Vector3(2.37,22.682,-1.075)},
		{"id":"public_gutter_outlet", "at":Vector3(6.1,22.7,4.2),"look":Vector3(fixture.gutter_x,22.3,fixture.outlet_z)},
		{"id":"public_leader_from_deck", "at":Vector3(6.2,19.2,3.1),"look":Vector3(fixture.gutter_x,21.2,fixture.outlet_z)}]:
		player.set_physics_process(false)
		var eye: Vector3=view.at
		if view.id=="public_leader_from_deck":eye.y+=player.STANDING_EYE
		player.global_position=root.to_global(eye-Vector3.UP*player.STANDING_EYE)
		player.camera.global_position=root.to_global(eye)
		player.camera.fov=45 if view.id=="public_flashing_pocket" else 72
		await _court_capture(view.id,view.look)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("weather-checks.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","parts":parts,"triangles":triangles,"roof_contacts":roof_contacts,"valley_contacts":valley_contacts,
		"grooves":grooves,"failures":failures,"note":"Native fall and physical interfaces only. Hydraulic capacity and downstream main roof drainage remain unproved."},"\t"))

func _inside_rect(p: Vector2,r: Array) -> bool:
	return p.x>=float(r[0]) and p.x<=float(r[2]) and p.y>=float(r[1]) and p.y<=float(r[3])

func _weather_hit(a: Vector3,b: Vector3) -> Dictionary:
	var nearest:=INF;var result: Dictionary={}
	for i in range(0,weather_native.size(),3):
		var hit: Variant=Geometry3D.segment_intersects_triangle(a,b,weather_native[i],weather_native[i+1],weather_native[i+2])
		if hit==null:continue
		var distance:=a.distance_to(hit)
		if distance>=nearest:continue
		nearest=distance
		var normal: Vector3=(weather_native[i+1]-weather_native[i]).cross(weather_native[i+2]-weather_native[i]).normalized()
		result={"position":hit,"normal":normal}
	return result
