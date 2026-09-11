extends MinaCaptionManifestation
## The acoustic graph owns arrivals; this display only places their captions
## on functional subjects that actually exist in the current V2 world.
var adapter: OrisonV2AnchorAdapter
var _last_recurrence := -1

func _ready() -> void:
	RealityState.state_changed.connect(_on_reality_state_changed)
	AcousticGraphData.reality_event.connect(_on_reality_event)
	_apply_state(RealityState.case_state(CASE_ID))

func _apply_state(state: Dictionary) -> void:
	var recurrence := int(state.get("recurrence_count", 0))
	if recurrence != _last_recurrence or str(state.get("stage", "unseen")) in ["unseen", "stabilized", "resolved"]:
		_clear_remote()
	_last_recurrence = recurrence

func _on_reality_event(case_id: String, node_id: String, strength: float,
		recurrence: int) -> void:
	if adapter == null or case_id != CASE_ID:
		return
	if str(RealityState.case_state(CASE_ID).get("stage", "unseen")) in ["unseen", "stabilized", "resolved"]:
		return
	var subject := adapter.resolve(node_id) as FunctionalProp
	if subject == null or _remote_labels.has(node_id):
		return
	# Retain the original thresholds, stable sampling, 48-label cap, words and
	# appearance. Never retain the legacy graph-space position in V2.
	super._on_reality_event(case_id, node_id, strength, recurrence)
	var label := _remote_labels.get(node_id) as Label3D
	if label != null:
		label.reparent(subject, false)
		label.position = Vector3.UP * .72

func _exit_tree() -> void:
	_clear_remote()
