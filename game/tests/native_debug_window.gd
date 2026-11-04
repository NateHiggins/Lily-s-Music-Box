extends SceneTree
## Explicit debug launch only. Retain the native Window and original input path.
## GameBoot applies saved window mode after CLI parsing, so defer this override.
func _init() -> void:
 # Diagnostic process setting only; never change the Windows default or saves.
 var requested: String=OS.get_environment("ORISON_NATIVE_AUDIO_OUTPUT")
 if requested.is_empty():return
 if AudioServer.get_driver_name()!="WASAPI" or not AudioServer.get_output_device_list().has(requested):
  push_error("Requested native-test WASAPI output is unavailable: "+requested)
  quit(2)
  return
 AudioServer.output_device=requested
 print("NATIVE DEBUG AUDIO OUTPUT: ",requested)

func _initialize() -> void:
 call_deferred("_native_fullscreen")

func _native_fullscreen() -> void:
 root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
 root.size = DisplayServer.screen_get_size(root.current_screen)
 await process_frame
 await process_frame
 print("NATIVE DEBUG WINDOW: ", root.get_visible_rect().size, " mode=", root.mode)
