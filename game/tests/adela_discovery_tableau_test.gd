extends Node3D
## Real imported Adela/static pose on a synthetic plane; lifecycle/shape only.
## Actual yard, nurse contact, native skin sweep and artistic review remain separate.
const Tableau:=preload("res://scripts/characters/adela_discovery_tableau.gd")
class Clock extends Node:
	var minute:=182.0
	func minute_of_day() -> float:return minute
	func day_info() -> Dictionary:return {"year":1929,"month":7,"day_of_month":20}
class Visit extends Node:
	signal changed
	var away:=true
	var anchor: String="stairs"
	var left:=38.0
	var book: Dictionary={"visit":{"left_at":1.0,"loop_started":2.0},"anchors":{"stairs":{"paid":1,"loops":1}}}
	func in_visit() -> bool:return away
	func visit_anchor() -> String:return anchor
	func loop_minutes_left() -> float:return left
	func ledger() -> Dictionary:return book
class Adapter extends RefCounted:
	var root: Node3D
class Dated extends Node:
	var actor: Node3D
class World extends Node3D:
	var startup_ms:=1.0
	var campaign_clock: Node
	var adapter:=Adapter.new()
	var adela_encounters: Node
	var bar_region: Node
var errors: Array[String]=[]
var count:=0
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok:errors.append(label);push_error(label)
func _ready() -> void:
	var info: Dictionary={"year":1929,"month":7,"day_of_month":20}
	for row: Array in [[true,"stairs",181.999,38.0,false],[true,"stairs",182.0,38.0,true],[true,"stairs",219.999,.001,true],[true,"stairs",220.0,.001,false],[false,"stairs",182.0,38.0,false],[true,"button",182.0,38.0,false],[true,"stairs",182.0,0.0,false]]:
		check(Tableau.eligible(row[0],row[1],info,row[2],row[3])==row[4],"exact visit/blackout/expiry boundary "+str(row))
	check(not Tableau.eligible(true,"stairs",{"year":1929,"month":7,"day_of_month":19},182,38),"no body on living date")
	var world:=World.new();add_child(world)
	world.adapter.root=Node3D.new();world.add_child(world.adapter.root)
	var clock:=Clock.new();world.add_child(clock);world.campaign_clock=clock
	var visit:=Visit.new();world.add_child(visit)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8,.10,4);collider.shape=shape;ground.add_child(collider);ground.position=Vector3(-8.5,-.07,12.0);world.add_child(ground)
	for i in 2:await get_tree().physics_frame
	var owner:=Tableau.new();owner.configure(world,visit);world.add_child(owner)
	for i in 2:await get_tree().physics_frame
	check(is_instance_valid(owner.body),"actual Adela import/wardrobe/guard mounts: "+owner.last_refusal)
	if not is_instance_valid(owner.body):get_tree().quit(1);return
	check(owner.body.name=="AdelaHistoricalBody" and owner.is_in_group("adela_discovery_tableau"),"stable read-only proof identity")
	check(owner.body.skeleton.get_bone_count()==76 and owner.skin_nodes().size()>0,"actual rig and visible weighted skin")
	check(not owner.body.is_processing() and not owner.body.attention.pipeline.active and not owner.body._skirt.active and not owner.body.face.is_processing(),"sole frozen pose and no living writers")
	check(owner.body.face.value_of("eyeBlinkLeft")>.99 and owner.body.face.value_of("eyeBlinkRight")>.99,"closed eyes held through existing face writer")
	var bone_snapshot: Array[Transform3D]=[]
	for bone in 76:bone_snapshot.append(owner.body.skeleton.get_bone_global_pose(bone))
	var head: Vector3=owner.head_world()
	for i in 60:await get_tree().process_frame
	var stable:=true
	for bone in 76:stable=stable and bone_snapshot[bone].is_equal_approx(owner.body.skeleton.get_bone_global_pose(bone))
	check(stable and head.is_equal_approx(owner.head_world()),"real imported skeleton remains still across60frames")
	var before: Dictionary=RealityState.data.duplicate(true)
	var old: Node3D=owner.body
	RealityState.data=RealityState.data.duplicate(true);owner.refresh()
	for i in 2:await get_tree().physics_frame
	check(is_instance_valid(owner.body) and (not is_instance_valid(old) or owner.body!=old) and (not is_instance_valid(old) or not old.visible),"same-visit load retires old presentation before replacement")
	check(RealityState.data==before,"presentation writes no campaign flag/inventory")
	visit.away=false;visit.changed.emit()
	check(not is_instance_valid(owner.body) and not is_instance_valid(owner.solid),"home removes body and collider references immediately")
	check(not owner.is_physics_processing() and not owner.is_processing(),"no all-year polling outside stairs")
	for i in 2:await get_tree().physics_frame
	visit.away=true;visit.book.anchors.stairs.loops=2;visit.changed.emit()
	for i in 2:await get_tree().physics_frame
	check(is_instance_valid(owner.body),"earned rerun reconstructs one body")
	var dated:=Dated.new();var living:=Node3D.new();dated.add_child(living);dated.actor=living;world.add_child(dated);world.adela_encounters=dated
	owner.refresh();check(not is_instance_valid(owner.body),"never render duplicate visible living Adela")
	living.hide();owner.refresh()
	for i in 2:await get_tree().physics_frame
	check(is_instance_valid(owner.body),"tableau resumes only after living owner hides")
	clock.minute=220;owner.refresh();check(not is_instance_valid(owner.body),"03:40 retires exact window")
	for i in 2:await get_tree().physics_frame
	ground.queue_free()
	for i in 2:await get_tree().physics_frame
	clock.minute=182;owner.refresh()
	for i in 2:await get_tree().physics_frame
	check(not is_instance_valid(owner.body) and owner.last_refusal.contains("floor"),"missing real support refuses mount")
	print("ADELA TABLEAU: %d checks, %d failures; synthetic floor only"%[count,errors.size()])
	get_tree().quit(0 if errors.is_empty() else 1)
