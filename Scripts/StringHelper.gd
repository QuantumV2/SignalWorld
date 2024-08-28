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


static func gzip_decode(data):
	return data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
