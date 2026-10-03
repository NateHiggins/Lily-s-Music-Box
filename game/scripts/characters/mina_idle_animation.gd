extends RefCounted
## Compatibility entry point for the V2 composer and pose review. The calm
## idle is now a supplied clip; never append the retired procedural idle.
static func install(actor: AnimatedResident) -> bool:
	return actor.mina_animation != null
