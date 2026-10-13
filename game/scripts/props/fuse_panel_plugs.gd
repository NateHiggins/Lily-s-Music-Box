extends RefCounted
## Four real objects, one branch holder. No rating dial or inventory substitution.
const RATINGS := [30,10,15,20]
const THREAD_END := TAU*5.0
const THREAD_TRAVEL := .025
const HOME := Vector3(.145,.46,.108)
const PARKS := [Vector3(.065,.145,.165),Vector3(.185,.145,.165),Vector3(.065,.275,.165),Vector3(.185,.275,.165)]
var panel: Node3D
var hand: RefCounted:
	get: return panel._hand_controls
var rows: Array[Dictionary] = []
var proved := false
var publishing := false
var _last_sleeping := true
var last_block: Dictionary = {}
var _load_seconds := 0.0

func configure(owner: Node3D,_controls: RefCounted) -> void:
	panel=owner
	var originals: Array=panel.find_children("*","MeshInstance3D",true,false).filter(func(n): return n.mesh!=null)
	var spares: Array=[]
	# Names are assigned by the native partition binder; never infer original
	# source mesh indices after it has installed additional fixed stock.
	for draw: MeshInstance3D in originals:
		if str(draw.get_meta("native_service_instrument_part","")).begins_with("M07_P0"):
			if str(draw.get_meta("native_service_instrument_part")) in ["M07_P018","M07_P019","M07_P020"]: spares.append(draw)
	assert(spares.size()==3)
	spares.sort_custom(func(a,b): return str(a.get_meta("native_service_instrument_part"))<str(b.get_meta("native_service_instrument_part")))
	for i in 4:
		var body := RigidBody3D.new()
		body.name="PhysicalFuse%d"%RATINGS[i]
		body.mass=.08;body.freeze=true;body.can_sleep=true
		body.continuous_cd=true
		panel.add_child(body)
		var shape := CollisionShape3D.new()
		var cap := CylinderShape3D.new()
		cap.radius=.042;cap.height=.028
		shape.shape=cap;shape.rotation.x=PI/2;shape.position.z=.01
		body.add_child(shape)
		var stem := CollisionShape3D.new()
		var base := CylinderShape3D.new()
		base.radius=.024; base.height=.026
		stem.shape=base;stem.rotation.x=PI/2;stem.position.z=-.017
		body.add_child(stem)
		var draws: Array[MeshInstance3D]=[]
		for j in 4:
			var source: MeshInstance3D=[panel._plug,panel._window,panel._link,panel._stamp][j]
			var draw: MeshInstance3D=source if i==0 else spares[i-1] if j==0 else MeshInstance3D.new()
			if i>0 and j>0:
				draw.name="Spare%dDetail%d"%[RATINGS[i],j]
				draw.mesh=source.mesh
				draw.material_override=source.material_override
				panel.add_child(draw)
			draws.append(draw)
		var label := Label3D.new()
		label.name="FuseRating";label.text="%d A"%RATINGS[i]
		label.font_size=32;label.pixel_size=.00042;label.outline_size=0
		label.modulate=Color(.09,.07,.035)
		label.position=Vector3(0,.027,.0265)
		body.add_child(label)
		rows.append({"body":body,"draws":draws,"station":0 if i==0 else i+1,"turn":0.0})
	var card := Label3D.new()
	card.name="ConductorRating";card.text="HOUSE LIGHTS\nWIRE 15 A"
	card.font_size=32;card.pixel_size=.0008;card.outline_size=0
	card.modulate=Color(.08,.07,.04)
	card.position=Vector3(-.12,.20,.090)
	panel.add_child(card)
	panel._index.visible=false
	panel._offered.visible=false
	_install_fixed_collision(originals)
	sync_from_legacy()

func _install_fixed_collision(originals: Array) -> void:
	var body := StaticBody3D.new()
	body.name="PanelInteriorCollision"
	panel.add_child(body)
	for draw: MeshInstance3D in originals:
		var part := str(draw.get_meta("native_service_instrument_part",""))
		if part not in ["M07_P000","M07_P001","M07_P002","M07_P003","M07_P007","M07_P017"]: continue
		var shape := CollisionShape3D.new()
		shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);shape.global_transform=draw.global_transform

func active_index() -> int:
	for i in rows.size():
		if rows[i].station==0: return i
	return -1

func target_for(collider: Node) -> Dictionary:
	for i in rows.size():
		if collider==rows[i].body or rows[i].body.is_ancestor_of(collider): return grip(i)
	return {}

func grip(index: int) -> Dictionary:
	var row: Dictionary=rows[index]
	var threaded: bool=row.station==0
	var key := "fuse%d"%index
	return {"owner":panel,"part":row.body,"frame":panel,"kind":"hinge" if threaded else "free",
		"axis":Vector3.BACK,"minimum":0.0,"maximum":THREAD_END,
		"read":func(): return row.turn if threaded else row.body.position,
		"write":func(value): _turn(index,float(value)) if threaded else _carry(index,value),
		"begin":func():
			if not hand.held.is_empty() or RealityState.save_write_blocked: return false
			hand.held=key
			row.body.freeze=true;row.body.linear_velocity=Vector3.ZERO;row.body.angular_velocity=Vector3.ZERO
			if not threaded: row.station=-1
			return true,
		"owns":func(): return hand.held==key,
		"end":func():
			if threaded and row.turn>=THREAD_END-.0001: row.station=-1;row.turn=0.0
			if row.station==-1: _release(index)
			hand.held=""
			update_facts()
			panel.manipulation_changed.emit()}

func _turn(index: int,value: float) -> void:
	if hand.held!="fuse%d"%index: return
	if panel.panel_live(): panel._balk(.6);return
	rows[index].turn=clampf(value,0,THREAD_END)
	# Avoid an asymptotic sub-micrometre stop at either machined thread end.
	if rows[index].turn<.002: rows[index].turn=0.0
	elif rows[index].turn>THREAD_END-.002: rows[index].turn=THREAD_END
	_place_thread(rows[index])
	update_facts();refresh()

func _place_thread(row: Dictionary) -> void:
	row.body.position=HOME+Vector3(0,0,THREAD_TRAVEL*row.turn/THREAD_END)
	row.body.basis=Basis(Vector3.BACK,row.turn)

func _carry(index: int,value: Vector3) -> void:
	if hand.held!="fuse%d"%index or not value.is_finite(): return
	var body: RigidBody3D=rows[index].body
	var pose := body.global_transform
	var remaining := panel.global_basis*(value-body.position)
	# Sweep the complete plug, retaining surface-tangent motion when a cursor
	# gesture also presses into the back plate. An all-or-nothing overlap query
	# traps a hand-held part against the surface it is being lifted away from.
	last_block={}
	for slide in 4:
		if remaining.length_squared()<.0000000001: break
		var query := PhysicsTestMotionParameters3D.new()
		query.from=pose;query.motion=remaining;query.margin=.0002
		var result := PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(body.get_rid(),query,result):
			pose.origin+=remaining
			break
		pose.origin+=result.get_travel()
		last_block={"collider":str(result.get_collider().get_path()),"normal":str(result.get_collision_normal()),"pose":str(panel.to_local(pose.origin))}
		remaining=result.get_remainder().slide(result.get_collision_normal())
	body.global_transform=pose
	refresh()

func _release(index: int) -> void:
	var row: Dictionary=rows[index]
	var mouth := HOME+Vector3(0,0,THREAD_TRAVEL)
	var delta: Vector3=row.body.position-mouth
	# Only a hand-delivered plug at the actual mouth can catch its first thread.
	# A short alignment is the receiving socket's physical seating tolerance.
	if Vector2(delta.x,delta.y).length()<.021 and absf(delta.z)<.035 and active_index()==-1:
		if panel.panel_live() or RATINGS[index]>panel.CONDUCTOR_RATING:
			panel.offered_rating=RATINGS[index] if RATINGS[index]>panel.CONDUCTOR_RATING else 0
			panel._balk(.9)
		else:
			panel.offered_rating=0
			row.station=0;row.turn=THREAD_END
			_place_thread(row);refresh();return
	for slot in PARKS.size():
		if rows.any(func(other): return other.station==slot+1): continue
		if row.body.position.distance_to(PARKS[slot])<.03:
			row.station=slot+1;row.body.position=PARKS[slot];row.body.basis=Basis.IDENTITY
			refresh();return
	# No invisible parking plane: unplaced stock falls against actual collision.
	row.body.freeze=false;row.body.sleeping=false

func refresh() -> void:
	for row: Dictionary in rows:
		var body: RigidBody3D=row.body
		var offsets := [Vector3.ZERO,Vector3(0,0,.022),Vector3(0,0,.018),Vector3(0,.027,.023)]
		for j in row.draws.size():
			row.draws[j].transform=body.transform*Transform3D(Basis.IDENTITY,offsets[j])
	panel._offered.visible=false

func tick(delta: float) -> void:
	refresh()
	update_facts()
	if not panel.main_open and panel.protects_conductor(): _load_seconds+=delta
	else: _load_seconds=0.0
	if _load_seconds>=1.8: prove_load()
	var sleeping := rows.all(func(row): return row.body.freeze or row.body.sleeping)
	if sleeping and not _last_sleeping: panel.manipulation_changed.emit()
	_last_sleeping=sleeping

func update_facts() -> void:
	var index := active_index()
	panel.plug_out=index<0 or rows[index].turn>.001
	if index>=0: panel.fitted_rating=RATINGS[index]
	if panel.plug_out or panel.over_fused(): proved=false
	panel.load_proved=proved and not panel.main_open and panel.protects_conductor()
	panel.panel_safe=proved and panel.protects_conductor()

func prove_load() -> void:
	update_facts()
	if _load_seconds>=1.8 and not panel.main_open and panel.protects_conductor() and not proved:
		proved=true
		publishing=true
		panel.apply_maintenance_result({"activity_id":"fuse_panel_rating_service","quality":"good",
			"note":"isolated main, replaced plug by hand, and restored protected load",
			"mechanism_patch":{"panel_safe":true}})
		publishing=false

func sync_from_legacy() -> void:
	hand.held=""
	_load_seconds=0.0
	var chosen := RATINGS.find(panel.fitted_rating)
	if chosen<0: chosen=0
	proved=panel.panel_safe and panel.protects_conductor()
	for i in rows.size():
		var row: Dictionary=rows[i]
		row.body.freeze=true;row.body.linear_velocity=Vector3.ZERO;row.body.angular_velocity=Vector3.ZERO
		row.station=0 if i==chosen else i+1
		row.turn=THREAD_END if i==chosen and panel.plug_out else 0.0
		if i==chosen: _place_thread(row)
		else: row.body.position=PARKS[i];row.body.basis=Basis.IDENTITY
	refresh()

func snapshot() -> Dictionary:
	var items: Array=[]
	for row: Dictionary in rows:
		var pos: Vector3=row.body.position
		var rot: Quaternion=row.body.basis.get_rotation_quaternion()
		items.append({"station":row.station,"turn":row.turn,"position":[pos.x,pos.y,pos.z],"rotation":[rot.x,rot.y,rot.z,rot.w]})
	return {"items":items,"proved":proved}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2 or value.get("proved") is not bool: return false
	if value.get("items") is not Array or value.items.size()!=4: return false
	var stations: Array=[]
	var active := -1
	for i in 4:
		var row: Variant=value.items[i]
		if row is not Dictionary or row.size()!=4: return false
		for key: String in ["station","turn"]:
			if typeof(row.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row[key])): return false
		if row.station!=int(row.station) or row.station< -1 or row.station>4 or row.turn<0 or row.turn>THREAD_END: return false
		if row.station!=0 and row.turn!=0: return false
		if row.station>=0:
			if row.station in stations: return false
			stations.append(row.station)
		if row.station==0: active=i
		for key: String in ["position","rotation"]:
			if row.get(key) is not Array or row[key].size()!=(3 if key=="position" else 4): return false
			for number: Variant in row[key]:
				if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
		var pos := Vector3(row.position[0],row.position[1],row.position[2])
		var rot := Quaternion(row.rotation[0],row.rotation[1],row.rotation[2],row.rotation[3])
		if pos.length()>10000 or absf(rot.length_squared()-1)>.0001: return false
		if row.station>=0:
			var expected := Quaternion(Vector3.BACK,float(row.turn)) if row.station==0 else Quaternion.IDENTITY
			if absf(rot.dot(expected))<.99999: return false
		if row.station==0 and not pos.is_equal_approx(HOME+Vector3(0,0,THREAD_TRAVEL*row.turn/THREAD_END)): return false
		if row.station>0 and not pos.is_equal_approx(PARKS[int(row.station)-1]): return false
	if value.proved and (active<0 or RATINGS[active]>15 or value.items[active].turn>.001): return false
	return true

func restore(value: Dictionary) -> void:
	if not valid(value): return
	hand.held="";proved=value.proved;_load_seconds=0.0
	for i in 4:
		var saved: Dictionary=value.items[i]
		var row: Dictionary=rows[i]
		row.station=int(saved.station);row.turn=float(saved.turn)
		row.body.freeze=true
		row.body.position=Vector3(saved.position[0],saved.position[1],saved.position[2])
		row.body.basis=Basis(Quaternion(saved.rotation[0],saved.rotation[1],saved.rotation[2],saved.rotation[3]).normalized())
		row.body.linear_velocity=Vector3.ZERO;row.body.angular_velocity=Vector3.ZERO
		if row.station==0: _place_thread(row)
		row.body.freeze=row.station!=-1
		row.body.sleeping=false
	update_facts();refresh()
