extends Node3D
class Fixture:
	extends Node3D
	var layout: Dictionary
	var adapter: Dictionary
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var fixture:=Fixture.new(); add_child(fixture)
	var shell=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.show_clearance_anchors=false
	fixture.add_child(shell)
	fixture.layout=shell.layout; fixture.adapter={"root":shell}
	var player:=CharacterBody3D.new(); fixture.add_child(player)
	for frame in 3: await get_tree().physics_frame
	var provider=preload("res://scripts/dream/critters/guide_bell_route.gd").new()
	provider.setup(fixture,player)
	var results: Array=[]
	for stair: Dictionary in shell.layout.stairs:
		if str(stair.id)!="PRIMARY_F01_F02": continue
		var points: Array[Vector3]=provider.stair_points(shell,stair)
		for i in points.size():
			points[i]=shell.to_global(points[i])+Vector3.UP*.035
		for i in range(points.size()-1):
			var okay: bool=provider.supported(points[i],points[i+1])
			results.append({"leg":i,"from":points[i],"to":points[i+1],"ok":okay,"failure":provider.last_rejection.duplicate()})
		var route: PackedVector3Array=provider.request(points[0],points[-1])
		results.append({"path":route,"last_failure":provider.last_rejection})
	print("GUIDE STAIR DIAGNOSTICS ",JSON.stringify(results))
	get_tree().quit()
