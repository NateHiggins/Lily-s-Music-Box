extends Node
## Autoload-aware compilation preflight; never instantiate the game world.
func _ready() -> void:
 RealityState.persistence_enabled=false
 var paths: Variant=JSON.parse_string(OS.get_environment("ORISON_SCRIPT_CHECK"))
 if paths is not Array or paths.is_empty():
  push_error("ORISON_SCRIPT_CHECK must be a nonempty JSON array of res:// script paths")
  get_tree().quit(2);return
 var failures:=0
 for path in paths:
  if path is not String or not path.begins_with("res://") or not path.ends_with(".gd") or not ResourceLoader.exists(path):
   print("COMPILE CHECK: invalid path ",path);failures+=1;continue
  var source:=load(path) as GDScript
  var valid:=source!=null and source.can_instantiate()
  print("COMPILE CHECK: ",path," = ",valid)
  if not valid:failures+=1
 print("SCRIPT COMPILATION: ","PASS" if failures==0 else "FAIL","; ",paths.size()," scripts; ",failures," failures; no composed world")
 get_tree().quit(0 if failures==0 else 1)
