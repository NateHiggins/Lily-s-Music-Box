extends Node
## NPC authority legitimately recording its own perception.

var knowledge := {}


func on_heard_riser_hammer() -> void:
	knowledge.record_fact("npc_knowledge", {"self": "heard_hammer"})
	knowledge.knows = true
