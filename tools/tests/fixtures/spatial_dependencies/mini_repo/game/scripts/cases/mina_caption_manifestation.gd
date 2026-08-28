extends Node
## Synthetic stand-in matching a curated KNOWN_CONTRACTS path: the id
## reference below must classify as SAVE_CONTRACT via the override.

const RESIDUE_SOCKET_ID := "1A_FRIDGE_FACE"


func fallback_offset() -> Vector3:
	# Fallback used only when the socket is absent: local presentation
	# offset, must stay OUT of the manifest.
	return Vector3(0.0, 0.75, 0.015)
