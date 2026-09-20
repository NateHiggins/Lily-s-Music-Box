extends Node
func _ready() -> void:
	var directory := "C:/PleaseRemainOnTheLine-astra/design/astra/work/lamp_export_probe/"
	var ok := ProjectSettings.load_resource_pack(directory+"control.pck",true)
	for name in ["lamp_field.compute", "lamp_scene_shadow.compute"]:
		ok = ok and not FileAccess.file_exists("res://shaders/"+name)
	ok = ok and ProjectSettings.load_resource_pack(directory+"candidate.pck",true)
	var expected: Dictionary = {"lamp_field.compute": "61d71766b7f95090169683a1d9ccd162c03312168aa047c664cb0e60f2facac7", "lamp_scene_shadow.compute": "50d6beea028ac5f0c563cbaf251a5e0b84ec92fbc45faf9665f57447720a3235"}
	for name in expected:
		ok = ok and FileAccess.get_sha256("res://shaders/"+name)==expected[name]
	print("PACKED COMPUTE: ","PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
