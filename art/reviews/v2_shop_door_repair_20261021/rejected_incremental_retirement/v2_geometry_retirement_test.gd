extends Node
func _ready() -> void:
	var retire:=preload("res://scripts/building/orison_v2_geometry_retirement.gd").new()
	var root:=Node3D.new();var references: Array[WeakRef]=[weakref(root)]
	for group in 30:
		var parent_node:=Node3D.new();root.add_child(parent_node);references.append(weakref(parent_node))
		for index in 20:
			var draw:=MeshInstance3D.new();draw.mesh=BoxMesh.new();parent_node.add_child(draw);references.append(weakref(draw));references.append(weakref(draw.mesh))
	var in_tree:=Node3D.new();add_child(in_tree)
	var passed:=not retire.enqueue(in_tree) and retire.enqueue(root) and not retire.enqueue(root)
	retire.advance(1)
	passed=passed and is_instance_valid(root) and not root.is_inside_tree() and retire.freed_nodes<631
	for step in 1000:
		retire.advance(1000)
		if retire.roots.is_empty():break
	for reference: WeakRef in references:passed=passed and reference.get_ref()==null
	passed=passed and retire.roots.is_empty() and retire.freed_nodes==631
	var interrupted:=Node3D.new();interrupted.add_child(Node3D.new());var interrupted_ref: WeakRef=weakref(interrupted)
	passed=passed and retire.enqueue(interrupted);retire.advance(1);retire.dispose();passed=passed and interrupted_ref.get_ref()==null and retire.roots.is_empty()
	print("V2 GEOMETRY RETIREMENT: ","PASS" if passed else "FAIL"," freed=",retire.freed_nodes)
	get_tree().quit(0 if passed else 1)
