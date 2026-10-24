extends RefCounted
## Immutable Blender front frames and their independently retained part stocks.
## The semantic opening, lining, leaf and wall bearing retain their authorities.
const SOURCE := preload("res://assets/props/door_casing_mitres.glb")
var variants: Dictionary={}
var errors: Array[String]=[]

static func key_for(width: float,height: float,service: bool) -> String:
	return "%s%04d_%04d" % ["S" if service else "D",roundi(width*1000.0),roundi(height*1000.0)]

func prepare(layout: Dictionary) -> bool:
	variants.clear();errors.clear()
	var source: Node3D=SOURCE.instantiate()
	for record: Dictionary in layout.doors:
		for service: bool in [false,true]:
			var key:=key_for(float(record.width),float(record.height),service)
			if variants.has(key):continue
			var frame:=source.find_child(key,true,false) as MeshInstance3D
			if frame==null or frame.mesh==null:
				errors.append("missing native miter front frame: "+key);continue
			var parts: Dictionary={}
			for pair: Array in [["FrameLeft","left"],["FrameRight","right"],["FrameHead","head"]]:
				var part:=source.find_child(key+"_"+str(pair[1]),true,false) as MeshInstance3D
				if part==null or part.mesh==null:errors.append("missing native miter part: "+key+"/"+str(pair[0]))
				else:parts[str(pair[0])]=part.mesh
			if parts.size()==3:variants[key]={"mesh":frame.mesh,"parts":parts}
	source.free()
	return errors.is_empty() and not variants.is_empty()

func frame_for(width: float,height: float,service: bool) -> Dictionary:
	return variants.get(key_for(width,height,service),{})
