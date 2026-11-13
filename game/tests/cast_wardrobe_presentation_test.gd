extends Node
## The rebuilt cast through the presentation, as the game will load them: every person named in
## ORISON_CAST_PEOPLE (default: everyone with a folder under res://assets/characters/cast) is dressed in each
## of their three sets, with and without the outer layer and the hat, and changed from one set to the next.
## Real imported assets; no building, dialogue or saves.
const Presentation := preload("res://scripts/characters/cast_model_presentation.gd")
const BASE := "res://assets/characters/cast"

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CAST WARDROBE: [FAIL] ", text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func _people() -> Array[String]:
	var wanted := OS.get_environment("ORISON_CAST_PEOPLE")
	var people: Array[String] = []
	if not wanted.is_empty():
		for id: String in wanted.split(",", false):
			people.append(id.strip_edges())
		return people
	for folder: String in DirAccess.get_directories_at(BASE):
		if ResourceLoader.exists("%s/%s/%s.gltf" % [BASE, folder, folder]):
			people.append(folder)
	people.sort()
	return people


## The parts of one set, by slot, from the notes beside the model.
func _set_parts(notes: Dictionary, letter: String) -> Dictionary:
	var parts: Dictionary = {}
	for part: String in notes:
		var note: Dictionary = notes[part]
		if str(note.get("set", "")) == letter:
			parts[str(note.get("slot", ""))] = part
	return parts


## What must be mounted when these parts are worn: one part to a slot, less the slots a whole outfit stands for.
func _expected(notes: Dictionary, parts: Array) -> Dictionary:
	var slots: Dictionary = {}
	for part: String in parts:
		slots[str(notes[part].slot)] = part
	for part: String in parts:
		for taken: Variant in (notes[part] as Dictionary).get("replaces", []):
			if str(taken) != str(notes[part].slot):
				slots.erase(str(taken))
	return slots


func run() -> void:
	RealityState.persistence_enabled = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.35, 2)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
	var people := _people()
	check(not people.is_empty(), "at least one rebuilt cast member is installed")
	for id: String in people:
		var source := "%s/%s/%s.gltf" % [BASE, id, id]
		var probe := Presentation.Wardrobe.new()
		probe.person_id = id
		probe.read_wardrobe(source.get_base_dir())
		var notes: Dictionary = probe.notes.duplicate(true)
		check(notes.size() >= 6, id + " owns a wardrobe of parts with notes")
		var actor: Presentation = null
		for letter: String in ["a", "b", "c"]:
			var by_slot := _set_parts(notes, letter)
			var core: Array = []
			for slot: String in ["top", "bottom", "feet"]:
				if by_slot.has(slot):
					core.append(by_slot[slot])
			var full: Array = core.duplicate()
			for slot: String in ["over", "head"]:
				if by_slot.has(slot):
					full.append(by_slot[slot])
			if actor == null:
				actor = Presentation.new()
				actor.name = "Cast_" + id
				actor.configure(id, source, full)
				add_child(actor)
				check(actor.ready_ok and actor.errors.is_empty(), "%s set %s binds body, wardrobe, pose, face and hair: %s" % [id, letter, "; ".join(PackedStringArray(actor.errors))])
				if not actor.ready_ok:
					break
				await frames(4)
				check(actor.skeleton.get_bone_count() == 76, id + " carries the 76-bone skeleton")
				check(actor.model.find_children("Skin_*", "MeshInstance3D", true, false).size() == 8, id + " body partitions retained")
				check(actor.find_children("*", "AnimationPlayer", true, false).is_empty(), id + " no movement graft")
				check(not actor.hair.look.is_empty(), id + " brought a hair look and it was read")
				if not actor.hair.look.is_empty():
					var cards: ShaderMaterial = actor.hair.materials["Hair"]
					check(is_equal_approx(float(cards.get_shader_parameter("roundness")), float(actor.hair.look.roundness)), id + " hair look reaches the card material")
					check(is_equal_approx(float((actor.hair.materials["HairCap"] as ShaderMaterial).get_shader_parameter("cap_feather")), float(actor.hair.look.cap_feather)), id + " hair look reaches the cap material")
					check(is_equal_approx(float(cards.get_shader_parameter("anisotropy")), 0.0) and is_equal_approx(float(cards.get_shader_parameter("normal_depth")), 0.3), id + " reviewed shading settings are set explicitly")
			else:
				check(actor.wear(full), "%s changes into set %s: %s" % [id, letter, "; ".join(PackedStringArray(actor.errors))])
				if not actor.ready_ok:
					break
				await frames(2)
			var expected := _expected(notes, full)
			var mounted := true
			for slot: String in expected:
				mounted = mounted and str(actor.wardrobe.worn.get(slot, "")) == str(expected[slot])
			check(mounted and actor.wardrobe.worn.size() == expected.size(), "%s set %s: exactly the expected slots are mounted (%s)" % [id, letter, str(actor.wardrobe.worn)])
			var hats := actor.model.find_children("HatHair", "MeshInstance3D", true, false)
			var hair := actor.model.find_children("Hair", "MeshInstance3D", true, false)
			if hats.size() == 1 and hair.size() == 1:
				var hatted: bool = expected.has("head")
				check((hats[0] as MeshInstance3D).visible == hatted and (hair[0] as MeshInstance3D).visible != hatted, "%s set %s: hair for a hat shows only under a hat" % [id, letter])
				check((hats[0] as MeshInstance3D).get_surface_override_material(0) == actor.hair.materials["Hair"], id + " hat hair wears the card material")
			for area: String in ["head", "hands", "chest"]:
				var skin := actor.model.find_children("Skin_" + area, "MeshInstance3D", true, false)
				check(skin.size() == 1 and (skin[0] as MeshInstance3D).visible, "%s set %s: %s is never hidden" % [id, letter, area])
			var covered: Dictionary = {}
			for slot: String in expected:
				for area: Variant in (notes[expected[slot]] as Dictionary).get("covers", []):
					covered[str(area)] = true
			var bare: Array = []
			for area: String in Presentation.SKIN_AREAS:
				if area in ["head", "hands"] or not covered.has(area):
					bare.append(area)
			check(actor.wardrobe.bare_parts() == bare, "%s set %s: exactly the uncovered skin shows (%s)" % [id, letter, str(actor.wardrobe.bare_parts())])
			# The same set without its outer layer and hat is still a whole outfit.
			if full.size() > core.size() and not core.is_empty():
				check(actor.wear(core), "%s set %s without outer layer or hat: %s" % [id, letter, "; ".join(PackedStringArray(actor.errors))])
				if not actor.ready_ok:
					break
				check(not actor.wardrobe.worn.has("over") and not actor.wardrobe.worn.has("head"), "%s set %s: the outer layer and hat come off" % [id, letter])
		# Hair dressed for an occasion is headwear that is the hair: with it on, neither the everyday hair nor the
		# hair cut for a hat shows, and the occasion clothes under it are still a whole outfit.
		if actor != null and actor.ready_ok and notes.has("f_head"):
			var occasion := _set_parts(notes, "c")
			var evening: Array = []
			for slot: String in ["top", "bottom", "feet"]:
				if occasion.has(slot):
					evening.append(occasion[slot])
			evening.append("f_head")
			check(str(notes["f_head"].get("slot", "")) == "head" and str(notes["f_head"].get("hair", "")) == "replace", id + " dressed hair is headwear whose note says it is the hair")
			check(actor.wear(evening), "%s dresses the hair for an occasion: %s" % [id, "; ".join(PackedStringArray(actor.errors))])
			if actor.ready_ok:
				await frames(2)
				check(str(actor.wardrobe.worn.get("head", "")) == "f_head", id + " dressed hair is mounted as headwear")
				var shown := false
				for mesh: Node in actor.model.find_children("Hair", "MeshInstance3D", true, false) + actor.model.find_children("HatHair", "MeshInstance3D", true, false):
					shown = shown or (mesh as MeshInstance3D).visible
				check(not shown, id + " with the hair dressed, no other hair shows")
				var back: Array = []
				for slot: String in ["top", "bottom", "feet"]:
					if occasion.has(slot):
						back.append(occasion[slot])
				check(actor.wear(back), id + " lets the dressed hair down again")
				var everyday := actor.model.find_children("Hair", "MeshInstance3D", true, false)
				check(everyday.size() == 1 and (everyday[0] as MeshInstance3D).visible, id + " everyday hair returns when the dressed hair comes off")
		if actor != null and actor.ready_ok:
			actor.set_active(false)
			check(not actor.visible and not actor.hair.motion.active, id + " off shift hides the model and stops the hair reader")
			actor.set_active(true)
			await frames(2)
			check(actor.visible and actor.ready_ok, id + " comes back without a reload")
			# A change that is refused leaves the person as they were: seen, dressed, and still changeable.
			var before: Dictionary = actor.wardrobe.worn.duplicate()
			var before_parts: Array = actor.worn_parts()
			var before_bare: Array = actor.wardrobe.bare_parts()
			var lone: Array = []
			for part: String in notes:
				if str(notes[part].slot) == "top" and (notes[part].get("replaces", []) as Array).is_empty():
					lone = [part]
					break
			for refused: Array in [lone, ["no_such_part"], []]:
				if refused == lone and lone.is_empty():
					continue
				check(not actor.wear(refused) and not actor.last_refusal.is_empty(), "%s refuses %s with a reason" % [id, str(refused)])
				check(actor.ready_ok and actor.visible and actor.errors.is_empty() and actor.wardrobe.worn == before and actor.worn_parts() == before_parts and actor.wardrobe.bare_parts() == before_bare,
						"%s is unchanged after refusing %s" % [id, str(refused)])
			check(actor.wear(before_parts) and actor.last_refusal.is_empty(), id + " can still change clothes after a refusal")
		if actor != null:
			# Half dressed is refused, as it is for the first two people.
			var half := Presentation.new()
			half.report_errors = false
			var top_only: Array = []
			for part: String in notes:
				if str(notes[part].slot) == "top" and (notes[part].get("replaces", []) as Array).is_empty():
					top_only = [part]
					break
			if not top_only.is_empty():
				half.configure(id, source, top_only)
				add_child(half)
				check(not half.ready_ok and not half.visible and half.errors.has("current intake requires top, bottom and feet; partial dress refused"), id + " a top alone is refused")
				half.queue_free()
			actor.queue_free()
			await frames(2)
	print("CAST WARDROBE RESULT: ", checks, " checks / ", failures.size(), " failures")
	print("CAST WARDROBE TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
