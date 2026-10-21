extends Node
## Boolean construction arithmetic and actual shell boxes; no visual grant.
const Shell=preload("res://scripts/building/orison_v2_blockout.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
	print("CONSTRUCTION PRECISION: ",label," = ",ok)
	if not ok:failures+=1
func _ready() -> void:
	var pieces: Array[AABB]=Shell._subtract_box(AABB(Vector3.ZERO,Vector3.ONE),AABB(Vector3(.9999995,.25,.25),Vector3(.2,.5,.5)))
	check(pieces.size()==1,"sub-micrometre overlap never creates flat later-axis fragments")
	check(Shell._subtract_box(AABB(Vector3.ZERO,Vector3(0,1,1)),AABB(Vector3.ONE,Vector3.ONE)).is_empty(),"already collapsed stock is rejected")
	var shell: Node3D=Shell.new();shell.show_clearance_anchors=false;shell.show_reservation_volumes=false
	add_child(shell)
	check(shell.failures.is_empty(),"complete actual source shell builds")
	var count:=0;var invalid: Array[String]=[]
	for shape: CollisionShape3D in shell.find_children("*","CollisionShape3D",true,false):
		if not shape.shape is BoxShape3D:continue
		count+=1
		var size: Vector3=shape.shape.size
		if minf(size.x,minf(size.y,size.z))<=.00001:invalid.append(str(shell.get_path_to(shape)))
	check(count>1000,"all original shell box colliders are inspected")
	check(invalid.is_empty(),"no degenerate collider stocks in actual shell: "+str(invalid))
	shell.free()
	print("V2 CONSTRUCTION PRECISION: ","PASS" if failures==0 else "FAIL"," boxes=",count," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
