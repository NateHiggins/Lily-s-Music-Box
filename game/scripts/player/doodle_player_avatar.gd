extends Node3D
## Owner-supplied rig is presentation only; the existing controller owns motion.
const LAYER:=1<<15
const MODEL:="res://assets/characters/player_doodle/player_doodle.glb"
var holder: PlayerController
var animator: AnimationPlayer
var skeleton: Skeleton3D
var idle_clip: StringName
var native_ready:=false
var reflected:=false
var _moving:=false

func _ready() -> void:
	set_process(false)
	var model: Node3D=(load(MODEL) as PackedScene).instantiate()
	add_child(model);model.rotation.y=PI
	var finish:=MatLib.get_mat("player_doodle").duplicate() as StandardMaterial3D
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE
	finish.normal_enabled=true;finish.normal_scale=.45
	finish.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.layers=LAYER;draw.material_override=finish
		draw.set_meta("material_key","player_doodle")
	var skeletons:=model.find_children("*","Skeleton3D",true,false)
	var animations:=model.find_children("*","AnimationPlayer",true,false)
	if skeletons.size()!=1 or animations.size()!=1:return
	skeleton=skeletons[0];animator=animations[0]
	# The imported FBX bind vertices and evaluated skin use different axes.
	# Its automatic rest-mesh AABB lies flat at foot level and is culled by
	# the mirror's near plane. Bound the rig in skeleton space once; no scan
	# or mesh skinning on the CPU each frame. Margin covers the round head
	# and the supplied idle's small shifts beyond the resting bone centers.
	var bounds:=AABB(Vector3.ZERO,Vector3.ZERO)
	for index in skeleton.get_bone_count():bounds=bounds.expand(skeleton.get_bone_global_rest(index).origin)
	bounds=bounds.grow(.40)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.custom_aabb=draw.global_transform.affine_inverse()*skeleton.global_transform*bounds
	for clip: StringName in animator.get_animation_list():
		if str(clip).contains("Idle"):idle_clip=clip;break
	if idle_clip.is_empty():return
	animator.get_animation(idle_clip).loop_mode=Animation.LOOP_LINEAR
	animator.play(idle_clip);animator.advance(0);animator.active=false
	holder.camera.cull_mask&=~LAYER
	native_ready=true

func set_reflection_active(enabled: bool) -> void:
	if not native_ready or reflected==enabled:return
	reflected=enabled;animator.active=enabled;set_process(enabled)

func _process(_delta: float) -> void:
	var moving: bool=holder.planar_speed()>.10
	if moving!=_moving:
		_moving=moving
		if moving:animator.pause();animator.seek(0,true)
		else:animator.play(idle_clip)
