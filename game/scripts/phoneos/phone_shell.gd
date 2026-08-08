extends Node
## Standalone entry point for the handset.
##
## Deliberately thin. Everything the phone is lives in PhoneDevice (the
## object) and PhoneOS (what runs on it), so this scene can be thrown
## away when the phone becomes something the player holds in the
## Orison. Run it on its own with:
##
##   godot --path game res://scenes/phoneos/PhoneShell.tscn

const BACKDROP := Color("0a060c")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var phone := PhoneDevice.new()
	host.add_child(phone)
	# Fit on entry and on every resize, so the handset is whole at any
	# window size instead of running off the bottom.
	phone.fit_into(Vector2(get_viewport().get_visible_rect().size))
	get_viewport().size_changed.connect(func():
		phone.fit_into(Vector2(get_viewport().get_visible_rect().size)))
