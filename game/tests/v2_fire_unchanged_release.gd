extends "res://tests/v2_fire_hand_bench.gd"
## INERT actual-input signal/save-owner regression; no world qualification.
const Owner := preload("res://scripts/building/orison_v2_household_state.gd")
class Clock extends Node:
	var phase := .1
	func mechanism_snapshot() -> Dictionary:return {"phase":phase}
	func valid_mechanism(value: Variant) -> bool:
		return value is Dictionary and value.size()==1 and typeof(value.get("phase")) in [TYPE_FLOAT,TYPE_INT] and value.phase>=0. and value.phase<1.
	func restore_mechanism(value: Dictionary) -> void:phase=float(value.phase)
var changes := 0
var release_signals: Array = []
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var ground:=StaticBody3D.new();add_child(ground)
	var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8,.2,8);col.shape=shape;col.position.y=-.1;ground.add_child(col)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-30,0);add_child(sun)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"native fixture mounts"):
		print(native.errors);get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	for ref: WeakRef in native.stations.values():
		var other: Node3D=ref.get_ref()
		if other!=actor:other.free()
	var clock:=Clock.new();add_child(clock)
	var owner:=Owner.new();add_child(owner)
	owner._subjects={"CAB":actor,"CLOCK":clock};owner._kinds={"CAB":"mechanism","CLOCK":"mechanism"}
	var saved: Dictionary=owner.snapshot();owner._defaults=saved.duplicate(true)
	RealityState.data[Owner.KEY]=saved.duplicate(true)
	check(owner.validate(saved,owner._kinds),"real household validator accepts native controls and running clock fixture")
	owner._restore(saved);owner._bound=true
	# Restoring a loose washer legitimately resumes its final support search.
	# Isolate unchanged grips only AFTER that physical motion has settled.
	for frame in 60:await get_tree().physics_frame
	var rest: Transform3D=actor._gasket_body.transform
	await get_tree().physics_frame;await get_tree().physics_frame
	check(actor._gasket_body._support!=null and actor._gasket_body.transform==rest,"loose washer settles on real support before input assertions")
	owner.capture_now();owner.profiling=true
	actor.manipulation_changed.connect(func():
		changes+=1
		release_signals.append({"stack":get_stack(),"door":actor._door_angle,"clock":clock.phase}))
	actor.manipulation_changed.connect(owner._commit_change)
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	var at: Vector3=actor._door_pivot.to_global(Vector3(-.4,.1,.015))
	await aim(at);click()
	check(player._grab.active() and actor._hand=="door","primary input grabs the real door")
	clock.phase=.2;click()
	check(not player._grab.active() and actor._hand.is_empty(),"unchanged second click still releases and cleans up")
	check(changes==0 and owner.profile_causes.is_empty() and RealityState.data[Owner.KEY].records.CLOCK.value.phase==.1 and clock.phase==.2,"unchanged release does not save incidental clock advance or roll it back")
	check(await hand.operate(at,1.78,actor),"actual motion opens and releases the real door")
	print("RELEASE STATE: ",{"changes":changes,"causes":owner.profile_causes.size(),"saved_door":RealityState.data[Owner.KEY].records.CAB.value.door,"live_door":actor._door_angle,"saved_clock":RealityState.data[Owner.KEY].records.CLOCK.value.phase})
	check(changes==1 and owner.profile_causes.size()==1 and RealityState.data[Owner.KEY].records.CAB.value.door==actor._door_angle and RealityState.data[Owner.KEY].records.CLOCK.value.phase==.2,"changed release publishes controls and live clock through the original owner")
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();clock.phase=.3;key(KEY_SPACE)
	check(player.inspecting() and actor._hand.is_empty(),"Space borrows the unchanged tag grip and clears ownership")
	check(changes==1 and RealityState.data[Owner.KEY].records.CLOCK.value.phase==.2,"unchanged inspection entry does not request another save")
	key(KEY_ESCAPE)
	check(owner.capture_now() and RealityState.data[Owner.KEY].records.CLOCK.value.phase==.3,"normal pre-save snapshot still captures live clock movement")
	var out:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":observations,"failures":failures,"changes":changes,"signals":release_signals,"causes":owner.profile_causes},"\t"))
	owner.shutdown();print("FIRE UNCHANGED RELEASE: ","PASS" if failures.is_empty() else "FAIL"," checks=",observations.size())
	get_tree().quit(0 if failures.is_empty() else 1)
