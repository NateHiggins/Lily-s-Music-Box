extends Node
## Friends builds have a stable public identity and deterministic user folder.

func _ready() -> void:
	var failures := 0
	var claims := {
		"public product name is canonical": ProjectSettings.get_setting(
				"application/config/name", "") == "Please Remain on the Line",
		"version is explicit": ProjectSettings.get_setting(
				"application/config/version", "") == "0.1.0",
		"user data does not depend on a renamed project": bool(
				ProjectSettings.get_setting(
						"application/config/use_custom_user_dir", false)),
		"user folder is stable ASCII": ProjectSettings.get_setting(
				"application/config/custom_user_dir_name", "") \
				== "PleaseRemainOnTheLine",
	}
	for label in claims:
		if claims[label]:
			print("  PASS  %s" % label)
		else:
			failures += 1
			push_error("  FAIL  %s" % label)
	print("PROJECT IDENTITY TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)
