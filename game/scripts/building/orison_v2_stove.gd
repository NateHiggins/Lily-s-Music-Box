extends "res://scripts/props/stove_prop.gd"
## Original service/gameplay authority; only native visual stock is substituted.
var native_ready := false

func _build_visual() -> void:
	super._build_visual()
	if has_meta("native_stove_factory"):
		native_ready = get_meta("native_stove_factory").install_on(self)
		remove_meta("native_stove_factory")
