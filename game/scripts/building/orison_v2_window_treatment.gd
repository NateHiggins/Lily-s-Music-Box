extends Node3D
## Independent lift, slat tilt and curtain draw; HouseholdState owns saves.
signal settings_changed
const SOURCE := preload("res://assets/props/window_treatments.glb")
const SHADER := preload("res://shaders/v2_window_stock.gdshader")
const PITCH := .045
const PACKED := .0045
static var meshes: Dictionary = {}
var width := 1.5
var height := 1.7
var style := "plain"
var fabric := "linen"
var tint := Color.WHITE
var raised := .5
var tilt_degrees := 20.0
var curtain_open := .85
var character_note := ""
var _slats: MultiMeshInstance3D
var _bottom: MultiMeshInstance3D
var _cords: MultiMeshInstance3D
var _rungs: MultiMeshInstance3D
var _panels: MultiMeshInstance3D
var _tabs: MultiMeshInstance3D
var _pull: PropControlArea
var _wand: PropControlArea
var _tassel: MultiMeshInstance3D
var _motion: Tween
var _target: Dictionary = {}
var _count := 0
var _drop := 0.0
var _pitch := PITCH

static func material(key: String, color: Color, grain: bool = false,
        cloth: Vector2 = Vector2.ONE) -> ShaderMaterial:
    var base := MatLib.get_mat(key) as StandardMaterial3D
    var result := ShaderMaterial.new();result.shader=SHADER
    result.set_shader_parameter("albedo_tex",base.albedo_texture)
    result.set_shader_parameter("rough_tex",base.roughness_texture)
    result.set_shader_parameter("normal_tex",base.normal_texture)
    result.set_shader_parameter("stock_tint",base.albedo_color*color)
    result.set_shader_parameter("roughness_gain",base.roughness)
    result.set_shader_parameter("meters_per_tile",float(preload("res://scripts/generated/material_sets.gd").SETS[key][3]))
    result.set_shader_parameter("longitudinal_grain",grain)
    result.set_shader_parameter("end_grain",grain)
    result.set_shader_parameter("cloth_metres",cloth)
    return result

func _batch(label: String, mesh_name: String, count: int, finish: Material) -> MultiMeshInstance3D:
    var draw := MultiMeshInstance3D.new();draw.name=label;draw.material_override=finish
    var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
    mm.mesh=meshes[mesh_name];mm.instance_count=count
    draw.multimesh=mm;add_child(draw)
    for i in count:mm.set_instance_custom_data(i,Color(1,1,1,1))
    return draw

func _put(draw: MultiMeshInstance3D, index: int, pose: Transform3D,
        chart: Vector2 = Vector2.ONE) -> void:
    draw.multimesh.set_instance_transform(index,pose)
    draw.multimesh.set_instance_custom_data(index,Color(chart.x,chart.y,1,1))

func _pose(at: Vector3, size: Vector3, angle: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.RIGHT,angle)*Basis.from_scale(size),at)

func _ready() -> void:
    if meshes.is_empty():
        var native := SOURCE.instantiate()
        for draw: MeshInstance3D in native.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
        native.free()
    var wood := material("trim",Color.WHITE,true)
    var thread := material("linen",Color(.75,.71,.61))
    var metal := material("brass_dull",Color(.7,.7,.7))
    var available := height-.309
    _count=maxi(2,ceili(available/PITCH)+1)
    _pitch=available/float(_count-1)
    _slats=_batch("RotatingCrownedSlats","CrownedWoodSlat",_count,wood)
    var head := _batch("HeadRail","HeadRail",1,wood)
    _put(head,0,_pose(Vector3.ZERO,Vector3(width-.06,1,1)),Vector2(width-.06,1))
    _bottom=_batch("MovingBottomRail","BottomRail",1,wood)
    _cords=_batch("LadderAndLiftCords","CordStock",4*(_count+1)+3,thread)
    _rungs=_batch("LadderRungs","LadderRung",2*_count,thread)
    var mounts := _batch("WallBrackets","MountBracket",2,metal)
    for side in 2:_put(mounts,side,_pose(Vector3((side*2-1)*(width*.5-.035),0,-.018),Vector3.ONE))
    var wand := _batch("TiltWand","TiltWand",1,wood)
    _put(wand,0,_pose(Vector3(-width*.43,-.29,.052),Vector3.ONE))
    _tassel=_batch("LiftTassel","CordTassel",1,wood)
    _pull=_control("lift",Vector3(width*.43,-.65,.052),Vector3(.12,.16,.10))
    _wand=_control("tilt",Vector3(-width*.43,-.43,.052),Vector3(.10,.18,.10))
    if style!="bare":
        var rod := _batch("CurtainRod","CurtainRod",1,metal)
        _put(rod,0,_pose(Vector3(0,.10-(height-.16)*.48 if style=="cafe" else .10,.13),Vector3(width+.28,1,1)),Vector2(width+.28,1))
        var supports := _batch("CurtainSupports","CurtainBracket",2,metal)
        for side in 2:_put(supports,side,_pose(Vector3((side*2-1)*(width*.5+.10),.10-(height-.16)*.48 if style=="cafe" else .10,.04),Vector3.ONE))
        var length := height-.16
        if style=="cafe":length*=.52
        _panels=_batch("SewnCurtainPanels","PleatedSewnPanel",2,material(fabric,tint,false,Vector2((width+.24)*.65,length)))
        _tabs=_batch("SewnHangingTabs","SewnTab",16,material(fabric,tint))
        _control("curtain",Vector3(width*.5,.07-(height-.16-length)-length*.5,.17),Vector3(.13,.25,.12))
    _apply();set_process(false)

func _control(id: String, at: Vector3, size: Vector3) -> PropControlArea:
    var area := PropControlArea.new();area.configure(id);area.name=id.capitalize()+"Control"
    var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size;shape.shape=box
    area.position=at;area.add_child(shape);add_child(area);return area

func settings_snapshot() -> Dictionary:
    return _target.duplicate() if not _target.is_empty() else {"raise":raised,"tilt_degrees":tilt_degrees,"curtain_open":curtain_open}

static func valid_settings(value: Variant) -> bool:
    if value is not Dictionary or value.size()!=3:return false
    for key: String in ["raise","tilt_degrees","curtain_open"]:
        if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])):return false
    return float(value.raise)>=0 and float(value.raise)<=1 and absf(float(value.tilt_degrees))<=75 and float(value.curtain_open)>=0 and float(value.curtain_open)<=1

func restore_settings(value: Dictionary) -> void:
    if not valid_settings(value):return
    if _motion!=null and _motion.is_valid():_motion.kill()
    _target.clear()
    raised=float(value.raise);tilt_degrees=float(value.tilt_degrees);curtain_open=float(value.curtain_open)
    if _slats!=null:_apply()

func set_settings(lift: float, angle: float, cloth_open: float, duration: float = .35) -> void:
    if not is_finite(lift) or not is_finite(angle) or not is_finite(cloth_open):return
    if _motion!=null and _motion.is_valid():_motion.kill()
    var from := Vector3(raised,tilt_degrees,curtain_open)
    var to := Vector3(clampf(lift,0,1),clampf(angle,-75,75),clampf(cloth_open,0,1))
    if duration<=0:restore_settings({"raise":to.x,"tilt_degrees":to.y,"curtain_open":to.z});settings_changed.emit();return
    _target={"raise":to.x,"tilt_degrees":to.y,"curtain_open":to.z}
    _motion=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _motion.tween_method(func(t: float):
        var next := from.lerp(to,t);raised=next.x;tilt_degrees=next.y;curtain_open=next.z;_apply(),0.0,1.0,duration)
    _motion.finished.connect(func():_target.clear();settings_changed.emit())
    settings_changed.emit()

func control_prompt(id: String) -> String:
    if RealityState.save_write_blocked:return ""
    match id:
        "lift":return "Adjust blind height"
        "tilt":return "Turn blind slats"
        "curtain":return "Draw curtains" if curtain_open>.5 else "Open curtains"
    return ""

func interact_control(id: String, _actor: Node = null) -> Dictionary:
    if RealityState.save_write_blocked or (_motion!=null and _motion.is_running()):return {}
    match id:
        "lift":set_settings(0 if raised>.9 else minf(1.0,raised+.25),tilt_degrees,curtain_open)
        "tilt":set_settings(raised,-75 if tilt_degrees>60 else tilt_degrees+25,curtain_open)
        "curtain":set_settings(raised,tilt_degrees,0 if curtain_open>.5 else 1)
        _:return {}
    return {"action":"window_treatment","control":id}

func _line(index: int, a: Vector3, b: Vector3) -> void:
    var delta := b-a;var length := maxf(.001,delta.length())
    var rotation := Basis(Quaternion(Vector3.UP,delta.normalized())) if delta.length()>.00001 else Basis.IDENTITY
    _put(_cords,index,Transform3D(rotation*Basis.from_scale(Vector3(1,length,1)),(a+b)*.5),Vector2(1,length))

func _apply() -> void:
    _drop=.055+float(_count-1)*_pitch-raised*float(_count-1)*(_pitch-PACKED)
    var last_points: Array[Vector3]=[]
    for ladder in 2:
        for side in [-1.0,1.0]:last_points.append(Vector3((ladder*2-1)*width*.28,-.026,side*.027))
    for i in _count:
        var nominal := .055+float(i)*_pitch
        var depth := minf(nominal,_drop-float(_count-1-i)*PACKED)
        var next_depth := minf(nominal+_pitch,_drop-float(_count-2-i)*PACKED)
        var packed := depth<nominal-.001 or raised>.999 or (i<_count-1 and next_depth-depth<_pitch-.001)
        var angle := 0.0 if packed else deg_to_rad(tilt_degrees)
        var at := Vector3(0,-depth,0)
        _put(_slats,i,_pose(at,Vector3(width-.09,1,1),angle),Vector2(width-.09,1))
        for ladder in 2:
            var x := (ladder*2-1)*width*.28
            _put(_rungs,i*2+ladder,Transform3D(Basis(Vector3.RIGHT,angle)*Basis(Vector3.UP,PI*.5)*Basis.from_scale(Vector3(.05,1,1)),at+Vector3(x,0,0)),Vector2(.05,1))
            for side in 2:
                var point := at+Vector3(x,0,0)+Basis(Vector3.RIGHT,angle)*Vector3(0,0,(side*2-1)*.027)
                var slot := ladder*2+side
                _line(i*4+slot,last_points[slot],point);last_points[slot]=point
    for slot in 4:_line(_count*4+slot,last_points[slot],Vector3(last_points[slot].x,-_drop-.017,0))
    for i in 2:_line(4*(_count+1)+i,Vector3((i*2-1)*width*.28,-.027,0),Vector3((i*2-1)*width*.28,-_drop-.017,0))
    var pull_length := minf(height-.3,.52+raised*.45)
    _line(4*(_count+1)+2,Vector3(width*.43,-.026,.052),Vector3(width*.43,-pull_length,.052))
    _pull.position.y=-pull_length
    _put(_tassel,0,_pose(Vector3(width*.43,-pull_length,.052),Vector3.ONE))
    _put(_bottom,0,_pose(Vector3(0,-_drop-.017,0),Vector3(width-.09,1,1)),Vector2(width-.09,1))
    if _panels!=null:
        var length := (height-.16)*(.52 if style=="cafe" else 1.0)
        var panel_width := (width+.24)*.5*lerpf(1.02,.26,curtain_open)
        var center := (width+.24)*.5-panel_width*.5
        for side in 2:
            var top := .07-(height-.16-length)
            _put(_panels,side,_pose(Vector3((side*2-1)*center,top,.14),Vector3(panel_width,length,1)))
            for tab in 8:
                var x := (side*2-1)*center+panel_width*(float(tab)/7.0-.5)*.94
                _put(_tabs,side*8+tab,_pose(Vector3(x,top+.020,.14),Vector3.ONE))

func _exit_tree() -> void:
    if _motion!=null and _motion.is_valid():_motion.kill()
