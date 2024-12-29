extends Node2D

@export var grid_color: Color = Color(.6, .6, .6, 1)

var camera: Camera2D
var tilemap: TileMapLayer
var tile_size: Vector2
var viewport_rect: Rect2
var last_camera_position: Vector2
var last_zoom: Vector2


func update_selection_cube():
	if %SelectionStartSprite and %SelectionStartSprite.visible and %SelectionEndSprite.visible:
	
		draw_cube(%SelectionStartSprite.position + Vector2(63,64), %SelectionEndSprite.position + Vector2(63,64), Color.BLUE, Color.ORANGE)
func _ready():
	camera = get_viewport().get_camera_2d()
	tilemap = %CellMap
	tile_size = tilemap.tile_set.tile_size
	viewport_rect = get_viewport_rect()
func draw_cube(top_left: Vector2, bottom_right: Vector2, col1 = Color.WHITE, col2 = Color.WHITE):
	var top_right = Vector2(bottom_right.x, top_left.y)
	var bottom_left = Vector2(top_left.x, bottom_right.y)
	var line_width = 10
	# Front face
	draw_line(top_left, top_right, col1, line_width)
	draw_line(top_left, bottom_left, col1,line_width)
	draw_line(bottom_left, bottom_right, col2,line_width)
	draw_line(top_right, bottom_right, col2,line_width)

func _process(_delta):
	if camera.get_screen_center_position() != last_camera_position or camera.zoom != last_zoom:
		queue_redraw()
		last_camera_position = camera.get_screen_center_position()
		last_zoom = camera.zoom

func _draw():
	if not camera or not tilemap:
		return

	var top_left = (camera.get_screen_center_position() - viewport_rect.size / (2 * camera.zoom))
	var bottom_right = (camera.get_screen_center_position() + viewport_rect.size / (2 * camera.zoom))

	var start_cell = tilemap.local_to_map(top_left) - Vector2i.ONE
	var end_cell = tilemap.local_to_map(bottom_right) + Vector2i.ONE

	var vertical_lines = PackedVector2Array()
	var horizontal_lines = PackedVector2Array()

	for x in range(start_cell.x, end_cell.x + 1):
		var start_pos = tilemap.map_to_local(Vector2i(x, start_cell.y))
		var end_pos = tilemap.map_to_local(Vector2i(x, end_cell.y))
		vertical_lines.append(start_pos)
		vertical_lines.append(end_pos)

	for y in range(start_cell.y, end_cell.y + 1):
		var start_pos = tilemap.map_to_local(Vector2i(start_cell.x, y))
		var end_pos = tilemap.map_to_local(Vector2i(end_cell.x, y))
		horizontal_lines.append(start_pos)
		horizontal_lines.append(end_pos)

	draw_multiline(vertical_lines, grid_color, 5, true)
	draw_multiline(horizontal_lines, grid_color, 5, true)
	update_selection_cube()
	
