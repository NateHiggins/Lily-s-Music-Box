extends Area3D
## A small target on the actual valve cap; the shared TapProp owns all flow.
var tap: TapProp
var hot := false

func interact_prompt() -> String:
	var enabled: bool = tap.get_flow_state()["hot" if hot else "cold"]
	return "%s %s water" % ["Turn off" if enabled else "Turn on", "hot" if hot else "cold"]

func interact(_player: Node) -> void:
	var flow := tap.get_flow_state()
	if hot:
		tap.set_hot(not bool(flow.hot))
	else:
		tap.set_cold(not bool(flow.cold))
