extends RefCounted
## V2's millimetre stock needs contacts finer than the default centimetre allowance.
## The world owns this temporary space setting; explicit V1 retains its defaults.
const ALLOWED_PENETRATION := .00005
var _space := RID()
var _previous := -1.0

func bind(world: World3D) -> bool:
	if world==null or _space.is_valid(): return false
	_space=world.space
	_previous=PhysicsServer3D.space_get_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)
	PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,ALLOWED_PENETRATION)
	if absf(PhysicsServer3D.space_get_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)-ALLOWED_PENETRATION)>.0000001:
		release();return false
	return true

func release() -> void:
	if _space.is_valid() and _previous>=0.:
		PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,_previous)
	_space=RID();_previous=-1.
