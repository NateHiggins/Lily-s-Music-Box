extends Node3D
## Loaded recipe dispatch regression; appearance is reviewed separately.
const Entry := preload("res://scripts/building/orison_v2_bar_entry.gd")
var failures: Array[String] = []
var checks := 0
var bar: OrisonV2BarRegion
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	var profile := OS.get_environment("ENTRY_FINISH_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	if not profile.begins_with("C:/ov/reports/harukiya_entry_refurb_20261114/finish_dispatch_") or OS.get_user_data_dir().replace("\\","/").simplify_path() != profile.path_join("PleaseRemainOnTheLine") or output.is_empty():get_tree().quit(2);return
	var original: Dictionary = RealityState.data
	var text := JSON.stringify(original,"",true,true)
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2);return
	var spec: Dictionary = Entry.read_spec()
	var parts: Dictionary = {}
	for row: Dictionary in spec.native_parts + spec.door_parts: parts[str(row.name)] = row
	bar = OrisonV2BarRegion.new(); add_child(bar)
	check(not bar.startup_failed,"actual bar starts")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var families: Dictionary = {}
	var observations: Array = []
	for draw: MeshInstance3D in bar.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("harukiya_entry_part"):continue
		var identity := str(draw.get_meta("harukiya_entry_part"))
		if not parts.has(identity):check(false,"known native entry part "+identity);continue
		var role := str(parts[identity].matkey)
		var mapped: bool = role in ["entry_brick","entry_teal","entry_step","entry_red"]
		var material := draw.get_surface_override_material(0) as ShaderMaterial
		check(material != null,"real layered override "+identity)
		if material == null:continue
		var enabled: bool = material.get_shader_parameter("has_mask_tex") == true
		var amount: Variant = material.get_shader_parameter("mask_amount")
		check(enabled == mapped,"loaded ageing mask only on intended native role "+identity)
		if mapped:
			families[role] = int(families.get(role,0)) + 1
			var mask := material.get_shader_parameter("mask_tex") as Texture2D
			check(mask != null and amount is Vector4 and amount.length() > 0.0,"real mapped mask and nonzero strengths "+identity)
		observations.append({"part":identity,"role":role,"mask_enabled":enabled,"mask_amount":amount})
	for role: String in ["entry_brick","entry_teal","entry_step","entry_red"]:check(int(families.get(role,0))>0,"actual role covered "+role)
	bar.shutdown();bar.free();await get_tree().process_frame
	check(RealityState.end_preview_campaign(self),"preview returned")
	check(is_same(RealityState.data,original) and JSON.stringify(original,"",true,true)==text,"campaign reference/content restored")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("finish_dispatch.json"),FileAccess.WRITE)
	if file == null:get_tree().quit(2);return
	file.store_string(JSON.stringify({"evidence_class":"INERT loaded material diagnostic","checks":checks,"failures":failures,"families":families,"observations":observations},"\t"));file.flush()
	print("ENTRY FINISH DISPATCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() and file.get_error()==OK else 1)
