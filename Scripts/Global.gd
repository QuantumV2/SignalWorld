extends Node
var tick_speed = 15*60
var tick_counter = 0
signal tick

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
const RotationInd:Dictionary  ={
	0: 0,
	1: TileTransform.ROTATE_90,
	2: TileTransform.ROTATE_180,
	3: TileTransform.ROTATE_270,
}
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
const PowerTypesAtl : Dictionary = {
	-1:Vector2i(-1,-1),
	0:Vector2i(-1,-1),
	1:Vector2i(0,0),
	2:Vector2i(1,0),
	3:Vector2i(2,0),
}
func array_to_dict_recursive(array):
	var dict = {}
	for index in range(len(array)):
		if array[index] is Array:
			dict[index] = array_to_dict_recursive(array[index])
		else:
			dict[index] = array[index]
	return dict

func get_tile_data_rotation(alt_tile : int):
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Global.swap_fullscreen_mode()

func swap_fullscreen_mode():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _physics_process(_delta: float) -> void:
	tick_counter += 1*60
	if tick_counter >= tick_speed:
		tick.emit()
		tick_counter = 0
