extends Node
const Millwork=preload("res://scripts/building/orison_v2_millwork.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _ready() -> void:
	RealityState.persistence_enabled=false
	var irrelevant: Array[AABB]=[AABB(Vector3(1,1.64,10),Vector3(1,.02,.2))]
	var whole:=Millwork._profile_sections(Vector2(0,4),1.629,1.671,0,.042,true,irrelevant)
	check(whole.size()==1 and absf(whole[0].size.y-.042)<.00001,"unrelated casing retains a single full native rail")
	var casing:=AABB(Vector3(1,1.64,-.1),Vector3(1,.02,.3))
	var relevant: Array[AABB]=[casing]
	var pieces:=Millwork._profile_sections(Vector2(0,4),1.629,1.671,0,.042,true,relevant)
	var area:=0.0;var full_sides:=0
	for piece: Rect2 in pieces:
		area+=piece.get_area()
		check(not piece.intersects(Rect2(1,1.64,1,.02)),"actual casing area remains empty")
		if absf(piece.size.y-.042)<.00001:full_sides+=1
	check(full_sides==2,"both unaffected sides retain the original bead height")
	check(absf(area-(4*.042-1*.02))<.00001,"clipping preserves the exact intended face area")
	var rotated: Array[AABB]=[AABB(Vector3(-.1,1.64,1),Vector3(.3,.02,1))]
	check(Millwork._profile_sections(Vector2(0,4),1.629,1.671,0,.042,false,rotated)==pieces,"perpendicular wall receives identical clipping")
	check(Millwork._profile_sections(Vector2(.1,0),0,1,0,.04,true,[]).is_empty(),"closed narrow corner emits no negative rectangle")
	var face: Dictionary={"along_x":true,"inward":1.0,"face":0.0,"start":0.0,"finish":2.0,"low":0.0,"high":3.0,"source":"main"}
	var ended: Array[Dictionary]=[{"source":"end","bounds":AABB(Vector3(.9,0,-1),Vector3(.2,3,1))}]
	check(Millwork._exposed_faces([face],ended)==[face],"wall ending behind the face cannot truncate a continuous rail")
	var cap:=face.duplicate();cap.source="end";cap.start=.9;cap.finish=1.1
	var main: Array[Dictionary]=[{"source":"main","bounds":AABB(Vector3(0,0,-.1),Vector3(2,3,.2))}]
	check(Millwork._exposed_faces([cap],main).is_empty(),"embedded wall end does not create a phantom trim return")
	var crossing: Array[Dictionary]=[{"source":"crossing","bounds":AABB(Vector3(.9,0,0),Vector3(.2,3,.5))}]
	var exposed:=Millwork._exposed_faces([face],crossing)
	check(exposed.size()==2 and absf(float(exposed[0].finish)-.9)<.00001 and absf(float(exposed[1].start)-1.1)<.00001,"a real crossing wall still clips the exposed face")
	get_tree().quit(1 if failures else 0)
