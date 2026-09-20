extends Node3D
## V2's physical display only. MinaCaseGameplay owns the factual wake binding.
## The display follows the existing refrigerator's moving food door.
var label: Label3D
func _ready() -> void:
	label = Label3D.new()
	label.name = "MinaWakingResidue"
	label.text = "REFRIGERATOR"
	label.font_size = 30
	label.pixel_size = .0022
	label.modulate = Color(.68,.86,.76,.72)
	label.outline_size = 9
	label.outline_modulate = Color(.01,.02,.02,.95)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.no_depth_test = false
	add_child(label)
	RealityState.state_changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	visible = bool(RealityState.case_state(MinaCaptionManifestation.CASE_ID).get("resolved",false)) 		and RealityState.has_waking_residue(MinaCaptionManifestation.RESIDUE_ID)
