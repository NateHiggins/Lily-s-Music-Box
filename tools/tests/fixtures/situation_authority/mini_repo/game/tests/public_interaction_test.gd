extends Node
## Claims player interaction proof and actually exercises the public
## interaction surface before asserting the consequence.


func _ready() -> void:
	var prop := load_prop()
	var prompt := prop.get_interaction_text()
	assert(not prompt.is_empty())
	prop.interact()
	prop.resolve("player_repair")
