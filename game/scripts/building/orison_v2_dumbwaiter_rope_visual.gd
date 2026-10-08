extends Node3D
## Read-only visual followers. The original prop alone owns all travel/state.
var source: DumbwaiterProp
var legs: Array[MeshInstance3D] = []
var hand_return: MeshInstance3D
var endpoints: Array[Vector3] = []

func configure(actor: DumbwaiterProp, unit: Mesh, lower: Mesh) -> void:
	source=actor
	process_priority=1
	for i in 4:
		var draw:=MeshInstance3D.new()
		draw.name=["CarDraftRope","CounterweightDraftRope","HandRopeLeft","HandRopeRight"][i]
		draw.mesh=unit;draw.material_override=actor._rope.material_override
		add_child(draw);legs.append(draw)
	hand_return=MeshInstance3D.new();hand_return.name="HandRopeReturn"
	hand_return.mesh=lower;hand_return.material_override=actor._rope.material_override
	add_child(hand_return)
	actor._rope.visible=false
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var bottom:=source._rope.transform*Vector3(0,-.49,0)
	var center:=Vector3(bottom.x,bottom.y+.099,.375)
	hand_return.position=center
	endpoints=[source._car.position+Vector3(-.179,.15,0),source._counterweight.position+Vector3(0,.12,.013),center+Vector3(-.099,0,0),center+Vector3(.099,0,0)]
	var tops: Array[Vector3]=[Vector3(-.269,.89,.13),Vector3(.23,.89,.13),Vector3(-.269,.89,.375),Vector3(-.071,.89,.375)]
	for i in 4:
		var axis:=tops[i]-endpoints[i]
		legs[i].transform=Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled(Vector3(1,axis.length(),1)),(tops[i]+endpoints[i])*.5)
