extends RefCounted
## World-owned retirement of already detached passive geometry. Collision leaves
## the SceneTree immediately; node/resource destruction is spread across frames.
const BUDGET_USEC:=2000
var roots: Array[Node]=[]
var _stack: Array[Node]=[]
var peak_step_ms:=0.
var freed_nodes:=0

func enqueue(root: Node) -> bool:
	if not is_instance_valid(root) or root.get_parent()!=null or root.is_inside_tree() or root in roots:return false
	roots.append(root);_stack.append(root)
	return true

func advance(budget_usec: int=BUDGET_USEC) -> void:
	var started:=Time.get_ticks_usec()
	while not _stack.is_empty():
		var node: Node=_stack.back()
		if node.get_child_count()>0:
			_stack.append(node.get_child(node.get_child_count()-1))
		else:
			_stack.pop_back();roots.erase(node);node.free();freed_nodes+=1
		if Time.get_ticks_usec()-started>=budget_usec:break
	peak_step_ms=maxf(peak_step_ms,(Time.get_ticks_usec()-started)/1000.)

func dispose() -> void:
	_stack.clear()
	while not roots.is_empty():
		var root: Node=roots.pop_back()
		if is_instance_valid(root):root.free()
