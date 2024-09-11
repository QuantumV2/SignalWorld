extends Node
## A thing to handle everything


## The rate at which the cells get updated, default 900
var tick_speed := 15*60
var _tick_counter := 0
## The tick signal, activates when cells get updated
signal tick

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



	
## @experimental
func load_custom_cells(path) -> void :
	var folder = DirAccess.open(path)
	var dirnames = folder.get_directories()
	for name in dirnames:
		var cellinfo = FileAccess.open(path + name + "/" + name + ".json", FileAccess.READ)

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
