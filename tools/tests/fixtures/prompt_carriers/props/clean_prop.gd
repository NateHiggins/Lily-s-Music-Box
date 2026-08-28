extends Node
## Clean semantic prompts: the carrier belongs to the player.


func interact_prompt() -> String:
	if locked:
		return "Enter the apartment"
	if state == 2:
		return "Press the carriage lever"
	return "Open the wardrobe" if closed else "Close the wardrobe"


func control_prompt(control_id: String) -> String:
	if control_id == "valve":
		return "Open the valve"
	return interact_prompt()
