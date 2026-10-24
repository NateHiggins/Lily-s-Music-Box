extends Node
## INERT source-state controls; no rendered world or actual-input qualification.
class World extends Node3D:
	var player: Node3D
	var mirror_renderer: Node
class Player extends Node3D:
	var camera: Camera3D
class Mirror extends Node:
	var camera: Camera3D
	var live:=false
	func active_camera() -> Camera3D:return camera if live else null
class Reflections extends Node:
	var positions: Array[Vector3]=[]
	func capture_positions() -> Array[Vector3]:return positions
class Policy extends Node:
	var world: Node3D
	var sources: Array[Dictionary]=[]
	var visible_sources: Array[String]=[]
var checks: Array=[]
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks.append({"label":label,"ok":ok});print("SERVICE DISTANCE: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	var world:=World.new();add_child(world)
	var player:=Player.new();world.player=player;world.add_child(player)
	player.camera=Camera3D.new();player.add_child(player.camera);player.camera.make_current()
	var mirror:=Mirror.new();world.mirror_renderer=mirror;world.add_child(mirror)
	mirror.camera=Camera3D.new();world.add_child(mirror.camera);mirror.camera.position.x=20.;player.camera.make_current()
	var probes:=Reflections.new();probes.name="V2RoomReflections";world.add_child(probes)
	var policy:=Policy.new();policy.world=world;world.add_child(policy)
	for i in range(1,17):
		var light:=OmniLight3D.new();light.position.x=i;light.shadow_enabled=i!=2;light.visible=i!=16;world.add_child(light)
		policy.sources.append({"id":"diagnostic_"+str(i),"light":light,"visible":light.visible,"graph_visible":true})
	var budget:=preload("res://scripts/building/service_light_distance.gd").new(policy)
	budget.set_enabled(true)
	check(policy.visible_sources.size()==7,"main camera retains sources inside eight metres")
	check(not policy.sources[1].light.shadow_enabled,"originally unshadowed source stays unshadowed")
	var switches: int=budget.switches
	for tick in 60:budget.tick()
	check(budget.switches==switches,"stable resting view repeats no source switches")
	policy.sources[3].graph_visible=false;budget.tick()
	check(not policy.sources[3].light.visible,"distance vote never bypasses the existing room graph")
	mirror.live=true;budget.tick()
	check(policy.sources[12].light.visible and policy.sources[12].light.shadow_enabled,"active reflected camera preserves distant illumination and shadows")
	check(not policy.sources[15].light.visible,"reflected camera never enables an originally hidden source")
	mirror.live=false;probes.positions=[Vector3(16,0,0)];budget.tick()
	check(policy.sources[12].light.visible and not policy.sources[12].light.shadow_enabled,"shadowless cube capture preserves illumination without extra shadow work")
	probes.positions.clear();player.camera.position.x=50.;budget.tick()
	check(policy.visible_sources.is_empty(),"actual camera movement controls distance independently of player feet")
	player.camera.position.x=0.;budget.tick()
	check(policy.visible_sources.size()==6,"nearby sources return after camera movement")
	budget.set_enabled(false)
	var restored:=true
	for row: Dictionary in budget.originals:
		var light: Light3D=row.source.light
		restored=restored and light.distance_fade_enabled==row.fade and light.distance_fade_begin==row.begin and light.distance_fade_length==row.length and light.distance_fade_shadow==row.shadow_distance and light.shadow_enabled==row.shadow and light.visible==(row.source.visible and row.source.graph_visible)
	check(restored,"disabling distance policy restores every original light property and graph visibility")
	var real:=preload("res://scripts/building/orison_v2_room_reflections.gd").new();world.add_child(real)
	var probe:=ReflectionProbe.new();real.add_child(probe);probe.position=Vector3(3,2,1);probe.origin_offset=Vector3(.2,.3,.4)
	real.probes.test=probe;real._capture_frames.test=Engine.get_frames_drawn()
	check(real.capture_positions()==[probe.to_global(probe.origin_offset)],"real cube capture exports its transformed optical origin")
	real._capture_frames.test=Engine.get_frames_drawn()-33
	check(real.capture_positions().is_empty(),"finished cube captures stop retaining source illumination")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);FileAccess.open(directory.path_join("state_controls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures},"\t"))
	print("SERVICE DISTANCE BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
