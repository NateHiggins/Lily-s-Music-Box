extends Node3D
## Isolated courtesy-policy diagnostic, not composed-world qualification.
const Courtesy := preload("res://scripts/characters/character_squeeze_past.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	print("SQUEEZE: ", label, " = ", value)
	if not value: failures.append(label)
func _ready() -> void:
	RealityState.persistence_enabled = false
	run.call_deferred()
func run() -> void:
	var mover := Node3D.new()
	var peer := Node3D.new()
	var wall := StaticBody3D.new()
	add_child(mover); add_child(peer); add_child(wall)
	peer.add_to_group("animated_residents")
	var courtesy := Courtesy.new()
	check(not courtesy.permits(mover,peer), "first contact yields")
	for i in 100: courtesy.permits(mover,peer)
	check(not courtesy.permits(mover,peer), "repeated queries in one frame do not accelerate timeout")
	for i in int(Engine.physics_ticks_per_second*.9):
		await get_tree().physics_frame
		courtesy.permits(mover,peer)
	check(courtesy.permits(mover,peer), "continuous character blockage permits passage")
	check(not courtesy.permits(mover,wall), "native body never receives permission")
	courtesy.cue(peer)
	courtesy.cue(peer)
	check(courtesy.cue_count==1, "speaker cooldown suppresses repeated cue")
	var second := Courtesy.new()
	second.cue(peer)
	check(second.cue_count==0, "speaker cooldown applies across movers")
	check(peer.get_node_or_null("PassingCourtesy") != null, "authored caption exists")
	for i in 3: await get_tree().physics_frame
	check(not courtesy.permits(mover,peer), "interrupted contact starts fresh yield")
	peer.hide()
	check(not courtesy.permits(mover,peer), "hidden actor cannot grant passage")
	await get_tree().create_timer(2.2).timeout
	check(peer.get_node_or_null("PassingCourtesy")==null, "caption retires after presentation")
	var output := OS.get_environment("ORISON_SQUEEZE_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"diagnostic", "failures":failures, "scope":"courtesy timing and presentation lifecycle only"},"  "))
	get_tree().quit(0 if failures.is_empty() else 1)
