extends Node
func _ready() -> void:
	var owner_node:=MinaCaptionManifestation.new()
	var retired:=Label3D.new();var live:=Label3D.new()
	owner_node.add_child(live);owner_node._remote_labels={"retired":retired,"live":live}
	retired.free()
	owner_node._clear_remote()
	var passed:=owner_node._remote_labels.is_empty() and live.is_queued_for_deletion()
	owner_node._clear_remote()
	owner_node.free()
	print("V2 CAPTION RETIREMENT: ","PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
