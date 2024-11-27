extends Node
class_name StringHelper


static func string_to_vector2i(string := "") -> Vector2:
	if string:
		var new_string: String = string
		new_string = new_string.erase(0, 1)
		new_string = new_string.erase(new_string.length() - 1, 1)
		var array: Array = new_string.split(", ")

		return Vector2i(int(array[0]), int(array[1]))

	return Vector2i.ZERO

static func gzip_encode(text: String):
	var data = text.to_utf8_buffer()
	data = data.compress(FileAccess.COMPRESSION_DEFLATE)
	return data

static func is_base64(string: String) -> bool:
	# Check if the string matches the base64 pattern
	var regex = RegEx.new()
	regex.compile("^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)?$")
	
	if not regex.search(string):
		return false
	
	# Check if the length is valid (multiple of 4)
	if string.length() % 4 != 0:
		return false
	
	# Try decoding
	var decoded = Marshalls.base64_to_raw(string)
	
	# If decoding succeeds and the result is not empty, it's valid base64
	return decoded.size() > 0
static func gzip_decode(data):
	return data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
