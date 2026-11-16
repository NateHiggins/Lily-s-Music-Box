@tool
extends EditorPlugin
## Resource import normally replaces glTF/source scripts, and tests are excluded.
## These specific files are also runtime inputs; keep their bytes without changing
## ResourceLoader's imported scenes or weakening existing source-hash validation.
class RuntimeSourceExport extends EditorExportPlugin:
    const TABLES := ["res://data/orison_v2/acoustic_ventilation.json",
        "res://data/orison_v2/acoustic_heating.json", "res://data/orison_v2/acoustic_flue.json"]
    const READERS := ["orison_v2_millwork", "orison_v2_owner_building_finishes",
        "orison_v2_roof_base_flashings", "orison_v2_roof_drainage",
        "orison_v2_roof_service_weathering", "orison_v2_roof_public_weathering"]

    func _get_name() -> String:
        return "OrisonRuntimeSourceBytes"

    func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
        # Android remains a separate qualification track.
        if not features.has("windows") and not features.has("Windows"): return
        var paths := {"res://assets/props/companion_time_register.glb": true,
            "res://assets/props/companion_typing_arm.glb": true}
        for table: String in TABLES:
            var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(table))
            for binding: Dictionary in document.source_bindings:
                paths[str(binding.path)] = true
        var fixture := RegEx.new()
        fixture.compile('res://tests/fixtures/[^"\n]+\\.json')
        for reader: String in READERS:
            var text := FileAccess.get_file_as_string("res://scripts/building/" + reader + ".gd")
            for hit: RegExMatch in fixture.search_all(text): paths[hit.get_string()] = true
        var total := 0
        for path: String in paths:
            if not path.begins_with("res://") or ".." in path or not FileAccess.file_exists(path):
                push_error("Required runtime source bytes missing: " + path)
                continue
            var bytes := FileAccess.get_file_as_bytes(path)
            add_file(path, bytes, false)
            total += bytes.size()
        print("RUNTIME SOURCE BYTES: %d files / %d bytes retained" % [paths.size(), total])

var exporter := RuntimeSourceExport.new()

func _enter_tree() -> void:
    add_export_plugin(exporter)

func _exit_tree() -> void:
    remove_export_plugin(exporter)
