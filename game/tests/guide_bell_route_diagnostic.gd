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
		var x:=float(stair.origin[0]); var z:=float(stair.origin[1]); var width:=float(stair.width)
		var low: float=shell.level_y[stair.from]; var high: float=shell.level_y[stair.to]
		var mid:=low+float(stair.rise)*int(stair.risers_per_flight)
		var run:=float(stair.tread)*int(stair.risers_per_flight)
		var half: MeshInstance3D=shell.get_node(str(stair.id)+"/HalfLanding")
		var turn:=half.position.z+half.mesh.get_aabb().end.z-.32
		var a:=x+width*.5; var b:=x+width*1.5+float(stair.gap)
		var points: Array[Vector3]=[Vector3(a,low,z-.25),Vector3(a,low,z),Vector3(a,mid,z+run),Vector3(a,mid,turn),Vector3(b,mid,turn),Vector3(b,mid,z+run+float(stair.landing_depth)),Vector3(b,high,z+float(stair.landing_depth)),Vector3(b,high,z-.25)]
		for i in points.size():
			points[i]=shell.to_global(points[i])+Vector3.UP*.035
		for i in range(points.size()-1):
			var okay: bool=provider.supported(points[i],points[i+1])
			results.append({"leg":i,"from":points[i],"to":points[i+1],"ok":okay,"failure":provider.last_rejection.duplicate()})
		var route: PackedVector3Array=provider.request(points[0],points[-1])
		results.append({"path":route,"last_failure":provider.last_rejection})
	print("GUIDE STAIR DIAGNOSTICS ",JSON.stringify(results))
	get_tree().quit()
