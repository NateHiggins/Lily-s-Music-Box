extends Label3D
## Same authored caption/state rules as V1, attached to actual V2 subjects.
var caption_index := 0
func _ready() -> void:
	font_size = 38
	pixel_size = .0025
	outline_modulate = Color(.015,.025,.025,.95)
	outline_size = 10
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	no_depth_test = false
	RealityState.state_changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	var state := RealityState.case_state(MinaCaptionManifestation.CASE_ID)
	visible = state.get("stage","unseen") not in ["unseen","stabilized","resolved"]
	var recurring := int(state.get("recurrence_count",0))>0
	var entry: Dictionary = MinaCaptionManifestation.CAPTIONS[caption_index]
	text = entry.claim if recurring else entry.noun
	modulate = Color(1,.62,.42) if recurring else Color(.82,.96,.88)
