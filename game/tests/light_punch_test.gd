extends Node
## Regression for the retired photographic overlay; intrusion authority remains.
var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	_run()


func _run() -> void:
    var enabled: bool = root.player.lamp_is_enabled()
    _check("no photographic lamp overlay is constructed", root.player._light_mask == null)
    root.player.set_beam_mask_enabled(true)
    root.sanity.intruded.emit("noel_domestic_museum", 4)
    root.sanity.attention_withheld.emit("noel_domestic_museum", 3)
    for frame in 4: await get_tree().process_frame
    _check("intrusions cannot recreate a flare overlay", root.player._light_mask == null)
    _check("intrusions preserve logical lamp authority", root.player.lamp_is_enabled() == enabled)
    _check("no photographic projector is restored", root.player.flashlight.light_projector == null)
    print("[PUNCH] RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
    get_tree().quit(_fails)
