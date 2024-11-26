extends Node
## A thing to handle everything


var mod_count = 0; 
var source_offset = 2;

## The rate at which the cells get updated, default 900
var tick_speed := 15*60
var _tick_counter := 0
## The tick signal, activates when cells get updated
signal tick

func create_bitmask(num_bits: int) -> int:
	return (1 << num_bits) - 1

func bits_required(value: int) -> int:
	if value == 0:
		return 1  # Special case: 0 requires 1 bit to represent
	
	# Use logarithm base 2 and ceil to get the minimum number of bits
	return int(ceil(log(abs(value) + 1) / log(2)))

## A class to pack and unpack bits
class BitPacker:
	var fields = []
	var total_bits = 0

	func add_field(name: String, bits: int, signed: bool = false):
		fields.append({"name": name, "bits": bits, "shift": total_bits, "signed": signed})
		total_bits += bits

	func pack(values: Dictionary) -> int:
		var result = 0
		for field in fields:
			var value = values[field.name]
			var mask = (1 << field.bits) - 1
			if field.signed and value < 0:
				# Handle negative values for signed fields
				value = (1 << field.bits) + value
			result |= (value & mask) << field.shift
		return result

	func unpack(packed: int) -> Dictionary:
		var result = {}
		for field in fields:
			var mask = (1 << field.bits) - 1
			var value = (packed >> field.shift) & mask
			if field.signed and (value & (1 << (field.bits - 1))):
				# Sign extend for negative values in signed fields
				value -= (1 << field.bits)
			result[field.name] = value
		return result

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

func _physics_process(_delta: float) -> void:
	_tick_counter += 1*60
	if _tick_counter >= tick_speed:
		tick.emit()
		_tick_counter = 0
