extends Node


func create_tilemap_array(tilemap: TileMapLayer, colormap: TileMapLayer) -> Array:
	var result = []
	var usedrect: Rect2i = tilemap.get_used_rect()
	for x in range(usedrect.size.x):
		var arr = []
		arr.resize(usedrect.size.y)
		arr.fill({})
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
	print(result)
	return result

@onready var curr_grid: Array = create_tilemap_array(%CellMap, %ColorMap)
@onready var next_grid: Array = curr_grid.duplicate(true)

func update_tiles(tilemap: TileMapLayer, colormap: TileMapLayer, arr : Array):
	for x in arr.size():
		for y in arr[0].size():
			var curr_cell = arr[x][y]
			if(curr_cell['type'] != -1):
				var atlas_coords = Global.CellTypesAtlCoords[curr_cell["type"]]
				tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[curr_cell['rotation']])
				colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl[curr_cell['powered']])

func do_wire_cell(curr_cell,x,y):
	if curr_cell['powered']:
		next_grid[x][y]["powered"] = 0
		match curr_cell['rotation']:
			0:
				if y > 0:
					next_grid[x][y - 1]['powered'] = 1
			90:
				if x < curr_grid.size()-1:
					next_grid[x + 1][y]['powered'] = 1
			180:
				if y < curr_grid[0].size()-1:
					next_grid[x][y+1]['powered'] = 1
			270:
				if x > 0:
					next_grid[x-1][y]['powered'] = 1

func do_generator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell.get('powered', false):
		return

	var grid_size = Vector2i(len(next_grid), len(next_grid[0]))
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in directions:
		var nx = (x + dir.x + grid_size.x) % grid_size.x
		var ny = (y + dir.y + grid_size.y) % grid_size.y
		#print(nx, " ", ny)

		if next_grid[nx][ny].get('type', -1) != -1:
			next_grid[nx][ny]['powered'] = 1
	return

func update_gamestate():

	update_tiles(%CellMap,%ColorMap, curr_grid)
	for x in curr_grid.size():
		for y in curr_grid[0].size():
			var curr_cell = curr_grid[x][y]
			match curr_cell["type"]:
				Global.CellTypes.Wire:
					do_wire_cell(curr_cell,x,y)
				Global.CellTypes.Generator:
					curr_cell['powered'] = 1
					do_generator_cell(curr_cell,x,y)
	curr_grid = next_grid.duplicate(true)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.connect("tick", update_gamestate)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
