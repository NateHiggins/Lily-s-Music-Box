extends RefCounted
## A carried emitter beside the eye, converging on the viewed work. Scene
## collision retracts the source before a wall can swallow it. No light,
## electrical, inspection-camera or interaction authority is created here.
const ORIGIN := Vector3(.16,-.12,-.06)
const CLEARANCE := .018
var _sphere:=SphereShape3D.new()
var _query:=PhysicsShapeQueryParameters3D.new()
var _aim:=PhysicsRayQueryParameters3D.new()
var last_fraction:=1.
var last_focus:=1.6
func _init() -> void:
	_sphere.radius=CLEARANCE;_query.shape=_sphere;_query.collision_mask=1;_query.margin=.001
	_aim.collision_mask=1
func resolve(player: CharacterBody3D,desired: Transform3D) -> Transform3D:
	var camera: Camera3D=player.get("camera")
	var eye: Transform3D=camera.global_transform
	var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
	_aim.from=eye.origin;_aim.to=eye.origin-eye.basis.z*1.6;_aim.exclude=[player.get_rid()]
	var hit: Dictionary=space.intersect_ray(_aim)
	last_focus=clampf(eye.origin.distance_to(hit.position),.12,1.6) if not hit.is_empty() else 1.6
	# Close work progressively raises the hand toward the eye. At ordinary
	# distance retain the sideways light that describes relief and bevels.
	var reach: float=smoothstep(.12,.65,last_focus)
	var offset: Vector3=(desired.origin-eye.origin)*lerpf(.15,1.,reach)
	_query.transform=Transform3D(Basis.IDENTITY,eye.origin);_query.motion=offset;_query.exclude=[player.get_rid()]
	var sweep: PackedFloat32Array=space.cast_motion(_query)
	last_fraction=clampf(sweep[0]-.01,0.,1.) if sweep[0]<1. else 1.
	var origin: Vector3=eye.origin+offset*last_fraction
	var target: Vector3=eye.origin-eye.basis.z*last_focus
	return Transform3D(Basis.looking_at(target-origin,eye.basis.y),origin)
