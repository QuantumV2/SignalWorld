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

static func gzip_encode(text: String, deflate:bool=false):
	var gzip = StreamPeerGZIP.new()
	gzip.start_compression(deflate)
	print(text)
	var data = text.to_utf8_buffer()
	var size = 65535
	for i in range(0, data.size(), size):
		print("meow")
		gzip.put_data(data.slice(i, size))
	gzip.finish()
	return gzip.get_data(gzip.get_available_bytes())[1]

static func gzip_decode(data, deflate:bool=false):
	var gzip = StreamPeerGZIP.new()
	gzip.start_decompression(deflate)
	var size = 65535
	for i in range(0, data.size(), size):
		gzip.put_data(data.slice(i, size))
	gzip.finish()
	return gzip.get_utf8_string(gzip.get_available_bytes())
