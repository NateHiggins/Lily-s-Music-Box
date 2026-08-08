class_name SwcPackageSource
extends RefCounted

## Where a World Package's bytes come from.
##
## A package is a set of package-relative paths and their contents. Whether those
## live in a directory on a developer's disk or inside a single ``.swcpkg`` archive
## shipped to a browser is a delivery detail, and nothing above this class should
## have an opinion about it.
##
## The archive path is not a web workaround. It is how a package would arrive from
## a CDN, and keeping the desktop build on the same interface means the code that
## ships is the code that was tested.

var label: String = ""


static func open(location: String) -> SwcPackageSource:
	if location.get_extension().to_lower() == "swcpkg":
		return ArchivePackageSource.open_archive(location)
	return DirectoryPackageSource.open_directory(location)


func read(_relative_path: String) -> PackedByteArray:
	return PackedByteArray()


func has(_relative_path: String) -> bool:
	return false


func json(relative_path: String) -> Variant:
	return SwcFormats.parse_json_bytes(read(relative_path), "%s!%s" % [label, relative_path])


func reader() -> Callable:
	return func(relative_path: String) -> PackedByteArray: return read(relative_path)


class DirectoryPackageSource:
	extends SwcPackageSource

	var root: String = ""

	static func open_directory(path: String) -> SwcPackageSource:
		var source := DirectoryPackageSource.new()
		source.root = path
		source.label = path
		if not FileAccess.file_exists(path.path_join("manifest.json")):
			push_error("SwcPackageSource: no manifest.json in %s" % path)
			return null
		return source

	func read(relative_path: String) -> PackedByteArray:
		return SwcFormats.read_bytes(root.path_join(relative_path))

	func has(relative_path: String) -> bool:
		return FileAccess.file_exists(root.path_join(relative_path))


class ArchivePackageSource:
	extends SwcPackageSource

	var _zip: ZIPReader = null
	var _names: Dictionary = {}

	static func open_archive(path: String) -> SwcPackageSource:
		var reader := ZIPReader.new()
		if reader.open(path) != OK:
			push_error("SwcPackageSource: cannot open archive %s" % path)
			return null
		var source := ArchivePackageSource.new()
		source._zip = reader
		source.label = path
		for name in reader.get_files():
			source._names[name] = true
		if not source._names.has("manifest.json"):
			push_error("SwcPackageSource: %s contains no manifest.json" % path)
			return null
		return source

	func read(relative_path: String) -> PackedByteArray:
		if not _names.has(relative_path):
			push_error("SwcPackageSource: %s is not in %s" % [relative_path, label])
			return PackedByteArray()
		return _zip.read_file(relative_path)

	func has(relative_path: String) -> bool:
		return _names.has(relative_path)
