extends Node
## A thing to handle everything


var mod_count = 0;
var source_offset = 2;

## The rate at which the cells get updated, default 10
var tick_speed := 10.0:
	set(value):
		if tick_timer:
			tick_timer.set_wait_time(value)
var _tick_counter := 0
## The tick signal, activates when cells get updated
signal tick

const HEADER = 0x53570001

func create_bitmask(num_bits: int) -> int:
	return (1 << num_bits) - 1

func bits_required(value: int) -> int:
	if value == 0:
		return 1  # Special case: 0 requires 1 bit to represent
	
	# Use logarithm base 2 and ceil to get the minimum number of bits
	return int(ceil(log(abs(value) + 1) / log(2)))

## A class to pack and unpack bits



class BitPacker:
	var data = []
	var current_byte = 0
	var bit_position = 0

	func add_bits(value: int, num_bits: int) -> void:
		while num_bits > 0:
			var bits_to_write = min(8 - bit_position, num_bits)
			var mask = (1 << bits_to_write) - 1
			var shifted_value = (value >> (num_bits - bits_to_write)) & mask
			current_byte |= shifted_value << (bit_position)
			bit_position += bits_to_write
			num_bits -= bits_to_write
			if bit_position == 8:
				data.append(current_byte)
				current_byte = 0
				bit_position = 0 

	func get_bytes() -> PackedByteArray:
		var result = PackedByteArray(data)
		if bit_position > 0:
			result.append(current_byte)
		return result

class BitReader:
	var data: PackedByteArray
	var byte_index: int = 0
	var bit_position: int = 0

	func _init(bytes: PackedByteArray):
		data = bytes

	func read_bits(num_bits: int) -> int:
		var result = 0
		var bits_read = 0
		while bits_read < num_bits:
			if byte_index >= data.size():
				break
			var bits_to_read = min(8 - bit_position, num_bits - bits_read)
			var mask = (1 << bits_to_read) - 1
			result |= ((data[byte_index] >> bit_position) & mask) << (num_bits - bits_read - bits_to_read)
			bit_position += bits_to_read
			bits_read += bits_to_read
			if bit_position == 8:
				byte_index += 1
				bit_position = 0
		return result

	static func compress(json_data: Dictionary) -> PackedByteArray:
		var packer = BitPacker.new()
		var cells = json_data['d']
		var grid_size = json_data['s']
		# Add header (big-endian)
		packer.add_bits((HEADER >> 24) & 0xFF, 8)
		packer.add_bits((HEADER >> 16) & 0xFF, 8)

		packer.add_bits((HEADER >> 8) & 0xFF, 8)
		packer.add_bits(HEADER & 0xFF, 8)

		# Add grid size
		encode_varint(packer, grid_size[0])
		encode_varint(packer, grid_size[1])
		cells.sort_custom(sort_cells)

		var prev_x = 0
		var prev_y = 0
		var prev_real_x = 0
		var prev_real_y = 0

		for cell in cells:
			var x = cell[0][0]
			var y = cell[0][1]
			var pos_str = cell[1][0]
			var powered = cell[1][1]
			var rotation = cell[1][2]
			var cell_type = cell[1][3]

		# Parse real coordinates
			var real_coords = pos_str
			var real_x = int(real_coords.x)
			var real_y = int(real_coords.y)

		# Delta encode position
			var dx = x - prev_x
			var dy = y - prev_y
			encode_varint(packer, dx)
			encode_varint(packer, dy)

		# Delta encode real position
			var real_dx = real_x - prev_real_x
			var real_dy = real_y - prev_real_y
			encode_varint(packer, real_dx)
			encode_varint(packer, real_dy)

		# Encode other properties
			#packer.add_bits( ((powered & 0b1111) << 4) | (( (rotation / 90) & 0b00000011 ) << 2)  , 8)
			packer.add_bits(powered & 0b00001111, 4)
			#print("Encoding: ", rotation / 90 & 0b11 )
			packer.add_bits(rotation / 90 & 0b00000011, 2)
			packer.add_bits(0, 2)
			encode_varint(packer, cell_type)

			prev_x = x
			prev_y = y
			prev_real_x = real_x
			prev_real_y = real_y

		return packer.get_bytes()

	static func decompress(compressed_data: PackedByteArray) -> Dictionary:
		var reader = BitReader.new(compressed_data)
		var result = {"d": [], "s": []}

		# Check header (big-endian)
		var header = (reader.read_bits(8) << 24) | (reader.read_bits(8) << 16) | (reader.read_bits(8) << 8) | reader.read_bits(8)
		if header != HEADER:
			printerr("Invalid header")
			return result

		# Read grid size
		result["s"] = [decode_varint(reader), decode_varint(reader)]

		var prev_x = 0
		var prev_y = 0
		var prev_real_x = 0
		var prev_real_y = 0

		while reader.byte_index < compressed_data.size() or reader.bit_position != 0:
			# Delta decode position
			var dx = decode_varint(reader)
			var dy = decode_varint(reader)
			var x = prev_x + dx
			var y = prev_y + dy
			# Delta decode real position
			var real_dx = decode_varint(reader)
			var real_dy = decode_varint(reader)
			var real_x = prev_real_x + real_dx
			var real_y = prev_real_y + real_dy

	# Decode other properties
			var powered = reader.read_bits(4)
			#print(powered)
			var rotation = reader.read_bits(2) * 90
			reader.read_bits(2)
			#print("Decoding: ", rotation)
			var cell_type = decode_varint(reader)

	# Construct cell data
			var cell = [
				[x, y],
				[Vector2i(real_x,real_y), powered, rotation, cell_type]
			]
			result["d"].append(cell)

			prev_x = x
			prev_y = y
			prev_real_x = real_x
			prev_real_y = real_y

		return result

	static func encode_varint(packer: BitPacker, value: int) -> void:
		var unsigned_value = (value << 1) ^ (value >> 31)  # zigzag encoding
		while unsigned_value >= 0x80:
			packer.add_bits((unsigned_value & 0x7f) | 0x80, 8)
			unsigned_value >>= 7
		packer.add_bits(unsigned_value, 8)

	static func decode_varint(reader: BitReader) -> int:
		var value = 0
		var shift = 0
		var byte
		while true:
			byte = reader.read_bits(8)
			value |= (byte & 0x7f) << shift
			if (byte & 0x80) == 0:
				break
			shift += 7
		return (value >> 1) ^ -(value & 1)  # zigzag decoding

	static func sort_cells(a, b):
		if a[0][0] != b[0][0]:
			return a[0][0] < b[0][0]
		return a[0][1] < b[0][1]

# Usage
# var json_data = parse_json(json_string)
# var compressed_data = Compressor.compress(json_data)
# var decompressed_data = Compressor.decompress(compressed_data)

# Usage
# var json_data = parse_json(json_string)
# var compressed_data = Compressor.compress(json_data)

## Tile Rotations
enum TileTransform {
	ROTATE_0 = 0,
	ROTATE_90 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	ROTATE_180 = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	ROTATE_270 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
}
const RotationDict : Dictionary = {
	-1:0,
	0: 0,
	90: TileTransform.ROTATE_90,
	180: TileTransform.ROTATE_180,
	270: TileTransform.ROTATE_270,
}

const RotToDeg:Dictionary = {
	0:0,
	1:90,
	2:180,
	3:270,
}
const DegToRot:Dictionary = {
	0:0,
	90:1,
	180:2,
	270:3,
}

const RotationInd:Dictionary  ={
	0: 0,
	1: TileTransform.ROTATE_90,
	2: TileTransform.ROTATE_180,
	3: TileTransform.ROTATE_270,
}

## Cell Types, <[StringName], [int]>
const CellTypes : Dictionary = {
	&"Wire":0,
	&"Generator":1,
	&"AND":2,
	&"Buffer":3,
	&"Detector":4,
	&"Switch":5,
	&"XOR":6,
	&"JumpPad":7,
	&"Blocker":8,
	&"Randomizer":9,
	&"AngledWire":10,
	&"Flow":11,
}

func is_base64_gzip_deflated(base64_string: String) -> bool:
	var decoded = Marshalls.base64_to_raw(base64_string)

	if decoded.size() < 2:
		return false

	return decoded[0] == 0x1F and decoded[1] == 0x8B
	
func array_to_dict_recursive(array) -> Dictionary:
	var dict = {}
	for index in range(len(array)):
		if typeof(array[index]) == TYPE_ARRAY:
			dict[int(index)] = array_to_dict_recursive(array[index])
		else:
			dict[int(index)] = array[index]
	return dict

## Cell's atlas coords on the tilemap
const CellTypesAtlCoords : Dictionary = {
	-1:Vector2i(-1,-1),
	0:Vector2i(0,0),
	1:Vector2i(1,0),
	2:Vector2i(2,0),
	3:Vector2i(3,0),
	4:Vector2i(0,1),
	5:Vector2i(1,1),
	6:Vector2i(2,1),
	7:Vector2i(3,1),
	8:Vector2i(0,2),
	9:Vector2i(1,2),
	10:Vector2i(2,2),
	11:Vector2i(5,1),
}

const PowerTypes : Dictionary = {
	Vector2i(-1,-1):0,
	Vector2i(0,0):1,
	Vector2i(1,0):2,
	Vector2i(2,0):3,
}
## Power Types Atlas Coords
const PowerTypesAtl : Dictionary = {
	-1:Vector2i(-1,-1),
	0:Vector2i(-1,-1),
	1:Vector2i(0,0),
	2:Vector2i(1,0),
	3:Vector2i(2,0),
}

## Get Tile rotation in degrees
func get_tile_data_rotation(alt_tile : int)->int:
	match alt_tile:
		TileTransform.ROTATE_0:
			return 0  # ROTATE_0
		TileTransform.ROTATE_90:
			return 90  # ROTATE_90
		TileTransform.ROTATE_180:
			return 180  # ROTATE_180
		TileTransform.ROTATE_270:
			return 270  # ROTATE_270
		_:
			return -1  # invalid or non-90 degree rotation

func add_custom_cell(name:String, image:Image, behavior: String):
	pass
	

## @experimental
func load_custom_cells(path) -> void :
	var folder = DirAccess.open(path)
	var dirnames = folder.get_directories()
	for _name in dirnames:
		pass
		print(path + _name + "/" + _name + ".json")
		var cellinfofile = FileAccess.open(path + _name + "/" + _name + ".json", FileAccess.READ)
		var cellinfostr = cellinfofile.get_as_text()
		var cellinfo = JSON.parse_string(cellinfostr)
		cellinfofile.close()
		var behaviorfile = FileAccess.open(path + _name + "/behavior.gd", FileAccess.READ)
		var behaviorstr = behaviorfile.get_as_text()
		behaviorfile.close()
		add_custom_cell(cellinfo['name'], cellinfo['image'], behaviorstr)
		print(cellinfo, behaviorstr)
		

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Global.swap_fullscreen_mode()

func swap_fullscreen_mode() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
var tick_timer: Timer

func _ready():
	tick_timer = Timer.new()
	add_child(tick_timer)
	tick_timer.connect("timeout", on_tick)
	tick_timer.set_wait_time(1.0 / tick_speed)
	tick_timer.set_one_shot(false)
	tick_timer.start()

func on_tick():
	tick.emit()
"""func _physics_process(_delta: float) -> void:
	_tick_counter += 60
	if _tick_counter >= tick_speed:
		tick.emit()
		_tick_counter = 0
"""
