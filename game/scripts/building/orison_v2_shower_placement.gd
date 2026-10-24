extends RefCounted
## Installation corrections inside the original wet rooms. Semantic anchors,
## acoustic ids and save identities remain unchanged. Move the complete live
## fixture, including its receptor, collision, rail and valve targets.
const OFFSETS := {
	"F05_5A_SHOWER_01":.08,"F06_6A_SHOWER_01":.08,
	"F03_3D_SHOWER_01":.175,"F04_4D_SHOWER_01":.175,
}
static func local_offset(identity: String) -> Vector3:
	return Vector3(float(OFFSETS.get(identity,0.0)),0,0)
