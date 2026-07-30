extends Node
## Autoload "GameBoot": registers input actions in code so the project file
## stays free of hand-serialized InputEvent blobs.

const ACTIONS := {
	"move_forward": KEY_W, "move_back": KEY_S,
	"move_left": KEY_A, "move_right": KEY_D,
	"run": KEY_SHIFT, "crouch": KEY_C, "jump": KEY_SPACE,
	"interact": KEY_E, "flashlight": KEY_L,
	"noclip": KEY_V, "debug_panel": KEY_F1,
	"intro": KEY_F2,
	"distort_map": KEY_F3,
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = ACTIONS[action]
			InputMap.action_add_event(action, ev)


## Blender (Z-up, Y-north) -> Godot (Y-up, -Z north) via the glTF convention.
static func b2g(p: Array) -> Vector3:
	return Vector3(p[0], p[2], -p[1])
