extends StaticBody3D
## Interaction surface for the player's mailbox door. The MailBankProp
## owns all the behavior; this body only exists so the player's use-ray
## has something door-sized to hit.


func interact_prompt() -> String:
	return get_parent().interact_prompt()


func interact(player: Node) -> void:
	get_parent().interact(player)
