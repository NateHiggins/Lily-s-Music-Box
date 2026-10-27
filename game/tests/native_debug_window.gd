extends SceneTree
## Explicit debug launch only. Retain the native Window and original input path.
## GameBoot applies saved window mode after CLI parsing, so defer this override.
func _initialize() -> void:
 call_deferred("_native_fullscreen")

func _native_fullscreen() -> void:
 root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
 root.size = DisplayServer.screen_get_size(root.current_screen)
 await process_frame
 await process_frame
 print("NATIVE DEBUG WINDOW: ", root.get_visible_rect().size, " mode=", root.mode)
