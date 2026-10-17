extends RefCounted
## Native supports fit the surveyed finished wall, including lobby wainscot.
## The installation datum is checked before accepting the authored brackets.
const PATH := "res://data/orison_v2/radiator_wall_mounts.json"
var facts := {}
var root: Node3D
var errors: Array[String] = []

func configure(building: Node3D) -> void:
    root = building
    var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    for installation: Dictionary in source.installations:
        facts[str(installation.id)] = installation

func fit(radiator: RadiatorProp, anchor: Node3D, _level: String) -> bool:
    var identity := str(anchor.name)
    if not facts.has(identity):
        errors.append("missing surveyed radiator mount " + identity)
        return false
    var source: Dictionary = facts[identity]
    var pose := root.global_transform.affine_inverse()*anchor.global_transform
    var point := Vector3(source.floor_origin[0],source.floor_origin[1],source.floor_origin[2])
    var direction := Basis(Vector3.UP,float(source.yaw)).x
    if source.sections != radiator.section_count or \
            (pose.origin-Vector3.UP*radiator.installation_drop).distance_to(point)>.0001 or \
            pose.basis.x.distance_to(direction)>.0001:
        errors.append("radiator installation changed since native wall survey: " + identity)
        return false
    if source.ties is not Array or source.ties.size()!=2:
        errors.append("radiator needs two surveyed supports: " + identity)
        return false
    for tie: Dictionary in source.ties:
        if tie.column is not Array or tie.column.size()!=3 or not is_finite(float(tie.bracket_z)) or float(tie.bracket_z)<=0.0:
            errors.append("invalid native support position: " + identity)
            return false
        for coordinate: Variant in tie.column:
            if typeof(coordinate) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(coordinate)):
                errors.append("invalid native support coordinate: " + identity)
                return false
        var native_names := RadiatorNativeParts.names("supports")
        if not native_names.has(str(tie.rod)) or not native_names.has(str(tie.hardware)):
            errors.append("unknown native support variant: " + identity)
            return false
    radiator.native_wall_mounts = source.ties.duplicate(true)
    return true

func draw() -> void:
    # Both fixed brackets and sliding rods now belong to each native radiator.
    # No floating legacy rods or global RadiatorTiePlates owner is produced.
    pass
