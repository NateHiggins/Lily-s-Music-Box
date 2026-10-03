extends TapProp
## The retained sink uses its generated primary area. TapProp's area handler
## handles shower curtains, while its existing interact() owns the tap cycle.

func interact_area(area: Area3D) -> void:
	if area.name == "PrimaryInteraction":
		interact(null)
	else:
		super.interact_area(area)
