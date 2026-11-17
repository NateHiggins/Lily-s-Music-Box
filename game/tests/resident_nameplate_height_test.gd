extends Node3D
## The developer nameplate sits a hand above each resident's own head, on rebuilt and old bodies alike (order
## w9189b10b24ac): the rebuilt cast runs 1.52-1.81 m, and one fixed 1.88 m floated it 35 cm above the shortest.
## Run with ORISON_DEVELOPER_OVERLAYS=1; without it no plate is built and the test says so.

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("NAMEPLATE: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	check(GameBoot.developer_overlays_enabled(), "developer overlays are on for this run")
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CastBodies.LIST_PATH))
	var heights: Array[float] = []
	for id: String in listed.residents:
		var actor := AnimatedResident.new()
		actor.setup(id.capitalize(), id, "", CastBodies.model_for(id))
		actor.externally_driven = true
		add_child(actor)
		await get_tree().process_frame
		var plate: Label3D = actor.get_node_or_null("DeveloperResidentNameplate")
		check(plate != null, "%s has a plate" % id)
		if plate != null:
			var top: float = actor._top_of_body()
			heights.append(plate.position.y)
			check(is_equal_approx(plate.position.y, top + AnimatedResident.NAMEPLATE_GAP), "%s's plate is a hand above the body (%.3f over %.3f)" % [id, plate.position.y, top])
			check(top > 1.4 and top < 2.0, "%s's measured top is a person's height: %.3f" % [id, top])
		print("NAMEPLATE ", id, " plate ", plate.position.y if plate else -1.0)
		actor.queue_free()
		await get_tree().process_frame
	# An old body measures too.
	var old := AnimatedResident.new()
	old.setup("Iris", "iris_bell", "", CastBodies.old_model("iris_bell"))
	old.externally_driven = true
	add_child(old)
	await get_tree().process_frame
	var old_plate: Label3D = old.get_node_or_null("DeveloperResidentNameplate")
	check(old_plate != null and old_plate.position.y > 1.4 and old_plate.position.y < 2.2, "an old body's plate also sits over its head")
	check(heights.size() == 18 and heights.max() - heights.min() > 0.2, "the plates follow the cast's real spread of heights")
	print("NAMEPLATE RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
