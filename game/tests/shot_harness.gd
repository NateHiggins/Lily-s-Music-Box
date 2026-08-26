class_name ShotHarness
extends RefCounted
## Shared contract for new evidence scenes. It does not own scene state or a
## camera; it makes capture timing, output and failure observable.

var host: Node
var tag := "SHOT"
var expected_frames := 0
var budget_seconds := 54.0
var output_dir := ""
var captures: Array[Dictionary] = []
var _started_msec := 0
var _failed := false
const CAPTURE_RESERVE_SECONDS := 0.35
const FINISH_RESERVE_SECONDS := 2.0


func setup(owner: Node, suite_tag: String, expected: int,
		budget := 54.0) -> bool:
	host = owner
	tag = suite_tag
	expected_frames = expected
	budget_seconds = minf(float(budget), 54.0)
	_started_msec = Time.get_ticks_msec()
	output_dir = OS.get_environment("SHOT_DIR")
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		_fail("SHOT_DIR must be an absolute directory")
		return false
	if DisplayServer.get_name() == "headless":
		_fail("capture requires the windowed renderer")
		return false
	var error := DirAccess.make_dir_recursive_absolute(output_dir)
	if error != OK:
		_fail("cannot create output directory: %s" % output_dir)
		return false
	checkpoint("setup")
	return true


func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _started_msec) / 1000.0


func remaining_seconds() -> float:
	return maxf(0.0, budget_seconds - elapsed_seconds())


func checkpoint(label: String) -> void:
	var outstanding := maxi(0, expected_frames - captures.size())
	var reserve := outstanding * CAPTURE_RESERVE_SECONDS \
			+ FINISH_RESERVE_SECONDS
	print("[%s TIMING] stage=%s elapsed=%.3f remaining=%.3f" % [
			tag, label, elapsed_seconds(), remaining_seconds()])
	print("[%s BUDGET] stage=%s outstanding=%d reserve=%.3f slack=%.3f" % [
			tag, label, outstanding, reserve, remaining_seconds() - reserve])


func settle(seconds: float, label := "settle") -> bool:
	if not _can_spend(seconds, label):
		return false
	await host.get_tree().create_timer(seconds, true, false, true).timeout
	checkpoint(label)
	return true


func capture(label: String) -> bool:
	if not _can_spend(0.35, "capture " + label):
		return false
	# Two rendered process frames flush camera/material changes. The post-draw
	# signal then identifies the exact resolved frame copied to CPU.
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	return _write_image(label, image, "rendered")


func capture_frozen_pair(stem: String) -> bool:
	## Writes one resolved image twice. This proves state identity only and must
	## be labelled as such; it is NOT a temporal renderer-noise measurement.
	if not _can_spend(0.35, "frozen pair " + stem):
		return false
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	return _write_image(stem + "_control_a", image, "same_resolved_image") \
			and _write_image(stem + "_control_b", image, "same_resolved_image")


func finish() -> bool:
	var ok := not _failed and captures.size() == expected_frames
	if captures.size() != expected_frames:
		_fail("frame count %d != expected %d" % [captures.size(), expected_frames])
		ok = false
	var receipt := {
		"schema_version": 1,
		"tag": tag,
		"status": "PASS" if ok else "FAIL",
		"elapsed_seconds": elapsed_seconds(),
		"budget_seconds": budget_seconds,
		"expected_frames": expected_frames,
		"actual_frames": captures.size(),
		"captures": captures,
	}
	var path := output_dir.path_join("scene_capture_receipt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write scene receipt")
		ok = false
	else:
		file.store_string(JSON.stringify(receipt, "\t"))
	checkpoint("finish")
	print("[%s] RESULT: %s captures=%d expected=%d elapsed=%.3f" % [
			tag, "PASS" if ok else "FAIL", captures.size(), expected_frames,
			elapsed_seconds()])
	return ok


func _write_image(label: String, image: Image, provenance: String) -> bool:
	if image == null or image.is_empty() or image.get_width() < 2 \
			or image.get_height() < 2:
		_fail("empty viewport image for %s" % label)
		return false
	var path := output_dir.path_join(label + ".png")
	if FileAccess.file_exists(path):
		_fail("refusing to overwrite %s" % path)
		return false
	var error := image.save_png(path)
	if error != OK:
		_fail("save_png %s returned %d" % [path, error])
		return false
	captures.append({
		"label": label,
		"file": label + ".png",
		"width": image.get_width(),
		"height": image.get_height(),
		"elapsed_seconds": elapsed_seconds(),
		"provenance": provenance,
	})
	print("[%s CAPTURE] %d/%d label=%s elapsed=%.3f path=%s" % [
			tag, captures.size(), expected_frames, label, elapsed_seconds(), path])
	return true


func _can_spend(seconds: float, operation: String) -> bool:
	if _failed:
		return false
	if elapsed_seconds() + seconds > budget_seconds:
		_fail("budget refuses %s at %.3f s; %.3f s remain" % [
				operation, elapsed_seconds(), remaining_seconds()])
		return false
	return true


func _fail(message: String) -> void:
	_failed = true
	push_error("[%s CAPTURE FAIL] %s" % [tag, message])
	print("[%s CAPTURE FAIL] %s" % [tag, message])
