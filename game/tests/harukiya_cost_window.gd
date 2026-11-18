extends "res://tests/native_debug_window.gd"
## Exact1440p hidden-desktop client without changing display mode or saves.
func _native_fullscreen() -> void:
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_BORDERLESS,true)
	root.size = Vector2i(2560,1440)
	await process_frame
	await process_frame
	print("HARUKIYA COST CLIENT: ",root.get_visible_rect().size," mode=",root.mode," borderless=",root.get_flag(Window.FLAG_BORDERLESS))
