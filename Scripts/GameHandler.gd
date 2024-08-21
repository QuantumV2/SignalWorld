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
func create_tilemap_array(tilemap: TileMapLayer, colormap: TileMapLayer) -> Array:
	var result = []
	var usedrect: Rect2i = tilemap.get_used_rect()
	for x in range(usedrect.size.x):
		var arr = []
		arr.resize(usedrect.size.y)
		result.append(arr)
		for y in range(usedrect.size.y):
			
			var currentpos = usedrect.position + Vector2i(x,y)
			var tile_atlas_coords = tilemap.get_cell_atlas_coords(currentpos)
			var tile_data = tilemap.get_cell_tile_data(currentpos)
			var tile_alt = tilemap.get_cell_alternative_tile(currentpos)
			var color_tile_atlas_coords = colormap.get_cell_atlas_coords(currentpos)
			#if tile_atlas_coords != Vector2i(-1,-1):
			var is_powered:int = Global.PowerTypes[color_tile_atlas_coords]
			result[x][y] = {
				"type": Global.CellTypes[tile_data.get_custom_data("CellTypes")] if tile_atlas_coords != Vector2i(-1,-1) else -1,
				"powered": is_powered,
				"rotation": Global.get_tile_data_rotation(tile_alt),
				"position": currentpos,
			}
	#print(result)
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
	
	# Check if there's a powered wire behind this one
	var back_x = x - dir.x
	var back_y = y - dir.y
	if not is_valid_cell(back_x, back_y, curr_grid) or not curr_grid[back_x][back_y]['powered']:
		next_grid[x][y]['powered'] = 0
	else:
		next_grid[x][y]['powered'] = curr_cell['powered']
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
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			if (curr_grid[nx][ny]['rotation'] != 180 and dir == Vector2i.DOWN) or (curr_grid[nx][ny]['rotation'] != 270 and dir == Vector2i.LEFT) or (curr_grid[nx][ny]['rotation'] != 0 and dir == Vector2i.UP) or (curr_grid[nx][ny]['rotation'] != 90 and dir == Vector2i.RIGHT):
				continue;
			next_grid[nx][ny]['powered'] = 1
			curr_grid[nx][ny]['powered'] = 1
			
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
		next_grid[x+dir.x][y+dir.y]['powered'] = 1
		next_grid[x][y]['powered'] = 0
		curr_grid[x][y]['powered'] = 0
		#WHY WONT IT WORK
		return
	else:
		next_grid[x][y]['powered'] = 0
		curr_grid[x][y]['powered'] = 0
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
		next_grid[x+dir.x][y+dir.y]['powered'] = 1
		next_grid[x][y]['powered'] = 0
		curr_grid[x][y]['powered'] = 0
		#WHY WONT IT WORK
		return
	else:
		next_grid[x][y]['powered'] = 0
		curr_grid[x][y]['powered'] = 0
		return

			
func do_randgenerator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y
		if (curr_grid[nx][ny]['rotation'] != 180 and dir == Vector2i.DOWN) or (curr_grid[nx][ny]['rotation'] != 270 and dir == Vector2i.LEFT) or (curr_grid[nx][ny]['rotation'] != 0 and dir == Vector2i.UP) or (curr_grid[nx][ny]['rotation'] != 90 and dir == Vector2i.RIGHT):
			continue;
		if is_valid_cell(nx, ny, curr_grid):
			next_grid[nx][ny]['powered'] = randi_range(0,1)
			curr_grid[nx][ny]['powered'] = next_grid[nx][ny]['powered']

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
	
	next_grid[x][y]['powered'] = 0;
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + (dir.x)
	var ny = y + (dir.y)
	var bx = x - (dir.x)
	var by = y - (dir.y)
	if is_valid_cell(bx,by,curr_grid):
		if curr_grid[bx][by]['powered']:
			next_grid[x][y]['powered'] = 1
			next_grid[bx][by]['powered'] = 0
			#next_grid[nx][ny]['powered'] = 1
func do_blocker_cell(curr_cell, x, y):
	if not curr_cell['powered']:
		return
	#next_grid[x][y]['powered'] = 0
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y
	if is_valid_cell(nx, ny, curr_grid):
		curr_grid[nx][ny]['powered'] = 0
		next_grid[nx][ny]['powered'] = 0
			
func do_switch_cell(curr_cell, x, y):
	if not curr_cell['powered']:
		return
			

func process_cell(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array, x: int, y: int):
	var curr_cell = arr[x][y]
	if curr_cell['type'] != -1:
		var atlas_coords = Global.CellTypesAtlCoords[curr_cell["type"]]
		tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[curr_cell['rotation']])
		colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl[curr_cell['powered']])

func update_tiles(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array):
	var width = arr.size()
	var height = arr[0].size()

	for i in range((width + 1) / 2):
		for x in [i, width - 1 - i]:
			if x < width:
				for y in range(height):
					process_cell(tilemap, colormap, arr, x, y)

	for i in range((height + 1) / 2):
		for y in [i, height - 1 - i]:
			if y < height:
				for x in range(width):
					process_cell(tilemap, colormap, arr, x, y)

func update_gamestate():
	curr_grid = next_grid.duplicate(true)
	update_tiles(%CellMap, %ColorMap, curr_grid)
	var width = curr_grid.size()
	var height = curr_grid[0].size()

	for i in range((width + 1) / 2):
		for x in [i, width - 1 - i]:
			if x < width:
				for y in range(height):
					process_game_cell(x, y)

	for i in range((height + 1) / 2):
		for y in [i, height - 1 - i]:
			if y < height:
				for x in range(width):
					process_game_cell(x, y)



func process_game_cell(x: int, y: int):
	var curr_cell = curr_grid[x][y]
	if curr_cell['powered'] == -1:
		return
	
	if curr_cell['type'] in CellFuncs.keys():
		CellFuncs[curr_cell['type']].call(curr_cell, x, y)
		if curr_cell['type'] in [Global.CellTypes.Generator, Global.CellTypes.Randomizer]:
			if is_valid_cell(x,y,next_grid):
				curr_cell['powered'] = 1
				update_tiles(%CellMap, %ColorMap, curr_grid)	
		if !is_valid_cell(x,y,next_grid):
			next_grid[x][y]['powered'] = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.connect("tick", update_gamestate)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
