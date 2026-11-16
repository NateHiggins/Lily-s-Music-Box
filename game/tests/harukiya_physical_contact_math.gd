extends RefCounted
## UNAPPLIED test-only technical contact candidate. No song or set rearrangement.
## Analytic IK/current-skin measurement adapted from retained music_instruments.
const CONTACT_SKIN_WEIGHT := .35
const PALM_GRIP_DATA := "res://tests/fixtures/harukiya_palm_grip_datums.json"
var palm_grips:Dictionary={}
var kit: Node3D
var kit_data: Dictionary = {}
var piano_frame := Transform3D.IDENTITY
var moving: Dictionary = {}
var rest_props: Dictionary = {}
var seated: Dictionary = {}
var latest: Dictionary = {}
var worst: Dictionary = {}
var worst_samples: Dictionary = {}
var seconds := 0.0
var press := 0.0
var event_index := 0
var drum_targets := {"Left":"HiHatUpper","Right":"Snare"}
func _event(_instrument: String, _side: String) -> Dictionary:
	return {"press":press,"index":event_index}
func _piano(driver: Node) -> void:
	var body: Skeleton3D = driver.skeleton
	for side: String in ["Left", "Right"]:
		var event := _event("piano", side.to_lower())
		var press := float(event.press)
		var variation := int(event.index) % 5 - 2
		var x := (.18 if side == "Left" else -.17) + float(variation)*(1.0/43.0)
		# Canonical piano-local key datum retained from the source instrument;
		# current mounted native ray is mandatory, and current rig is remeasured.
		var target := piano_frame * Vector3(x, .670 + .020*(1.0-press), -.470)
		var basis := _hand_basis(body, side, piano_frame.basis*Vector3.BACK)
		var finger_map := _finger_map(body, side, basis, 12.0 + press*5.0)
		var index_bone := body.find_bone(side+"HandIndex3")
		var finger: Transform3D = finger_map[index_bone]
		var tip_local: Vector3 = seated[str(driver.person_id)].fingertips[side].bone_local_point
		var finger_tip := finger*tip_local
		var wrist := target - body.global_basis*finger_tip
		_limb(driver, side+"Arm", side+"ForeArm", side+"Hand", wrist,
			_arm_pole(body,side), basis, "piano_"+side)
		_fingers(driver, side, finger_map)
		var actual := body.global_transform * (body.get_bone_global_pose(index_bone)*tip_local)
		_measure("piano_fingertip_"+side, actual.distance_to(target), {"target":target,"actual":actual,"press":press,"key_top_world_y":(piano_frame*Vector3(0,.670,0)).y,
			"contact_point_class":"most distal fully weighted source skin vertex; pad clearance requires native review"})
	for side: String in ["Left", "Right"]:
		var x := .15 if side == "Left" else -.09
		var support := piano_frame * Vector3(x, .0 if side == "Left" else .077, -.42)
		_foot(driver, side, support, piano_frame.basis*Vector3.BACK)


func _drums(driver: Node) -> void:
	var body: Skeleton3D = driver.skeleton
	for side: String in ["Left", "Right"]:
		var instrument := "hihat" if side == "Left" else "snare"
		var native: String = str(drum_targets[side])
		var event := _event(instrument, side.to_lower())
		var press := float(event.press)
		var row: Dictionary = kit_data.contacts[native]
		var target_local := _v(row.position)
		# Exported HiHatUpper target is an actual authored bow vertex; do not
		# substitute an approximate flat plane through this conical cymbal.
		var tip := kit.to_global(target_local) + Vector3.UP*(.018+.065*(1.0-press))
		var group := "Stick"+side
		var contact: Dictionary = kit_data.contacts[group]
		var native_axis := (_v(contact.tip)-_v(contact.position)).normalized()
		var length := _v(contact.tip).distance_to(_v(contact.position))
		var shoulder: Vector3 = body.global_transform*body.get_bone_global_pose(body.find_bone(side+"Arm")).origin
		var grip_seed:Vector3=shoulder
		if native in ["HiHatUpper","Snare"]:
			# A shoulder-to-tip line lets the butt run through the chest at the
			# near drums. Author a hand position in front of the actual shoulder,
			# then keep the complete unchanged native stick length to its target.
			var forward:Vector3=seated[str(driver.person_id)].forward
			var outside:Vector3=body.global_basis*Vector3.RIGHT*(1.0 if side=="Left" else -1.0)
			grip_seed+=forward*.27-Vector3.UP*.10+outside*.02
		var axis: Vector3 = (tip-grip_seed).normalized()
		# On impact the actual visible native tip lands at the exported surface.
		tip -= Vector3.UP*.018*press
		var grip := tip-axis*length
		var basis := _drum_hand_basis(body, side, axis)
		var finger_map := _finger_map(body, side, basis, 58.0,basis*_v(palm_grips.sides[side].normal_hand_local))
		var grip_offset := basis * _grip_local(body, side)
		var wrist := grip-body.global_basis*grip_offset
		_limb(driver, side+"Arm", side+"ForeArm", side+"Hand", wrist,
			_arm_pole(body,side), basis, "drum_"+side)
		_fingers(driver, side, finger_map)
		var hand := body.get_bone_global_pose(body.find_bone(side+"Hand"))
		var actual_grip := body.global_transform*(hand*_grip_local(body,side))
		var rotation := Basis(Quaternion(native_axis, (kit.global_basis.inverse()*axis).normalized()))
		for draw: Node3D in moving[group]:
			var original: Transform3D = rest_props[draw.get_instance_id()]
			draw.transform = Transform3D(rotation*original.basis,kit.to_local(actual_grip))
		var actual_tip := actual_grip+axis*length
		_measure("stick_tip_"+side,actual_tip.distance_to(tip),{"target":tip,"actual":actual_tip,"press":press,"surface":native,"preferred_grip_seed":grip_seed,"actual_grip":actual_grip,"native_axis":axis})
	var kick := float(_event("kick", "right").press)
	var hat := float(_event("hihat", "left").press)
	_move_group("BassPedal",-9.0*kick); _move_group("BassBeater",-12.0*kick); _move_group("HiHatPedal",-9.0*hat)
	for side: String in ["Left", "Right"]:
		var group := "HiHatPedal" if side == "Left" else "BassPedal"
		var amount := hat if side == "Left" else kick
		var pivot := _v(kit_data.pivots[group].position)
		var resting := _v(kit_data.contacts[group].position)
		var pedal_turn:=Basis(Vector3.RIGHT,deg_to_rad(-9.0*amount))
		var support := kit.to_global(pivot+pedal_turn*(resting-pivot))
		var support_normal:Vector3=kit.global_basis*(pedal_turn*_v(kit_data.contacts[group].normal))
		_foot(driver,side,support,kit.global_basis*Vector3.FORWARD,support_normal)


func _move_group(group: String, degrees: float) -> void:
	var turn := Basis(_v(kit_data.pivots[group].axis),deg_to_rad(degrees))
	for draw: Node3D in moving[group]:
		var original: Transform3D = rest_props[draw.get_instance_id()]
		draw.transform = Transform3D(turn*original.basis,original.origin)


func _limb(driver: Node, first: String, middle: String, end: String, world_target: Vector3,
		world_pole: Vector3, end_basis: Basis, label: String) -> void:
	var body: Skeleton3D = driver.skeleton
	var pipe: SkeletonModifier3D = driver.pipeline
	var a := body.find_bone(first); var b := body.find_bone(middle); var c := body.find_bone(end)
	var pa := body.get_bone_global_pose(a); var pb := body.get_bone_global_pose(b); var pc := body.get_bone_global_pose(c)
	var upper := pa.origin.distance_to(pb.origin); var lower := pb.origin.distance_to(pc.origin)
	var target := body.to_local(world_target); var direction := target-pa.origin
	var asked := direction.length(); var distance := clampf(asked,absf(upper-lower)+.0001,upper+lower-.0001)
	if asked < .000001: return
	direction /= asked
	var pole := body.to_local(world_pole)-pa.origin
	pole = (pole-direction*pole.dot(direction)).normalized()
	if pole.length_squared() < .1: pole = direction.cross(Vector3.UP).normalized()
	var along := (upper*upper-lower*lower+distance*distance)/(2.0*distance)
	var height := sqrt(maxf(0.0,upper*upper-along*along))
	var elbow := pa.origin+direction*along+pole*height
	var turn := Basis(Quaternion((pb.origin-pa.origin).normalized(),(elbow-pa.origin).normalized()))
	pipe._write(a,Transform3D(turn*pa.basis,pa.origin),"contact")
	pb = body.get_bone_global_pose(b); pc = body.get_bone_global_pose(c)
	var reached := pa.origin+direction*distance
	turn = Basis(Quaternion((pc.origin-pb.origin).normalized(),(reached-pb.origin).normalized()))
	pipe._write(b,Transform3D(turn*pb.basis,pb.origin),"contact")
	pc = body.get_bone_global_pose(c)
	pipe._write(c,Transform3D(end_basis,pc.origin),"contact")
	_measure(str(driver.person_id)+"_"+label,(body.global_transform*pc.origin).distance_to(world_target),{"asked_m":asked,"reach_m":upper+lower,"clamped":asked<absf(upper-lower)+.0001 or asked>upper+lower-.0001})


func _hand_basis(body: Skeleton3D, side: String, world_forward: Vector3) -> Basis:
	var hand := body.get_bone_global_rest(body.find_bone(side+"Hand"))
	var index := body.get_bone_global_rest(body.find_bone(side+"HandIndex1")).origin
	var pinky := body.get_bone_global_rest(body.find_bone(side+"HandPinky1")).origin
	var middle := body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var forward := (middle-hand.origin).normalized()
	var across := (index-pinky).normalized()*(1.0 if side=="Left" else -1.0)
	var normal := forward.cross(across).normalized(); across = normal.cross(forward).normalized()
	var wanted := (body.global_basis.inverse()*world_forward).normalized()
	var up := (body.global_basis.inverse()*Vector3.UP).normalized()
	var right := up.cross(wanted).normalized(); up = wanted.cross(right).normalized()
	# Candidate palm orientation is derived from current index/pinky rests.
	# Turn around the long hand axis: piano and matched drum grips palm down.
	return Basis(wanted,PI)*Basis(right,up,wanted)*Basis(across,normal,forward).inverse()*hand.basis


func _drum_hand_basis(body:Skeleton3D,side:String,world_axis:Vector3) -> Basis:
	# Matched grip: the complete shaft lies tangent to the measured palm plane,
	# diagonally across the hand. Its butt must not follow the forearm axis.
	var hand:=body.get_bone_global_rest(body.find_bone(side+"Hand"))
	var middle:Vector3=body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var source_normal:Vector3=(hand.basis*_v(palm_grips.sides[side].normal_hand_local)).normalized()
	var source_forward:Vector3=(middle-hand.origin).normalized()
	source_forward=(source_forward-source_normal*source_normal.dot(source_forward)).normalized()
	var source_across:Vector3=source_normal.cross(source_forward).normalized()
	var axis:Vector3=(body.global_basis.inverse()*world_axis).normalized()
	var down:Vector3=body.global_basis.inverse()*Vector3.DOWN
	var normal:Vector3=(down-axis*down.dot(axis)).normalized()
	if normal.length_squared()<.1:normal=axis.cross(Vector3.RIGHT).normalized()
	var forward:Vector3=Basis(normal,deg_to_rad(30.0 if side=="Left" else -30.0))*axis
	var across:Vector3=normal.cross(forward).normalized()
	return Basis(across,normal,forward)*Basis(source_across,source_normal,source_forward).inverse()*hand.basis

func prepare_palm_grips() -> bool:
	var decoded:Variant=JSON.parse_string(FileAccess.get_file_as_string(PALM_GRIP_DATA))
	if decoded is not Dictionary:return false
	palm_grips=decoded
	return FileAccess.get_sha256("res://assets/characters/stacy/stacy.gltf")==str(palm_grips.body_gltf_sha256) and FileAccess.get_sha256("res://assets/characters/stacy/stacy.bin")==str(palm_grips.body_bin_sha256) and FileAccess.get_sha256("res://assets/props/harukiya_drumkit.glb")==str(palm_grips.native_asset_sha256)

func _grip_local(_body: Skeleton3D, side: String) -> Vector3:
	# Actual fully-Hand-weighted source palm facet, not the skeletal centre.
	# Whole posed sticks/arms still require independent triangle checks.
	var row:Dictionary=palm_grips.sides[side]
	return _v(row.surface_hand_local)+_v(row.normal_hand_local)*(float(row.native_grip_radius_m)+float(palm_grips.contact_gap_m))

## Finger transforms relative to a wrist at origin; computed before writing,
## so fingertip targeting needs neither a second skeletal writer nor iteration.

func _finger_map(body: Skeleton3D, side: String, hand_basis: Basis, curl_degrees: float, palm_normal:Vector3=Vector3.ZERO) -> Dictionary:
	var hand := body.find_bone(side+"Hand")
	var result := {hand:Transform3D(hand_basis,Vector3.ZERO)}
	var rest_hand := body.get_bone_global_rest(hand)
	var rest_middle := body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var forward := (hand_basis*(rest_hand.basis.inverse()*(rest_middle-rest_hand.origin))).normalized()
	# Across the hand, not along the resting arm/fingers. Positive rotation
	# bends fingertips towards the floor and closes the grip around the stick.
	var across := forward.cross(palm_normal).normalized() if not palm_normal.is_zero_approx() else (body.global_basis.inverse()*Vector3.UP).cross(forward).normalized()
	for finger: String in ["Thumb","Index","Middle","Ring","Pinky"]:
		for number in range(1,4):
			var bone := body.find_bone(side+"Hand"+finger+str(number))
			if bone < 0: continue
			var parent := body.get_bone_parent(bone)
			var parent_pose: Transform3D = result.get(parent,Transform3D(hand_basis,Vector3.ZERO))
			var pose := parent_pose*body.get_bone_rest(bone)
			var amount := curl_degrees*(.35 if finger=="Thumb" else 1.0)
			pose.basis = Basis(across.normalized(),deg_to_rad(amount))*pose.basis
			result[bone] = pose
	result.erase(hand); return result


func _fingers(driver: Node, side: String, finger_map: Dictionary) -> void:
	var body: Skeleton3D = driver.skeleton
	var origin := body.get_bone_global_pose(body.find_bone(side+"Hand")).origin
	for bone: int in finger_map:
		if bone == body.find_bone(side+"Hand"): continue # wrist already has this sole contact writer
		var pose: Transform3D = finger_map[bone]; pose.origin += origin
		driver.pipeline._write(bone,pose,"contact")


func _contact(identity: String) -> Vector3:
	return kit.to_global(_v(kit_data.contacts[identity].position))


func _v(value: Array) -> Vector3: return Vector3(float(value[0]),float(value[1]),float(value[2]))


func _measure(label: String, gap: float, details: Dictionary) -> void:
	details["error_m"] = gap; details["seconds"] = seconds; details["frame"] = roundi(seconds*24.0)
	latest[label] = details
	if not worst.has(label) or gap>float(worst[label]): worst_samples[label] = details.duplicate(true)
	worst[label] = maxf(float(worst.get(label,0.0)),gap)

## Measure the terminal surface directly, using the imported mesh and inverse
## binds. A fully Index3-weighted vertex follows this joint exactly. This is
## the most distal tip, not an invented nail/phalange length or a claim that
## the entire softer finger pad is clear of the key.

func _fingertip_datum(driver: Node, side: String) -> Dictionary:
	var body: Skeleton3D = driver.skeleton
	var terminal := body.find_bone(side+"HandIndex3")
	var to_terminal := body.get_bone_global_rest(terminal).affine_inverse()
	var longest := -INF; var witness := {}
	for draw: MeshInstance3D in driver.model.find_children("*","MeshInstance3D",true,false):
		if str(draw.name) != "Skin_hands" or draw.mesh==null or draw.skin==null: continue
		var joints: Array[int] = []; var rest: Array[Transform3D] = []
		for slot in draw.skin.get_bind_count():
			var name := draw.skin.get_bind_name(slot)
			var bone := body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(slot)
			if bone<0: return {}
			joints.append(bone); rest.append(body.get_bone_global_rest(bone)*draw.skin.get_bind_pose(slot))
		for surface in draw.mesh.get_surface_count():
			var data := draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty(): continue
			var slots := int(bones.size()/vertices.size())
			for vertex in vertices.size():
				var weight := 0.0; var point := Vector3.ZERO
				for slot in slots:
					var index := vertex*slots+slot; var joint := bones[index]
					if joints[joint]==terminal: weight+=weights[index]
					point += (rest[joint]*vertices[vertex])*weights[index]
				if weight<.9999: continue
				var local := to_terminal*point
				if local.y>longest:
					longest=local.y; witness={"mesh":str(draw.name),"surface":surface,"vertex":vertex,
						"bone":side+"HandIndex3","terminal_weight":weight,"bone_local_point":local,
						"point_class":"most distal source vertex, not pad plane"}
	if not is_finite(longest) or longest <= 0.0: return {}
	return witness

## Native skin/bind data, posterior samples dominated by Hips. These are
## source measurements, not a hard-coded offset borrowed from another actor.

func _pelvis_datum(driver: Node) -> Dictionary:
	var body: Skeleton3D = driver.skeleton
	var hips := body.find_bone("Hips")
	var hip := body.get_bone_global_rest(hips).origin
	var low := INF; var witness := {}
	for draw: MeshInstance3D in driver.model.find_children("*","MeshInstance3D",true,false):
		if str(draw.name) != "Skin_body" and str(draw.name) != "Skin_hips": continue
		if draw.mesh==null or draw.skin==null: continue
		var joints: Array[int] = []; var rest: Array[Transform3D] = []
		for slot in draw.skin.get_bind_count():
			var name := draw.skin.get_bind_name(slot)
			var bone := body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(slot)
			joints.append(bone); rest.append(body.get_bone_global_rest(bone)*draw.skin.get_bind_pose(slot))
		for surface in draw.mesh.get_surface_count():
			var data := draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty(): continue
			var slots := int(bones.size()/vertices.size())
			for vertex in vertices.size():
				var weight := 0.0; var point := Vector3.ZERO
				for slot in slots:
					var index := vertex*slots+slot; var joint := bones[index]
					if joints[joint]==hips: weight+=weights[index]
					point += (rest[joint]*vertices[vertex])*weights[index]
				if weight<CONTACT_SKIN_WEIGHT or point.z>hip.z or absf(point.x-hip.x)>absf(body.get_bone_global_rest(body.find_bone("LeftUpLeg")).origin.x-body.get_bone_global_rest(body.find_bone("RightUpLeg")).origin.x)*.75: continue
				if point.y<low:
					low=point.y; witness={"mesh":str(draw.name),"surface":surface,"vertex":vertex,"hips_weight":weight,"rest_point":point}
	if not is_finite(low) or hip.y-low<=0.0: return {}
	return {"hips_above_support":hip.y-low,"support_witness":witness,"rest_hip":hip}


func _foot(driver: Node, side: String, support: Vector3, forward: Vector3, support_normal:Vector3=Vector3.UP) -> void:
	var body: Skeleton3D = driver.skeleton
	var foot: int = body.find_bone(side+"Foot")
	var heading := Basis(Vector3.UP,atan2(forward.x,forward.z))
	var tilt:=Basis(Quaternion(Vector3.UP,support_normal.normalized()))
	var source_pitch:=Basis.IDENTITY
	if driver.soles[side].has("pitch_rad"):source_pitch=Basis(_v(driver.soles[side].pitch_axis),float(driver.soles[side].pitch_rad))
	var basis := body.global_basis.inverse()*tilt*heading*source_pitch*body.get_bone_global_rest(foot).basis
	var local: Vector3 = driver.soles[side].bone_local_point
	var target: Vector3 = support-body.global_basis*(basis*local)
	var knee_pole:Vector3=target+forward*body.get_bone_global_rest(foot).origin.distance_to(body.get_bone_global_rest(body.find_bone(side+"UpLeg")).origin)+Vector3.UP*body.get_bone_rest(foot).origin.length()
	if driver.role=="drums":knee_pole+=body.global_basis*Vector3.RIGHT*(.24 if side=="Left" else -.24)
	_limb(driver,side+"UpLeg",side+"Leg",side+"Foot",target,knee_pole,basis,"foot_"+side)
	var actual: Vector3 = body.global_transform*(body.get_bone_global_pose(foot)*local)
	_measure(str(driver.person_id)+"_sole_"+side,actual.distance_to(support),{"target":support,"actual":actual,"measured_skin":driver.soles[side],"support_normal":support_normal,"knee_pole":knee_pole})

func _arm_pole(body: Skeleton3D, side: String) -> Vector3:
	var shoulder: Vector3=body.get_bone_global_pose(body.find_bone(side+"Arm")).origin
	var elbow: Vector3=body.get_bone_global_rest(body.find_bone(side+"ForeArm")).origin
	var rest_shoulder: Vector3=body.get_bone_global_rest(body.find_bone(side+"Arm")).origin
	var length: float=elbow.distance_to(rest_shoulder)
	return body.global_transform*(shoulder+Vector3(length if side=="Left" else -length,length*.5,-length*.5))

var proposed_payload: MeshInstance3D
var payload_source_pose := Transform3D.IDENTITY
var carry_state: Dictionary = {}
func _carry(driver: Node) -> void:
	var body: Skeleton3D=driver.skeleton
	var hand: int=body.find_bone("RightHand")
	var shoulder: Vector3=body.get_bone_global_pose(body.find_bone("RightArm")).origin
	var elbow: Vector3=body.get_bone_global_pose(body.find_bone("RightForeArm")).origin
	var wrist: Vector3=body.get_bone_global_pose(hand).origin
	var reach: float=shoulder.distance_to(elbow)+elbow.distance_to(wrist)
	var chest: Vector3=body.get_bone_global_pose(body.find_bone("Hips")).origin.lerp(shoulder,.65)
	var forward: Vector3=driver.actor.global_basis*Vector3.FORWARD
	var grip: Vector3=body.global_transform*chest+forward*reach*.70
	var basis: Basis=_hand_basis(body,"Right",forward)
	var finger_map: Dictionary=_finger_map(body,"Right",basis,58.)
	var local: Vector3=_grip_local(body,"Right")
	_limb(driver,"RightArm","RightForeArm","RightHand",grip-body.global_basis*(basis*local),_arm_pole(body,"Right"),basis,"carry_hand")
	_fingers(driver,"Right",finger_map)
	var actual: Vector3=body.global_transform*(body.get_bone_global_pose(hand)*local)
	var source_grip: Vector3=_v(kit_data.contacts.StickLeft.position)
	var native_axis: Vector3=(_v(kit_data.contacts.StickLeft.tip)-source_grip).normalized()
	var turn:=Basis(Quaternion(native_axis,forward.normalized()))
	# Proposed load-in pose for one COMPLETE named native wood stick, not disassembly authority.
	proposed_payload.global_transform=Transform3D(turn,actual-turn*source_grip)*payload_source_pose
	carry_state={"source_part":"DrumKit_StickLeft_KitSticks","handler":driver.person_id,"hand_target":grip,"actual_rig_grip":actual,"rig_measured_reach":reach,"payload_transform":proposed_payload.global_transform,"new_technical_pose":true,"artistically_accepted":false}
	_measure("component_handler_grip",actual.distance_to(grip),carry_state.duplicate(true))
