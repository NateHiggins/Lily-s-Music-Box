@tool
extends EditorPlugin
## Resource import normally replaces glTF/source scripts, and tests are excluded.
## These specific files are also runtime inputs; keep their bytes without changing
## ResourceLoader's imported scenes or weakening existing source-hash validation.
class RuntimeSourceExport extends EditorExportPlugin:
    const READERS := ["orison_v2_millwork", "orison_v2_owner_building_finishes",
        "orison_v2_roof_base_flashings", "orison_v2_roof_drainage",
        "orison_v2_roof_service_weathering", "orison_v2_roof_public_weathering"]

    func _get_name() -> String:
        return "OrisonRuntimeSourceBytes"

    func _collect_bindings(value: Variant, paths: Dictionary) -> void:
        if value is Dictionary:
            for key: Variant in value:
                var item: Variant = value[key]
                if item is String and item.begins_with("res://") and (
                        value.has(str(key) + "_sha256") or value.has("sha256") or value.has("sha256_lf")):
                    paths[item] = true
                if key == "source_sha256_lf" and item is Dictionary:
                    for source: String in item:
                        paths[source if source.begins_with("res://") else "res://" + source.trim_prefix("game/")] = true
                _collect_bindings(item, paths)
        elif value is Array:
            for item: Variant in value: _collect_bindings(item, paths)

    func _scan_data(directory: String, paths: Dictionary) -> void:
        for filename: String in DirAccess.get_files_at(directory):
            if filename.ends_with(".json"):
                _collect_bindings(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(filename))), paths)
        for child: String in DirAccess.get_directories_at(directory):
            _scan_data(directory.path_join(child), paths)

    func _scan_byte_readers(directory: String, paths: Dictionary, pattern: RegEx) -> void:
        for filename: String in DirAccess.get_files_at(directory):
            if not filename.ends_with(".gd"): continue
            var text := FileAccess.get_file_as_string(directory.path_join(filename))
            if "get_sha256" not in text and "get_file_as_bytes" not in text: continue
            for hit: RegExMatch in pattern.search_all(text):
                var path := hit.get_string()
                if "%" in path: continue # Authored data binds constructed resident paths.
                paths[path] = true
                if path.ends_with(".gltf") and FileAccess.file_exists(path.get_basename() + ".bin"):
                    paths[path.get_basename() + ".bin"] = true
        for child: String in DirAccess.get_directories_at(directory):
            _scan_byte_readers(directory.path_join(child), paths, pattern)

    func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
        # Android remains a separate qualification track.
        if not features.has("windows") and not features.has("Windows"): return
        var paths := {"res://assets/props/companion_time_register.glb": true,
            "res://assets/props/companion_typing_arm.glb": true}
        # Hash-bound source inputs are a runtime dependency, even when imported.
        # Retain only explicit bindings, rather than every source model/media file.
        _scan_data("res://data", paths)
        var byte_asset := RegEx.new()
        byte_asset.compile('res://assets/[^"\'\n]+\\.(glb|gltf|bin)')
        _scan_byte_readers("res://scripts", paths, byte_asset)
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
