extends Node
## Renderer regression: the service lamp never receives a rendered image.

var checks := 0
var failures := 0


func _ready() -> void:
	print("[LAMP COOKIE] START")
	var player := PlayerController.new()
	add_child(player)
	player.set_lamp_enabled(true)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check("the production spotlight owns no projected image",
			player.flashlight.light_projector == null)
	_check("the lamp still emits its authored spotlight",
			player.flashlight.visible and player.flashlight.light_energy > 0.0)
	_check("the retired cookie viewport does not exist",
			player.find_children("*", "SubViewport", true, false).is_empty())
	player.set_lamp_enabled(false)
	await get_tree().process_frame
	_check("a disabled lamp cannot retain a projected image",
			player.flashlight.light_projector == null)
	player.set_lamp_enabled(true)
	await get_tree().process_frame
	_check("re-enabling the lamp cannot recreate a projector",
			player.flashlight.light_projector == null)
	print("[LAMP COOKIE] %s %d/5" % [
			"PASS" if failures == 0 and checks == 5 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 and checks == 5 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LAMP COOKIE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
