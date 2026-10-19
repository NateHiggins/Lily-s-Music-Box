extends RefCounted
## Observe the real tween; a SceneTreeTimer can expire before tween time catches up.
static func observe(motion: Tween) -> Dictionary:
	var result: Dictionary={"finished":false}
	motion.finished.connect(func():result.finished=true,CONNECT_ONE_SHOT)
	return result

static func wait_for_finish(actor: Node,motion: Tween,observation: Dictionary,tree: SceneTree) -> bool:
	for frame in 120:
		if actor.get("_motion")!=motion:return false
		if observation.finished:return true
		if not motion.is_valid() or not motion.is_running():return false
		await tree.process_frame
	return false
