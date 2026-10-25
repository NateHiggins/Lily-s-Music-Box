extends RefCounted
## Optional provider seam: a model may nominate an authored reply ID only.
## This project has no production LLM transport. Offline replies are immediate.
## Never accept model-authored facts, action instructions, credentials or URLs.
signal selection_ready(request_id: int, line_id: String)

func available() -> bool:
	return false

func request_selection(_request_id: int, _bounded_context: Dictionary, _allowed_ids: Array[String]) -> void:
	pass

func cancel(_request_id: int) -> void:
	pass

static func valid_selection(line_id: String, allowed: Array[String]) -> bool:
	return line_id.length() <= 80 and line_id in allowed
