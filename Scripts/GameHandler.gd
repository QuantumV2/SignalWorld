extends Node

var CellFuncs : Dictionary = {
	Global.CellTypes.Wire: do_wire_cell,
	Global.CellTypes.Generator: do_generator_cell,
	Global.CellTypes.Buffer: do_buffer_cell,
	Global.CellTypes.JumpPad: do_jumppad_cell,
	Global.CellTypes.Detector: do_detector_cell,
	Global.CellTypes.Randomizer: do_randgenerator_cell,
	Global.CellTypes.Blocker: do_blocker_cell,
	Global.CellTypes.Switch: do_switch_cell,
	Global.CellTypes.AND: do_AND_cell,
	Global.CellTypes.XOR: do_XOR_cell,
}

var paused = false;

func user_place_tile_tilemap(tilemap: TileMapLayer, event: InputEvent, atlas_coords: Vector2i, alt_tile: int, source_id: int = 2):
	var camera_zoom = %Camera2D.zoom
	var event_position = event.position / camera_zoom + %CamOrigin.position - get_viewport().get_visible_rect().size / (2 * camera_zoom)
	var pos = tilemap.local_to_map(tilemap.to_local(event_position))
	
	tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)
	
	curr_grid = create_tilemap_array(%CellMap, %ColorMap)
	next_grid = curr_grid.duplicate(true)
func clear_tilemap():
	curr_grid = [[]]
	next_grid = [[]]
	var rct = %CellMap.get_used_rect()
	for x in rct.size.x:
		for y in rct.size.y:
			%CellMap.set_cell(Vector2i(x,y)+rct.position)
			%ColorMap.set_cell(Vector2i(x,y)+rct.position)

func change_tick_rate(value: float):
	Global.tick_speed = value*60

func create_tilemap_array(tilemap: TileMapLayer, colormap: TileMapLayer) -> Array:
	var used_rect: Rect2i = tilemap.get_used_rect()
	var result = Array()
	result.resize(used_rect.size.x)
	
	for x in range(used_rect.size.x):
		result[x] = Array()
		result[x].resize(used_rect.size.y)
		
		for y in range(used_rect.size.y):
			var current_pos = used_rect.position + Vector2i(x, y)
			var tile_atlas_coords = tilemap.get_cell_atlas_coords(current_pos)
			var tile_data = tilemap.get_cell_tile_data(current_pos)
			var tile_alt = tilemap.get_cell_alternative_tile(current_pos)
			var color_tile_atlas_coords = colormap.get_cell_atlas_coords(current_pos)
			var is_powered: int = Global.PowerTypes[color_tile_atlas_coords]

			var cell_type = Global.CellTypes[tile_data.get_custom_data("CellTypes")] if tile_atlas_coords != Vector2i(-1, -1) else -1

			result[x][y] = {
				"type": cell_type,
				"powered": is_powered,
				"rotation": Global.get_tile_data_rotation(tile_alt),
				"position": current_pos,
			}
	
	return result


@onready var curr_grid: Array = create_tilemap_array(%CellMap, %ColorMap)
@onready var next_grid: Array = curr_grid.duplicate(true)

func do_wire_cell(curr_cell, x, y):
	if not curr_cell['powered']:
		return []

	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y

	if is_valid_cell(nx, ny, curr_grid):
		next_grid[nx][ny]['powered'] = curr_cell['powered']

	# check all directions for cells pointing to us
	var active = false
	for direction in dirs:
		var check_x = x + direction.x
		var check_y = y + direction.y
		if is_valid_cell(check_x, check_y, curr_grid):
			var check_cell = curr_grid[check_x][check_y]
			if check_cell['powered']:
				var backrot = dirs[check_cell['rotation'] / 90]
				if x == check_x + backrot.x and y == check_y + backrot.y:
					active = true
					break

	next_grid[x][y]['powered'] = curr_cell['powered'] if active else 0
	return next_grid
func is_valid_cell(x, y, grid):
	if x < 0 or x >= grid.size() or y < 0 or y >= grid[0].size():
		return false
	if grid[x][y]['type'] == -1:
		return false
	# Check for active blockers
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for dir in dirs:
		var bx = x + dir.x
		var by = y + dir.y
		if is_cell_in_grid(bx, by, grid) and grid[bx][by]['type'] == Global.CellTypes.Blocker:
			var blocker_dir = dirs[grid[bx][by]['rotation'] / 90]
			if blocker_dir == -dir and grid[bx][by]['powered']:
				return false
	return true

func is_cell_in_grid(x, y, grid):
	return x >= 0 and x < grid.size() and y >= 0 and y < grid[0].size()

func do_generator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	if turn_off_if_invalid(x,y):
		return
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for dir in dirs:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid) and curr_grid[nx][ny]['powered'] < 1 :
			next_grid[nx][ny]['powered'] = 1
			curr_grid[nx][ny]['powered'] = 1
	if turn_off_if_invalid(x,y):
		return
func do_AND_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not next_grid[x][y]['powered']:
		return
	var neighbors = 0
	var powered_neighbors = 0
	
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			neighbors += 1;
			if curr_grid[nx][ny]['powered']:
				powered_neighbors  += 1;
	if neighbors-1 == powered_neighbors:
		var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var dir = dirs[curr_cell['rotation'] / 90]
		if is_valid_cell(x+dir.x, y+dir.y, next_grid):
			next_grid[x+dir.x][y+dir.y]['powered'] = 1
		next_grid[x][y]['powered'] = 0
		#WHY WONT IT WORK
		return
	else:
		next_grid[x][y]['powered'] = 0
		return
func do_XOR_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not next_grid[x][y]['powered']:
		return

	var neighbors = 0
	var powered_neighbors = 0
	
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			neighbors += 1;
			if curr_grid[nx][ny]['powered']:
				powered_neighbors  += 1;
	if (neighbors-1 != powered_neighbors) and powered_neighbors > 0:
		var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var dir = dirs[curr_cell['rotation'] / 90]
		if is_valid_cell(x+dir.x, y+dir.y, next_grid):
			next_grid[x+dir.x][y+dir.y]['powered'] = 1
		next_grid[x][y]['powered'] = 0
		#WHY WONT IT WORK
		return
	else:
		next_grid[x][y]['powered'] = 0
		return

			
func do_randgenerator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	if turn_off_if_invalid(x,y):
		return
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			var rand = randi_range(0,1)
			
			next_grid[nx][ny]['powered'] = rand
			curr_grid[nx][ny]['powered'] = rand
	if turn_off_if_invalid(x,y):
		return

func do_buffer_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return

	if curr_cell['powered'] == 2:
		next_grid[x][y]['powered'] = 0;
		var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var dir = dirs[curr_cell['rotation'] / 90]
		var nx = x + (dir.x)
		var ny = y + (dir.y)
		if is_valid_cell(nx,ny,curr_grid):
			next_grid[nx][ny]['powered'] = 1
	if curr_cell['powered'] == 1:
		next_grid[x][y]['powered'] = 2
		return

func do_jumppad_cell(curr_cell, x, y):
	if not curr_cell['powered']:
		return

	
	next_grid[x][y]['powered'] = 0;
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + (dir.x*2)
	var ny = y + (dir.y*2)
	if is_valid_cell(nx,ny,curr_grid):
		next_grid[nx][ny]['powered'] = 1
		
func do_detector_cell(curr_cell, x, y):
	
	if curr_cell['powered']:
		do_wire_cell(curr_cell, x, y)
	
	#next_grid[x][y]['powered'] = 0;
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var bx = x - (dir.x)
	var by = y - (dir.y)
	if is_valid_cell(bx,by,curr_grid):
		if curr_grid[bx][by]['powered']:
			next_grid[x][y]['powered'] = 1
			
			#next_grid[bx][by]['powered'] = 0
			#next_grid[nx][ny]['powered'] = 1
func do_blocker_cell(curr_cell, x, y):
	if not curr_cell['powered']:
		return
	
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y
	var bx = x - dir.x
	var by = y - dir.y
	if is_valid_cell(nx, ny, curr_grid) and is_valid_cell(bx, by, curr_grid):
		var backdir = dirs[curr_grid[bx][by]['rotation'] / 90]
		
		if curr_grid[bx][by]['powered'] or next_grid[bx][by]['powered']:
			if is_valid_cell(bx + backdir.x, by + backdir.y, curr_grid):
				if (curr_grid[bx + backdir.x][by + backdir.y] == curr_cell) :
					next_grid[x][y]['powered'] = 0
				else:
					curr_grid[nx][ny]['powered'] = 0
					next_grid[nx][ny]['powered'] = 0
			else:
				curr_grid[nx][ny]['powered'] = 0
				next_grid[nx][ny]['powered'] = 0
		else:
			curr_grid[nx][ny]['powered'] = 0
			next_grid[x][y]['powered'] = 0
			
func do_switch_cell(curr_cell, _x, _y):
	if not curr_cell['powered']:
		return
			

func process_cell(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array, x: int, y: int):
	var curr_cell = arr[x][y]
	if curr_cell['type'] != -1:
		var atlas_coords = Global.CellTypesAtlCoords[int(curr_cell["type"])]
		tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[int(curr_cell['rotation'])])
		colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl[int(curr_cell['powered'])])

func update_tiles(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array):
	var width = arr.size()
	var height = arr[0].size()

	for i in range((width + 1) / 2):
		for x in [i, width - 1 - i]:
			if x < width:
				for y in range(height):
					if curr_grid[x][y]['type'] != -1:
						process_cell(tilemap, colormap, arr, x, y)

	for i in range((height + 1) / 2):
		for y in [i, height - 1 - i]:
			if y < height:
				for x in range(width):
					if curr_grid[x][y]['type'] != -1:
						process_cell(tilemap, colormap, arr, x, y)

func update_gamestate():
	if paused or curr_grid.size() < 1:
		return
	curr_grid = next_grid.duplicate(true)
	update_tiles(%CellMap, %ColorMap, curr_grid)
	var width = curr_grid.size()
	var height = curr_grid[0].size()

	for i in range((width + 1) / 2):
		for x in [i, width - 1 - i]:
			if x < width:
				for y in range(height):
					if curr_grid[x][y]['type'] != -1:
						process_game_cell(x, y)

	for i in range((height + 1) / 2):
		for y in [i, height - 1 - i]:
			if y < height:
				for x in range(width):
					if curr_grid[x][y]['type'] != -1:
						process_game_cell(x, y)

func turn_off_if_invalid(x,y):
	if !is_valid_cell(x,y,next_grid) or !is_valid_cell(x,y,curr_grid):
		curr_grid[x][y]['powered'] = 0
		next_grid[x][y]['powered'] = 0
		return true
	return false

func process_game_cell(x: int, y: int):
	var curr_cell = curr_grid[x][y]
	if curr_cell['powered'] == -1 :
		return
	if turn_off_if_invalid(x,y):
		return


	if curr_cell['type'] in CellFuncs.keys():
		CellFuncs[curr_cell['type']].call(curr_cell, x, y)
		if curr_cell['type'] in [Global.CellTypes.Generator, Global.CellTypes.Randomizer]:
			if is_valid_cell(x,y,next_grid):
				curr_cell['powered'] = 1
				update_tiles(%CellMap, %ColorMap, curr_grid)
	if turn_off_if_invalid(x,y):
		return

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.connect("tick", update_gamestate)
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		paused = !paused


func _on_save() -> String:
	if !curr_grid or curr_grid == []:
		return ""
	var compresseddata = {"s":[curr_grid.size(), curr_grid[0].size()],"d":[]}
	for x in range(curr_grid.size()):
		for y in range(curr_grid[0].size()):
			if curr_grid[x][y]['type'] != -1:
				compresseddata['d'].append([[x,y], curr_grid[x][y]])
			#else:
				#compresseddata['e'].append([[x,y],curr_grid[x][y]['position']])

	var compressedstring = JSON.stringify(compresseddata)
	return Marshalls.raw_to_base64(StringHelper.gzip_encode(compressedstring))

func _on_open(str) -> void:
	var content = StringHelper.gzip_decode(Marshalls.base64_to_raw(str))

	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		var data = json.data
		var json_size = data['s']
		clear_tilemap()
		curr_grid = []
		curr_grid.resize(json_size[0])
	
		for i in range(curr_grid.size()):
			curr_grid[i] = []
			curr_grid[i].resize(json_size[1])
			
	
		for i in data['d']:
			var cell = i[1]
			cell['position'] = StringHelper.string_to_vector2i(cell['position'])
			%CellMap.set_cell(cell['position'], 2, Global.CellTypesAtlCoords[int(cell['type'])], Global.RotationDict[int(cell['rotation'])])
			%ColorMap.set_cell(cell['position'], 2, Global.PowerTypesAtl[int(cell['powered'])], 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
		update_tiles(%CellMap, %ColorMap, next_grid)
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())
