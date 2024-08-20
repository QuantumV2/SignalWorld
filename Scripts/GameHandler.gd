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
			if tile_atlas_coords != Vector2i(-1,-1):
				result[x][y] = {
					"type": Global.CellTypes[tile_data.get_custom_data("CellTypes")],
					"powered": Global.PowerTypes[color_tile_atlas_coords],
					"rotation": Global.get_tile_data_rotation(tile_alt),
					"position": currentpos,
				}
	print(result)
	return result

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
