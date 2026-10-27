extends RefCounted
## Fixed RG8 volume, all 127 slices including the complete 3D mip chain.
static var cached: ImageTexture3D
static var fluid: Dictionary={}

static func load_fluid() -> Dictionary:
	if not fluid.is_empty():return fluid
	var base := _read_volume("perlin_worley_128.r8",128,1,Image.FORMAT_R8)
	var curl := _read_volume("cloud_curl_32.rgb8",32,3,Image.FORMAT_RGB8)
	if base==null or curl==null:return {}
	fluid={"base":base,"curl":curl}
	return fluid

static func _read_volume(filename: String,extent: int,channels: int,format: Image.Format) -> ImageTexture3D:
	var bytes := FileAccess.get_file_as_bytes("res://assets/environment/weather/"+filename)
	var expected := 0;var size := extent
	while size>=1:
		expected+=size*size*size*channels;size/=2
	if bytes.size()!=expected:
		push_error("Cloud sculpting stock missing or truncated: "+filename);return null
	var images: Array[Image]=[];var offset := 0;size=extent
	while size>=1:
		var length := size*size*channels
		for slice in size:
			images.append(Image.create_from_data(size,size,false,format,bytes.slice(offset,offset+length)))
			offset+=length
		size/=2
	var volume := ImageTexture3D.new()
	return volume if volume.create(format,extent,extent,extent,true,images)==OK else null

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
