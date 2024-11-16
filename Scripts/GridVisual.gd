extends Node2D

@export var grid_color: Color = Color(.6, .6, .6, 1)

var camera: Camera2D
var tilemap: TileMapLayer
var tile_size: Vector2



func _ready():
	camera = get_viewport().get_camera_2d()
	tilemap = %CellMap
	tile_size = tilemap.tile_set.tile_size

func _process(_delta):
	queue_redraw()

func _draw():
	if not camera or not tilemap:
		return

	var viewport_rect = get_viewport_rect()
	var top_left = (camera.get_screen_center_position() - viewport_rect.size / (camera.zoom))
	var bottom_right = (camera.get_screen_center_position() + viewport_rect.size / (camera.zoom))  

	var start_cell = tilemap.local_to_map(top_left )
	var end_cell = tilemap.local_to_map(bottom_right )

	for x in range(start_cell.x, end_cell.x + 1):
		var start_pos = tilemap.map_to_local(Vector2i(x, start_cell.y))
		var end_pos = tilemap.map_to_local(Vector2i(x, end_cell.y))
		draw_line(start_pos, end_pos, grid_color,5,true)

	for y in range(start_cell.y, end_cell.y + 1):
		var start_pos = tilemap.map_to_local(Vector2i(start_cell.x, y))
		var end_pos = tilemap.map_to_local(Vector2i(end_cell.x, y))
		draw_line(start_pos, end_pos, grid_color,5,true)
