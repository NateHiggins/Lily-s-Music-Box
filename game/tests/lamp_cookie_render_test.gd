extends Node
## Renderer regression: the projector cookie is copied only from a mask frame
## that the SubViewport has completed drawing.

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
	var cookie: ImageTexture = player.get("_cookie")
	var viewport: SubViewport = player.get("_mask_view")
	_check("the first cookie exists only after a rendered frame", cookie != null)
	_check("the production spotlight owns that completed cookie",
			cookie != null and player.flashlight.light_projector == cookie)
	_check("the mask target is never left continuously sampling",
			viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS)
	if cookie != null:
		var image := cookie.get_image()
		_check("the completed cookie has the ruled 512-square dimensions",
				image.get_size() == Vector2i(512, 512))
		var centre := image.get_pixel(256, 256).get_luminance()
		var corner := image.get_pixel(8, 8).get_luminance()
		_check("the baked result is a torch pool, bright centre over dark edge",
				centre > corner + 0.20)
	player.set_lamp_enabled(false)
	await get_tree().process_frame
	_check("a disabled lamp cannot retain a projected image",
			player.flashlight.light_projector == null)
	print("[LAMP COOKIE] %s %d/6" % [
			"PASS" if failures == 0 and checks == 6 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 and checks == 6 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LAMP COOKIE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

