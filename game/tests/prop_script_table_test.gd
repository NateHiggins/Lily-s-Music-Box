extends Node
## The prop script table stands apart from either building root (V1
## retirement plan, section 4): V2's prop warehouse builds from it without
## loading the V1 root, and every row is a prop script that instantiates.
const Table := preload("res://scripts/props/prop_script_table.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	_check(Table.TABLE.size() >= 40, "the table holds the prop kinds (%d)" % Table.TABLE.size())
	for kind: String in Table.TABLE:
		var script: Variant = Table.TABLE[kind]
		_check(script is GDScript and (script as GDScript).can_instantiate(), "%s names a prop script" % kind)
	var v2_root := FileAccess.get_file_as_string("res://scripts/building/orison_v2_runtime_root.gd")
	_check(v2_root.contains("prop_script_table.gd") and not v2_root.contains("building_root.gd"),
		"the V2 root reads the table and no longer names the V1 root")
	var warehouse := PropWarehouse.new()
	add_child(warehouse)
	var built: int = warehouse.build(Table.TABLE)
	_check(built > 0 and built >= Table.TABLE.size() - 12, "the prop warehouse builds from the table (%d bays)" % built)
	print("[PROP SCRIPT TABLE] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	warehouse.queue_free()
	get_tree().quit(0 if _fails == 0 else 1)
