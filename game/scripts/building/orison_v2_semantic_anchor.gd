class_name OrisonV2SemanticAnchor
extends Marker3D
## Compatibility surface for existing identity-based consumers in the isolated
## v2 slice. It owns no gameplay state; calls are observable adapter receipts.

var console_stage := ""

func set_console_stage(stage: String) -> void:
	console_stage = stage
