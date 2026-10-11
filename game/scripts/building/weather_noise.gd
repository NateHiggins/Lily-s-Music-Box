extends RefCounted
## Fixed RG8 volume, all 127 slices including the complete 3D mip chain.
static var cached: ImageTexture3D
static func load_volume() -> ImageTexture3D:
	if cached != null: return cached
	var bytes := FileAccess.get_file_as_bytes("res://assets/environment/weather/perlin_worley_64.rg8")
	if bytes.size() != 599186:
		push_error("Weather noise missing or truncated")
		return null
	var images: Array[Image] = []
	var offset := 0
	var size := 64
	while size >= 1:
		for slice in size:
			var length := size*size*2
			images.append(Image.create_from_data(size,size,false,Image.FORMAT_RG8,bytes.slice(offset,offset+length)))
			offset += length
		size /= 2
	var volume := ImageTexture3D.new()
	if volume.create(Image.FORMAT_RG8,64,64,64,true,images) != OK: return null
	cached = volume
	return cached
