extends Node3D
## V2's small physical parts need sub-millimetre contact tolerance. Scope the
## setting to a live V2 physics space and restore it for the V1 rollback.
const PENETRATION := .0005
static var _leases := {}
var _space: RID

func _ready() -> void:
	_space=get_world_3d().space
	if not _leases.has(_space):
		_leases[_space]={"users":0,"previous":PhysicsServer3D.space_get_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)}
	_leases[_space].users+=1
	PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,PENETRATION)

func _exit_tree() -> void:
	if not _leases.has(_space): return
	_leases[_space].users-=1
	if _leases[_space].users==0:
		PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,_leases[_space].previous)
		_leases.erase(_space)
