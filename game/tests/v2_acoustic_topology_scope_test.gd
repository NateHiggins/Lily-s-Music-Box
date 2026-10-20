extends Node
## Isolated propagation-owner lifecycle test, not a building/listening receipt.
const Graph := preload("res://scripts/audio/acoustic_graph.gd")
var checks := 0
var failures := 0
class MusicWorld:
	extends Node
	var player: Node3D

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("ACOUSTIC SCOPE CHECK: ",label," = ",ok)

func _fixture() -> Dictionary:
	var out := {}
	for id: String in ["a","b","c"]:
		out[id]={"id":id,"pos":[0,0,0],"room":id,"network":"ventilation",
			"delay_ms":80,"damping":.1,"connections":[]}
	out.a.connections=["b"];out.b.connections=["a"]
	return out

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var graph := Graph.new()
	add_child(graph)
	var original := _fixture()
	graph.nodes.clear();graph.nodes.merge(original.duplicate(true))
	var public_dictionary: Dictionary=graph.nodes
	var previous := graph.audibility("a")
	_check(previous.size()==2 and previous[1].id=="b","original authored propagation")
	var changed := original.duplicate(true)
	changed.a.connections=["c"];changed.b.connections=[];changed.c.connections=["a"]
	var lease := graph.push_topology(changed)
	_check(lease>0 and graph.nodes==changed,"topology installed by original owner")
	_check(is_same(public_dictionary,graph.nodes),"public dictionary identity retained")
	_check(graph.audibility("a").size()==2 and graph.audibility("a")[1].id=="c","old cached route cannot survive topology swap")
	changed.a.connections=[]
	_check(graph.nodes.a.connections==["c"],"scope owns a copy of caller input")
	_check(graph.release_topology(lease) and graph.nodes==original,"exact original topology restored")
	_check(graph.audibility("a")==previous,"original delay/strength semantics restored")
	_check(not graph.release_topology(lease) and graph.nodes==original,"released token cannot mutate graph")
	var before_epoch: int=graph._topology_epoch
	var bad := original.duplicate(true);bad.a.connections=["missing"]
	_check(graph.push_topology(bad)==0 and graph._topology_epoch==before_epoch and graph.nodes==original,"missing target rejected atomically")
	bad=original.duplicate(true);bad.a.pos=[NAN,0,0]
	_check(graph.push_topology(bad)==0 and graph.nodes==original,"nonfinite position rejected")
	bad=original.duplicate(true);bad.a.damping=1.01
	_check(graph.push_topology(bad)==0,"invalid acoustic tuning rejected")
	bad=original.duplicate(true);bad.a.connections=["b","b"]
	_check(graph.push_topology(bad)==0,"duplicate connection rejected")
	var first := original.duplicate(true);first.a.pos=[1,0,0]
	var second := original.duplicate(true);second.a.pos=[2,0,0]
	var a := graph.push_topology(first);var b := graph.push_topology(second)
	before_epoch=graph._topology_epoch
	_check(graph.release_topology(a) and graph.nodes==second and graph._topology_epoch==before_epoch,"retiring older world preserves live newer scope")
	_check(graph.release_topology(b) and graph.nodes==original and graph._topology_scopes.is_empty(),"last release cannot resurrect retired world")
	a=graph.push_topology(first);b=graph.push_topology(second)
	_check(graph.release_topology(b) and graph.nodes==first,"nested top release restores still-live world")
	_check(graph.release_topology(a) and graph.nodes==original,"nested final release restores base")
	var events: Array=[]
	var reality: Array=[]
	graph.network_event.connect(func(id: String,_index: int,_accent: float,_pitch: float,_strength: float):events.append(id))
	graph.reality_event.connect(func(_case: String,id: String,_strength: float,_recurrence: int):reality.append(id))
	graph.propagate("a",0,1.,1.)
	graph._deliver_reality({"id":"b","delay":.08,"strength":1.},"epoch_fixture",1.,1,graph._topology_epoch)
	a=graph.push_topology(first)
	await get_tree().create_timer(.14).timeout
	_check(events==["a"] and reality.is_empty(),"queued motif and case deliveries cannot enter a new topology")
	events.clear()
	graph.propagate("a",0,1.,1.)
	graph.release_topology(a)
	await get_tree().create_timer(.14).timeout
	_check(events==["a"],"retired scope cannot deliver into restored building")
	events.clear()
	var swapped := [false]
	var tokens: Array[int]=[]
	var reentrant := func(id: String,_index: int,_accent: float,_pitch: float,_strength: float):
		if id=="a" and not swapped[0]:
			swapped[0]=true;tokens.append(graph.push_topology(first))
	graph.network_event.connect(reentrant)
	graph.propagate("a",0,1.,1.)
	await get_tree().create_timer(.14).timeout
	graph.network_event.disconnect(reentrant)
	_check(tokens.size()==1 and events==["a"],"signal callback swap cannot retag remaining old-plan events")
	if not tokens.is_empty():graph.release_topology(tokens[0])
	_check(graph.nodes==original and graph._topology_scopes.is_empty() and graph._topology_base.is_empty(),"all topology ownership retires")
	var transit := original.duplicate(true)
	transit.b.connections=["a","c"];transit.c.connections=["b"]
	transit.b.transit_only=true
	a=graph.push_topology(transit)
	_check(graph.audibility("a").size()==3,"passive junction still carries physical propagation")
	var targets: Array=graph._reality_plan("a",{"carrier":"network","networks":["ventilation"],"limit":2})
	_check(targets.size()==2 and targets[0].id=="a" and targets[1].id=="c","passive junction cannot consume narrative target limit")
	graph.release_topology(a)
	transit.a.pos=[8,0,0];transit.b.pos=[10,0,0];transit.c.pos=[12,0,0]
	var shared_lease := AcousticGraphData.push_topology(transit)
	var arcade := ArcadeRow.new()
	_check(arcade._nearest_graph_node(Vector3(10.1,0,0))=="c","secondary arcade binding ignores nearer passive pipe junction")
	arcade.free()
	var stub := MusicWorld.new();add_child(stub)
	stub.player=Node3D.new();stub.add_child(stub.player)
	var ambient := AmbientSoundscape.new();ambient.player=stub.player;ambient._rng.seed=1928
	var music := OrisonMusicDirector.new();music.world=stub;music._rng.seed=1928
	var physical_only := true
	for sample in 80:
		var ambient_at: Vector3=ambient._architectural_source()
		music._choose_radio_destination(false)
		physical_only=physical_only and ambient_at.x!=10. and music._radio_destination.x!=10.
	_check(physical_only,"ambient and radio directors retain physical sources instead of new pipe junctions")
	ambient.free();music.free();stub.free()
	_check(AcousticGraphData.release_topology(shared_lease),"shared fixture releases the real autoload")
	graph.free()
	print("V2 ACOUSTIC TOPOLOGY SCOPE: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
