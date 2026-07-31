class_name BroadcastScreens
extends Node
## One signal, every television in the building.
##
## The reel is built by `art/tools/build_broadcast.py`: six channels fighting
## over the same aerial, with the picture tearing, rolling, ghosting or
## dropping out between them. It is Ogg Theora because that is the only video
## format Godot 4 plays.
##
## Decoded ONCE into a shared SubViewport, whose texture is then handed to
## every screen surface in the building. Fifteen televisions playing fifteen
## copies of the same file would be fifteen video decodes for one picture,
## and this project already runs a per-object light cap that punishes waste.
## It is also the better fiction: every set in the Orison is tuned to the
## same interference because there is only one thing being received.
##
## The screens themselves are boxes in the merged floor meshes carrying the
## `screen` material, so there is no per-television node to attach anything
## to — the material override goes on the whole merged surface and every
## set on that floor lights up together.

const REEL := "res://assets/video/orison_broadcast.ogv"
const SIZE := Vector2i(512, 384)

var enabled := true
var screens := 0

var _viewport: SubViewport
var _video: VideoStreamPlayer
var _material: StandardMaterial3D


var audio: BroadcastAudio


func build(layout: Dictionary, floor_nodes: Dictionary) -> int:
	var stream := load(REEL)
	if stream == null:
		push_warning("broadcast reel missing: %s" % REEL)
		return 0
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	# ALWAYS, not WHEN_VISIBLE: the viewport itself is never on screen, so
	# anything visibility-driven would leave every television frozen on its
	# first frame — which looks exactly like a still texture and would have
	# been very hard to spot as a bug.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_video = VideoStreamPlayer.new()
	_video.stream = stream
	_video.loop = true
	_video.expand = true
	# Anchored to fill, not merely sized: a Control dropped into a bare
	# SubViewport keeps its own layout, and a player that does not fill the
	# viewport renders a picture into one corner of an otherwise black
	# target — which on a television reads as a dead set.
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.size = Vector2(SIZE)
	_video.volume_db = -80.0        # the reel carries no audio; belt and braces
	_viewport.add_child(_video)
	_video.play()

	_material = StandardMaterial3D.new()
	_material.albedo_texture = _viewport.get_texture()
	# Unshaded: a cathode tube emits its own picture and should not be lit by
	# the room, least of all by a LightRig that may have switched this storey
	# off entirely.
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	for fid in floor_nodes:
		screens += _apply(floor_nodes[fid])
	print("[BROADCAST] %d screen surfaces on one decode" % screens)
	# Sound comes from the same place the picture does, so the two cannot be
	# wired up out of step with each other.
	audio = BroadcastAudio.new()
	audio.name = "BroadcastAudio"
	add_child(audio)
	audio.build(layout, _video)
	return screens


## The builder merges by (floor, material), so every television on a storey
## shares one surface named `<floor>_furnish_screen`.
func _apply(node: Node) -> int:
	var found := 0
	if node is MeshInstance3D and str(node.name).contains("furnish_screen"):
		node.material_override = _material
		found += 1
	for child in node.get_children():
		found += _apply(child)
	return found


func set_enabled(on: bool) -> void:
	enabled = on
	if _video == null:
		return
	if on:
		_video.play()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_video.stop()
		# Leave the last frame on the glass rather than clearing to black:
		# a dead set still holds a faint image, and stopping the viewport
		# update is what actually saves the work.
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_playing() -> bool:
	return _video != null and _video.is_playing()


func stats() -> Dictionary:
	return {
		"screens": screens, "playing": is_playing(),
		"at": _video.stream_position if _video else 0.0,
	}
