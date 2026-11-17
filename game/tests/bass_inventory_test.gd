extends Node3D
const Native := preload("res://scripts/building/orison_v2_native_domestic_objects.gd")
const Bass := preload("res://scripts/props/inventory_bass_prop.gd")
const CaseView := preload("res://scripts/ui/carried_case_view.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	var output:=OS.get_environment("SHOT_DIR")
	if output.is_empty():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var original: Dictionary=RealityState.data
	var original_path: String=RealityState.save_path
	var original_persistence: bool=RealityState.persistence_enabled
	var original_mouse:=Input.mouse_mode
	var original_write_blocked: bool=RealityState.save_write_blocked
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var inv:=PersonInventory.book()
	check(PersonInventory.valid(inv) and PersonInventory.object_holder()=="lily","bass seeded once in Lily inventory")
	var legacy: Dictionary=inv.duplicate(true)
	legacy.erase(PersonInventory.OBJECTS_VERSION);legacy.holders.lily.erase(PersonInventory.BASS)
	RealityState.data[PersonInventory.KEY]=legacy
	check(PersonInventory.valid(legacy) and PersonInventory.object_holder()=="lily","legacy holdings migrate without a new save domain")
	var invalid: Dictionary=PersonInventory.book().duplicate(true)
	invalid.holders.player[PersonInventory.BASS]=invalid.holders.lily[PersonInventory.BASS].duplicate(true)
	check(not PersonInventory.valid(invalid),"duplicate instrument rejected")
	invalid=PersonInventory.book().duplicate(true);invalid.holders.lily[PersonInventory.BASS].location="moon"
	check(not PersonInventory.valid(invalid),"unknown placement rejected")
	check(not PersonInventory.give("player",PersonInventory.BASS,{"kind":"object"}) and PersonInventory.take("lily",PersonInventory.BASS).is_empty(),"generic give/take cannot duplicate or lose unique object")
	var before_blocked: Dictionary=PersonInventory.book().duplicate(true)
	RealityState.save_write_blocked=true
	check(not PersonInventory.hand_over("lily","player",PersonInventory.BASS) and not PersonInventory.set_object_location("lily","home"),"blocked saves refuse inventory writes")
	check(PersonInventory.book()==before_blocked,"blocked writes preserve inventory exactly")
	RealityState.save_write_blocked=false
	var factory:=Native.new()
	check(factory.prepare(),"actual native source loads")
	var bass:=Bass.new();bass.name="3C_bass";add_child(bass)
	check(factory.mount_on(bass,"3C_bass"),"one original native world projection")
	factory.finish();bass.bind_inventory_placement()
	var identity:=bass.get_instance_id()
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not bass.visible and bass.collision_layer==0 and bass.collision_mask==0,"stored inventory object has no active world display/collision")
	for shape: CollisionShape3D in bass.find_children("*","CollisionShape3D",false,false):check(shape.disabled,"stored collider disabled")
	var player:=PlayerController.new();add_child(player);player.set_process(false);player.set_physics_process(false)
	var view:=CaseView.new();view.player=player;add_child(view)
	view.open_case("lily")
	await get_tree().create_timer(.7).timeout
	check(view.opened and view.inventory_holder=="lily","Lily valise opens")
	var mini:=view._goods.get_node_or_null("InventoryBassPreview")
	check(mini!=null and mini.find_children("*","MeshInstance3D",true,false).size()==7,"valise contains native seven-part bass miniature")
	check(mini!=null and mini.find_children("*","CollisionObject3D",true,false).is_empty() and mini.find_children("*","CollisionShape3D",true,false).is_empty(),"inventory miniature has no physics")
	check(view._papers.is_empty() and view._stacks.is_empty(),"Lily view does not expose player papers or goods")
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image!=null and image.save_png(output.path_join("lily_inventory.png"))==OK,"actual Lily inventory render saved")
	view.close_case();await get_tree().create_timer(.4).timeout
	check(not view.opened and not player.call_locked,"case closes and releases controls")
	check(PersonInventory.hand_over("lily","player",PersonInventory.BASS) and PersonInventory.object_holder()=="player","single atomic inventory handoff")
	check(not PersonInventory.hand_over("lily","player",PersonInventory.BASS),"second handoff refused")
	check(PersonInventory.set_object_location("player","home"),"put down through inventory authority")
	await get_tree().physics_frame;await get_tree().physics_frame
	check(bass.visible and bass.collision_layer==1 and bass.get_instance_id()==identity,"same original world projection returns when placed")
	check(not PersonInventory.hand_over("player","lily",PersonInventory.BASS),"placed object must be stored before handoff")
	check(PersonInventory.set_object_location("player","inventory"),"store without carrying physics")
	RealityState.save_path=output.path_join("inventory_save.json")
	check(RealityState.save_game(),"actual disk save")
	PersonInventory.hand_over("player","lily",PersonInventory.BASS)
	RealityState.load_game()
	check(PersonInventory.object_holder()=="player" and PersonInventory.object_location()=="inventory","actual disk reload restores unique holder and stored state")
	check(bass.get_instance_id()==identity and not bass.visible,"reload projects same live object without duplicate")
	view.queue_free();player.queue_free();bass.queue_free()
	await get_tree().process_frame
	RealityState.data=original;RealityState.save_path=original_path;RealityState.persistence_enabled=original_persistence;RealityState.save_write_blocked=original_write_blocked;Input.mouse_mode=original_mouse
	var result: Dictionary={"evidence_class":"INERT technical diagnostic, not gameplay/art acceptance","status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Inventory ownership/migration, actual disk save/reload, native view with no physics; no stage performance or title Continue proof."}
	FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASS INVENTORY: ",checks," checks / ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
