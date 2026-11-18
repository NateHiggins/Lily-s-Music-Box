extends RefCounted
## Native instrument contacts for the approved trio choreography.
const BassVisual := preload("res://scripts/props/harukiya_bass_visual.gd")
const CONTACT_SKIN_WEIGHT := .35
const BASS_SCALE := .88
const PLUCK_POSITION := .70
const STRINGS := [
	{"open_midi": 28, "nut": [-0.018, 1.665, 0.157], "bridge": [-0.069, 0.62, 0.245]},
	{"open_midi": 33, "nut": [-0.006, 1.665, 0.161], "bridge": [-0.023, 0.62, 0.265]},
	{"open_midi": 38, "nut": [0.006, 1.665, 0.161], "bridge": [0.023, 0.62, 0.265]},
	{"open_midi": 43, "nut": [0.018, 1.665, 0.157], "bridge": [0.069, 0.62, 0.245]}
]
var bar: OrisonV2BarRegion
var kit: Node3D
var bass: Node3D
var kit_data := {}
var moving := {}
var rest_props := {}
var seated := {}
var placements := {}
var notes: Array[Dictionary] = []
var attacks := {}
var seconds := 0.0
var piano_frame := Transform3D.IDENTITY
var player_frame := Transform3D.IDENTITY
var audience_eyeline := Vector3.ZERO


func prepare(room: OrisonV2BarRegion, performers: Dictionary, score: RefCounted) -> bool:
	bar = room
	kit = room.destination.get_node_or_null("HarukiyaDrumKit") as Node3D
	if kit == null:
		return false
	kit_data = kit.get_meta("source", {})
	if kit_data.is_empty():
		return false
	for draw: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.get_meta("harukiya_drum_part", ""))
		for group: String in ["StickLeft", "StickRight", "BassPedal", "HiHatPedal", "BassBeater"]:
			if identity.begins_with("DrumKit_" + group + "_"):
				if not moving.has(group):
					moving[group] = []
				moving[group].append(draw)
				rest_props[draw] = draw.transform
	if moving.size() != 5:
		return false
	var piano: Dictionary = room.destination.spec.relocations.piano
	piano_frame = room.destination.global_transform * Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(piano.yaw_deg))), GameBoot.b2g(piano.at))
	for id: String in performers:
		if not _fit(performers[id]):
			return false
	var bench: Dictionary = bar.destination.spec.architecture.stage.piano_bench
	var bench_top := bar.destination.to_global(GameBoot.b2g(bench.at)) + Vector3.UP * float(bench.height)
	_place_seated("adela_voss", bench_top + piano_frame.basis * Vector3(0, 0, .16), piano_frame.basis * Vector3.BACK)
	_place_seated("stacy", _contact("seat") + kit.global_basis * Vector3(-.095, 0, -.125), kit.global_basis * Vector3.FORWARD)
	var bass_at: Vector3 = score.anchors.bass_endpin
	if not is_equal_approx(bass_at.y, float(bar.destination.spec.architecture.stage.floor_z)):
		return false
	audience_eyeline = bar.to_global(score.anchors.audience_eyeline)
	var yaw := Basis(Vector3.UP, deg_to_rad(175.0))
	var base := bass_at + yaw * Vector3(-.30, 0, -.33)
	player_frame = bar.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(225.0)), base)
	placements["lily"] = player_frame
	bass = BassVisual.instantiate(BASS_SCALE)
	if bass == null:
		return false
	bar.add_child(bass)
	bass.global_transform = bar.global_transform * Transform3D(
		(Basis(Vector3.FORWARD, .10) * yaw * Basis(Vector3.RIGHT, -.32)).scaled(Vector3.ONE * BASS_SCALE), bass_at)
	bass.visible = false
	for index in score.attacks.size():
		var row: Dictionary = score.attacks[index]
		var key := str(row.instrument) + str(row.get("side", "") if row.instrument == "piano" else "")
		if not attacks.has(key):
			attacks[key] = []
		var attack := row.duplicate()
		attack["index"] = index
		attacks[key].append(attack)
	for row: Dictionary in score.bass_notes:
		var selected := -1
		var semitones := 99
		for index in STRINGS.size():
			var interval := int(row.midi) - int(STRINGS[index].open_midi)
			if interval >= 0 and interval <= 12 and interval < semitones:
				selected = index
				semitones = interval
		if selected < 0:
			return false
		notes.append({"seconds": row.seconds, "string": selected, "semitones": semitones,
			"stop": 1.0 - pow(2.0, -float(semitones) / 12.0), "velocity": row.velocity})
	return not notes.is_empty()


func _fit(driver: Node) -> bool:
	var id: String = driver.person_id
	var body: Skeleton3D = driver.skeleton
	var datum := {} if id == "lily" else _pelvis_datum(driver)
	if id != "lily" and datum.is_empty():
		return false
	datum["fingertips"] = {}
	if id != "stacy":
		for side: String in ["Left", "Right"]:
			var tip := _fingertip_datum(driver, side)
			if tip.is_empty():
				return false
			datum.fingertips[side] = tip
	var pose: Dictionary = driver.stand.poses.at_ease.duplicate(true)
	pose.hips = {"turn":0.0, "tilt":0.0, "shift_x":0.0, "shift_z":0.0}
	pose.spine = {"forward": {"adela_voss":16.0, "lily":8.0, "stacy":2.0}[id], "side":0.0, "twist":0.0}
	for side: String in ["left", "right"]:
		if id == "lily":
			pose[side].thigh = [2.0, 0.0]
			pose[side].shin = [2.0, 0.0]
			pose[side].arm = [25.0, 30.0]
			pose[side].forearm = [12.0, 45.0]
			pose[side].curl = 18.0
		else:
			pose[side].thigh = [5.0, 75.0]
			pose[side].shin = [4.0, 0.0]
			pose[side].arm = [65.0, 85.0]
			pose[side].forearm = [10.0, 90.0]
			pose[side].curl = 12.0
	driver.stand.poses["trio"] = pose
	if id != "lily":
		var previous: Array[Transform3D] = []
		for index in body.get_bone_count():
			previous.append(body.get_bone_pose(index))
		body.reset_bone_poses()
		driver.stand.apply(body, "trio", false, 0.0, 0.0)
		datum["base_hips_local"] = body.get_bone_global_pose(body.find_bone("Hips")).origin
		for index in previous.size():
			body.set_bone_pose(index, previous[index])
	seated[id] = datum
	return true


func _place_seated(id: String, support: Vector3, forward: Vector3) -> void:
	var basis := Basis(Vector3.UP, atan2(forward.x, forward.z))
	var datum: Dictionary = seated[id]
	datum["world_support"] = support
	placements[id] = Transform3D(basis, support + Vector3.UP * float(datum.hips_above_support) - basis * datum.base_hips_local)


func state_for(id: String) -> Dictionary:
	var target := audience_eyeline
	var weight := .65
	if id == "stacy":
		target = _contact("Snare")
		weight = .22
	elif id == "lily":
		var note := _note_at(seconds)
		target = _string_point(int(note.string), float(note.stop))
		if fposmod(seconds, 11.0) < 2.0:
			target = placements.adela_voss.origin + Vector3.UP * .9
		weight = .28
	return {"pose":"trio", "gaze_target":target, "gaze_weight":weight}


func apply(driver: Node) -> void:
	var id: String = driver.person_id
	if id == "lily":
		_play_bass(driver)
		return
	var body: Skeleton3D = driver.skeleton
	var hips := body.find_bone("Hips")
	var pose := body.get_bone_global_pose(hips)
	pose.origin = body.to_local(seated[id].world_support + Vector3.UP * float(seated[id].hips_above_support))
	driver.pipeline._write(hips, pose, "contact")
	if id == "stacy":
		_drums(driver)
	else:
		_piano(driver)


func release() -> void:
	for draw: MeshInstance3D in rest_props:
		if is_instance_valid(draw):
			draw.transform = rest_props[draw]
	if is_instance_valid(bass):
		bass.hide()
		bass.queue_free()


func _piano(driver: Node) -> void:
	var body: Skeleton3D = driver.skeleton
	for side: String in ["Left", "Right"]:
		var event := _event("piano", side.to_lower())
		var press := float(event.press)
		var variation := int(event.index) % 5 - 2
		var x := (.18 if side == "Left" else -.17) + float(variation)*(1.0/43.0)
		# 2 cm nearer on the same .386..505 m white-key front keeps the
		# longest sampled left reach within this actual arm's .451 m length.
		var target := piano_frame * Vector3(x, .670 + .020*(1.0-press), -.470)
		var basis := _hand_basis(body, side, piano_frame.basis*Vector3.BACK)
		var finger_map := _finger_map(body, side, basis, 12.0 + press*5.0)
		var index_bone := body.find_bone(side+"HandIndex3")
		var finger: Transform3D = finger_map[index_bone]
		var tip_local: Vector3 = seated[str(driver.person_id)].fingertips[side].bone_local_point
		var finger_tip := finger*tip_local
		var wrist := target - body.global_basis*finger_tip
		_limb(driver, side+"Arm", side+"ForeArm", side+"Hand", wrist,
			body.global_position + body.global_basis*Vector3(.34 if side == "Left" else -.34, .2, -.1), basis, "piano_"+side)
		_fingers(driver, side, finger_map)

	for side: String in ["Left", "Right"]:
		var x := .15 if side == "Left" else -.09
		var support := piano_frame * Vector3(x, .0 if side == "Left" else .077, -.42)
		_foot(driver, side, support, piano_frame.basis*Vector3.BACK)


func _drums(driver: Node) -> void:
	var body: Skeleton3D = driver.skeleton
	for side: String in ["Left", "Right"]:
		var instrument := "hihat" if side == "Left" else "snare"
		var native := "HiHatUpper" if side == "Left" else "Snare"
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
		var axis_local := Vector3(-.70 if side == "Left" else -.60, -.15, -.8).normalized()
		var axis := kit.global_basis*axis_local
		# On impact the actual visible native tip lands at the exported surface.
		tip -= Vector3.UP*.018*press
		var grip := tip-axis*length
		var basis := _hand_basis(body, side, axis)
		var finger_map := _finger_map(body, side, basis, 58.0)
		var grip_offset := basis * _grip_local(body, side)
		var wrist := grip-body.global_basis*grip_offset
		_limb(driver, side+"Arm", side+"ForeArm", side+"Hand", wrist,
			body.global_position+body.global_basis*Vector3(.34 if side=="Left" else -.34,.20,-.15), basis, "drum_"+side)
		_fingers(driver, side, finger_map)
		var hand := body.get_bone_global_pose(body.find_bone(side+"Hand"))
		var actual_grip := body.global_transform*(hand*_grip_local(body,side))
		var rotation := Basis(Quaternion(native_axis, (kit.global_basis.inverse()*axis).normalized()))
		for draw: Node3D in moving[group]:
			var original: Transform3D = rest_props[draw]
			draw.transform = Transform3D(rotation*original.basis,kit.to_local(actual_grip))

	var kick := float(_event("kick", "right").press)
	var hat := float(_event("hihat", "left").press)
	_move_group("BassPedal",-9.0*kick); _move_group("BassBeater",-12.0*kick); _move_group("HiHatPedal",-9.0*hat)
	for side: String in ["Left", "Right"]:
		var group := "HiHatPedal" if side == "Left" else "BassPedal"
		var amount := hat if side == "Left" else kick
		var pivot := _v(kit_data.pivots[group].position)
		var resting := _v(kit_data.contacts[group].position)
		var support := kit.to_global(pivot+Basis(Vector3.RIGHT,deg_to_rad(-9.0*amount))*(resting-pivot))
		_foot(driver,side,support,kit.global_basis*Vector3.FORWARD)


func _move_group(group: String, degrees: float) -> void:
	var turn := Basis(_v(kit_data.pivots[group].axis),deg_to_rad(degrees))
	for draw: Node3D in moving[group]:
		var original: Transform3D = rest_props[draw]
		draw.transform = Transform3D(turn*original.basis,original.origin)


func _foot(driver: Node, side: String, support: Vector3, forward: Vector3) -> void:
	var body: Skeleton3D = driver.skeleton
	var foot := body.find_bone(side+"Foot")
	var ankle_height := body.get_bone_global_rest(foot).origin.y
	var target := support+Vector3.UP*ankle_height
	var heading := Basis(Vector3.UP,atan2(forward.x,forward.z))
	var basis := body.global_basis.inverse()*heading*body.get_bone_global_rest(foot).basis
	_limb(driver,side+"UpLeg",side+"Leg",side+"Foot",target,
		target+forward*.6+Vector3.UP*.25,basis,"foot_"+side)

## Two-bone analytic IK in skeleton space; no limb scale/stretch. Every joint
## is written once by the contact layer and failures remain visible in report.


func _limb(driver: Node, first: String, middle: String, end: String, world_target: Vector3,
		world_pole: Vector3, end_basis: Basis, label: String) -> void:
	var body: Skeleton3D = driver.skeleton
	var pipe: SkeletonModifier3D = driver.pipeline
	if label.begins_with("drum_"):
		world_pole = body.global_position + body.global_basis * Vector3(.34 if first.begins_with("Left") else -.34, .75, .25)
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
	# Native proof established the index/pinky-derived normal as palm-out.
	# Turn around the long hand axis: piano and matched drum grips palm down.
	return Basis(wanted,PI)*Basis(right,up,wanted)*Basis(across,normal,forward).inverse()*hand.basis


func _grip_local(body: Skeleton3D, side: String) -> Vector3:
	var hand := body.get_bone_global_rest(body.find_bone(side+"Hand"))
	var middle := body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	return hand.affine_inverse()*(hand.origin.lerp(middle,.68))

## Finger transforms relative to a wrist at origin; computed before writing,
## so fingertip targeting needs neither a second skeletal writer nor iteration.


func _finger_map(body: Skeleton3D, side: String, hand_basis: Basis, curl_degrees: float) -> Dictionary:
	var hand := body.find_bone(side+"Hand")
	var result := {hand:Transform3D(hand_basis,Vector3.ZERO)}
	var rest_hand := body.get_bone_global_rest(hand)
	var rest_middle := body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var forward := (hand_basis*(rest_hand.basis.inverse()*(rest_middle-rest_hand.origin))).normalized()
	# Across the hand, not along the resting arm/fingers. Positive rotation
	# bends fingertips towards the floor and closes the grip around the stick.
	var across := (body.global_basis.inverse()*Vector3.UP).cross(forward).normalized()
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
		var pose: Transform3D = finger_map[bone]; pose.origin += origin
		driver.pipeline._write(bone,pose,"contact")


func _contact(identity: String) -> Vector3:
	return kit.to_global(_v(kit_data.contacts[identity].position))


func _v(value: Array) -> Vector3: return Vector3(float(value[0]),float(value[1]),float(value[2]))


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
	if longest<.016 or longest>.04: return {}
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
				if weight<CONTACT_SKIN_WEIGHT or point.z>hip.z or absf(point.x-hip.x)>.16: continue
				if point.y<low:
					low=point.y; witness={"mesh":str(draw.name),"surface":surface,"vertex":vertex,"hips_weight":weight,"rest_point":point}
	if not is_finite(low) or hip.y-low<.015 or hip.y-low>.22: return {}
	return {"hips_above_support":hip.y-low,"support_witness":witness,"rest_hip":hip}


func _note_at(at: float) -> Dictionary:
	var selected:=0
	for index in notes.size():
		if float(notes[index].seconds)<=at+.10: selected=index
		else: break
	var result: Dictionary=notes[selected].duplicate(true)
	result["index"]=selected; result["age"]=at-float(result.seconds)
	result["left_target"]=_bass_left_target(result)
	result["right_target"]=_bass_right_target(result,float(result.age))
	result["pull"]=_bass_pull(float(result.age))
	result["motion_strength"]=sqrt(clampf(float(result.velocity),.12,1.0))
	# Blend the complete trajectories, not just the next string position. The
	# previous note may still be rebounding when a short next note is prepared.
	# Open-string clearance belongs inside this blend too.
	if selected>0 and result.age<0.0:
		var old: Dictionary=notes[selected-1]
		var u:=smoothstep(-.10,0.0,float(result.age))
		var old_age:=at-float(old.seconds)
		result.left_target=_bass_left_target(old).lerp(result.left_target,u)
		result.right_target=_bass_right_target(old,old_age).lerp(result.right_target,u)
		result.pull=lerpf(_bass_pull(old_age),float(result.pull),u)
		result.motion_strength=lerpf(sqrt(clampf(float(old.velocity),.12,1.0)),float(result.motion_strength),u)
	return result


func _bass_left_target(note: Dictionary) -> Vector3:
	var target:=_string_point(int(note.string),maxf(.025,float(note.stop)))
	if int(note.semitones)==0: target+=bass.global_basis*Vector3(.025,0,.015)
	return target


func _bass_pull(age: float) -> float:
	if age>=-.09 and age<0.0: return smoothstep(-.09,0.0,age)
	if age>=0.0 and age<.16: return 1.0-smoothstep(.015,.16,age)
	return 0.0


func _bass_right_target(note: Dictionary,age: float) -> Vector3:
	var target:=_string_point(int(note.string),PLUCK_POSITION)
	var strength:=sqrt(clampf(float(note.velocity),.12,1.0))
	var follow:=0.0
	if age>=0.0:
		follow=(.018+.007*strength)*smoothstep(0.0,.045,age)*(1.0-smoothstep(.045,.17,age))
	var idle:=smoothstep(.17,.45,age) if age>=0.0 else 1.0-smoothstep(-.10,0.0,age)
	# Both clearance curves are zero at the acoustic attack. Released/resting
	# fingers are intentionally off the string, with no binary 14mm jump.
	return target+bass.global_basis*Vector3(follow,0,.018*(1.0-_bass_pull(age))+.014*idle)


func _string_point(index: int, t: float) -> Vector3:
	var string: Dictionary=STRINGS[index]
	return bass.to_global(_v(string.nut).lerp(_v(string.bridge),clampf(t,0.0,1.0)))


func _bass_hand_basis(body: Skeleton3D,side: String,world_forward: Vector3,world_normal: Vector3) -> Basis:
	var hand:=body.get_bone_global_rest(body.find_bone(side+"Hand"))
	var index:=body.get_bone_global_rest(body.find_bone(side+"HandIndex1")).origin
	var pinky:=body.get_bone_global_rest(body.find_bone(side+"HandPinky1")).origin
	var middle:=body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var source_forward:=(middle-hand.origin).normalized()
	var source_across:=(index-pinky).normalized()*(1.0 if side=="Left" else -1.0)
	var source_normal:=source_forward.cross(source_across).normalized();source_across=source_normal.cross(source_forward).normalized()
	var forward:=(body.global_basis.inverse()*world_forward).normalized()
	var normal:=(body.global_basis.inverse()*world_normal).normalized()
	var across:=normal.cross(forward).normalized();normal=forward.cross(across).normalized()
	return Basis(across,normal,forward)*Basis(source_across,source_normal,source_forward).inverse()*hand.basis


func _bass_fingers(body: Skeleton3D,side: String,basis: Basis,world_forward: Vector3,world_normal: Vector3,curl: float) -> Dictionary:
	var hand:=body.find_bone(side+"Hand")
	var result: Dictionary={hand:Transform3D(basis,Vector3.ZERO)}
	var axis:=(body.global_basis.inverse()*(world_forward.cross(world_normal))).normalized()
	for finger: String in ["Thumb","Index","Middle","Ring","Pinky"]:
		for number in range(1,4):
			var bone:=body.find_bone(side+"Hand"+finger+str(number))
			if bone<0: continue
			var parent:=body.get_bone_parent(bone)
			var pose: Transform3D=result.get(parent,Transform3D(basis,Vector3.ZERO))*body.get_bone_rest(bone)
			pose.basis=Basis(axis,deg_to_rad(curl*(.35 if finger=="Thumb" else 1.0)))*pose.basis
			result[bone]=pose
	result.erase(hand);return result


func _play_bass(driver: Node) -> void:
	var body: Skeleton3D=driver.skeleton
	var note:=_note_at(seconds)
	var pull:=float(note.pull)
	for side: String in ["Left","Right"]:
		var target: Vector3
		var forward: Vector3
		var curl: float
		if side=="Left":
			target=note.left_target
			forward=bass.global_basis*Vector3(-1,-.15,-.05).normalized();curl=27.0
		else:
			target=note.right_target
			forward=bass.global_basis*Vector3(.8,-.6,-.05).normalized()
			curl=18.0+pull*16.0*(.75+.25*float(note.motion_strength))
		var normal:=bass.global_basis*Vector3(0,0,-1)
		var basis:=_bass_hand_basis(body,side,forward,normal)
		var finger_map:=_bass_fingers(body,side,basis,forward,normal,curl)
		var terminal:=body.find_bone(side+"HandIndex3")
		var local_tip: Vector3=seated.lily.fingertips[side].bone_local_point
		var relative: Transform3D=finger_map[terminal]
		var wrist:=target-body.global_basis*(relative*local_tip)
		var pole:=player_frame * Vector3(.32 if side=="Left" else -.32,1.12 if side=="Left" else .94,.22)
		_limb(driver,side+"Arm",side+"ForeArm",side+"Hand",wrist,pole,basis,"bass_"+side)
		_fingers(driver,side,finger_map)



func _event(instrument: String, side: String) -> Dictionary:
	var key := instrument + (side if instrument == "piano" else "")
	var rows: Array = attacks.get(key, [])
	var lo := 0
	var hi := rows.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(rows[mid].time) < seconds:
			lo = mid + 1
		else:
			hi = mid
	if rows.is_empty():
		return {"index":0, "press":0.0}
	var next := mini(lo, rows.size() - 1)
	var previous := maxi(lo - 1, 0)
	var index := previous if absf(seconds - float(rows[previous].time)) <= absf(seconds - float(rows[next].time)) else next
	var attack: Dictionary = rows[index]
	var age := seconds - float(attack.time)
	var press := 0.0
	if age >= -.11 and age < 0.0:
		press = smoothstep(-.11, 0.0, age)
	elif age >= 0.0 and age < .16:
		press = 1.0 - smoothstep(.015, .16, age)
	return {"index":attack.index, "press":press if float(attack.strength) > .01 else 0.0}
