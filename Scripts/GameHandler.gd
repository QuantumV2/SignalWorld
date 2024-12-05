class_name GameHandler extends Node2D
## A Game Handler, what did you expect?

## A dictionary of [enum Global.CellTypes] and their [Callable]
var CellFuncs : Dictionary = {
	Global.CellTypes.Wire: do_wire_cell,
	Global.CellTypes.Generator: do_generator_cell,
	Global.CellTypes.Buffer: do_buffer_cell,
	Global.CellTypes.JumpPad: do_jumppad_cell,
	Global.CellTypes.Detector: do_detector_cell,
	Global.CellTypes.Randomizer: do_randgenerator_cell,
	Global.CellTypes.Blocker: do_blocker_cell,
	Global.CellTypes.DFlipFlop: do_dflipflop_cell,
	Global.CellTypes.AND: do_AND_cell,
	Global.CellTypes.XOR: do_XOR_cell,
	Global.CellTypes.AngledWire: do_angledwire_cell,
	
	Global.CellTypes.Flow: do_wire_cell,
	
	Global.CellTypes.TFlipFlop: do_tflipflop_cell,
}

var paused = false;
var cell_size = Vector2(128, 128)
const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var selection_start= null
var selection_end= null

var orig_tileset = preload("res://Tilesets/color_tileset.tres")
var alt_tileset = preload("res://Tilesets/alt_color_tileset.tres")

var orig_cell_tileset = preload("res://Tilesets/cell_tileset.tres")
var alt_cell_tileset = preload("res://Tilesets/alt_cell_tileset.tres")

var orig_material = preload("res://Materials/normal.tres")
#var alt_material = preload("res://Materials/filled.tres")

var alt_palette = false


func select_area(start: Vector2i, end: Vector2i) -> void:
	selection_start = start
	selection_end = end
	
var prev_clipboard = ""
enum DataType {
	Json,
	Byte
}
var preferred_type: DataType = DataType.Byte

func toggle_preferred_format(is_on):
	if is_on:
		preferred_type = DataType.Json
	else:
		preferred_type = DataType.Byte
	
func user_place_tile_tilemap(tilemap: TileMapLayer, event: InputEvent, atlas_coords: Vector2i, alt_tile: int, source_id: int = 2):
	var camera_zoom = %Camera2D.zoom
	var event_position = event.position / camera_zoom + %CamOrigin.position - get_viewport().get_visible_rect().size / (2 * camera_zoom)
	var pos = tilemap.local_to_map(tilemap.to_local(event_position))
	var copied_data = DisplayServer.clipboard_get()
	var isbase64 = StringHelper.is_base64(copied_data)
	if copied_data != "" and isbase64:
		var copied_data_decode = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()
		var content_raw = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data))
		var reader = Global.BitReader.new(content_raw)

		# Check header (big-endian)
		var header = (reader.read_bits(8) << 24) | (reader.read_bits(8) << 16) | (reader.read_bits(8) << 8) | reader.read_bits(8)
		if header == Global.HEADER:
			copied_data_decode = JSON.stringify(Global.BitReader.decompress(content_raw))
		#var json = JSON.new()
		#var error = json.parse(copied_data_decode)

		paste_copied_data(copied_data_decode, pos, true, event, tilemap, source_id, atlas_coords, alt_tile)
			
	else:
		tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)
	
	#%CellMap/PlaceCellSound.play()
	curr_grid = create_tilemap_array(%CellMap, %ColorMap)
	next_grid = curr_grid.duplicate(true)
	
func clear_tilemap():
	curr_grid = []
	next_grid = []
	var rct = %CellMap.get_used_rect()
	for x in rct.size.x:
		for y in rct.size.y:
			%CellMap.set_cell(Vector2i(x,y)+rct.position)
			%ColorMap.set_cell(Vector2i(x,y)+rct.position)
			
func toggle_colormap(is_on):
	if is_on:
		%ColorMap.tile_set = alt_tileset
		%CellMap.tile_set = alt_cell_tileset
		%PreviewTileMap.tile_set = alt_cell_tileset
		%ColorMap.material = orig_material
		%Grid.grid_color = Color(0.2, 0.2, 0.3, 1)
		RenderingServer.set_default_clear_color(Color("#131521"))
		alt_palette = true
	else:
		%ColorMap.tile_set = orig_tileset
		%CellMap.tile_set = orig_cell_tileset
		%PreviewTileMap.tile_set = orig_cell_tileset
		%ColorMap.material = orig_material
		%Grid.grid_color = Color(0.6, 0.6, 0.6, 1)
		RenderingServer.set_default_clear_color(Color("#ffffff"))
		alt_palette = false
	return 0

func display_selection():
	var pos1 = selection_start
	var pos2 = selection_end
	if pos1 == null:
		%SelectionStartSprite.visible = false

	else:
		%SelectionStartSprite.visible = true
	if pos2 == null:
		%SelectionEndSprite.visible = false
	else:
		%SelectionEndSprite.visible = true

	if pos1 == null and pos2 == null:
		return;
	# Position the preview
	%SelectionStartSprite.position = (Vector2(pos1).floor() * cell_size) if pos1 != Vector2i(0,0) else (Vector2(pos1).floor() + cell_size)
	%SelectionEndSprite.position = (Vector2(pos2).floor() * cell_size) + cell_size
	%Grid.queue_redraw()

var copypasteinvalid = false
var prev_rot = 0
func display_cell_preview():
	var camera_zoom = %Camera2D.zoom
	var origin_pos = %CamOrigin.position
	var event_pos = get_viewport().get_mouse_position() / camera_zoom + origin_pos - get_viewport().get_visible_rect().size / (2 * camera_zoom)
	
	#var half_cell = cell_size / 2

	# Step 1: Calculate position without rotation
	var target_pos = (event_pos / cell_size).floor() * cell_size

	# Step 2: Apply rotation
	var selected_rotation = Global.RotToDeg[%RotationOptions.selected]

	%PreviewTileMap.rotation_degrees = selected_rotation

	# Step 3: Calculate offset caused by rotation
	var offset = Vector2(%PreviewTileMap.get_used_rect().size) * cell_size / 2
	var rotated_offset = offset.rotated(deg_to_rad(selected_rotation)) - offset

	# Step 4: Adjust position
	%PreviewTileMap.position = target_pos - rotated_offset
	# Check for clipboard data
	var copied_data = DisplayServer.clipboard_get()
	var isbase64 = StringHelper.is_base64(copied_data)
	# TODO: replace hack and try to actually validate the date
	if copied_data != "" and isbase64 and copied_data:

		%PreviewTileMap.clear()
		var copied_data_decode = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()


		var content_raw = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data))
		var reader = Global.BitReader.new(content_raw)

		# Check header (big-endian)
		var header = (reader.read_bits(8) << 24) | (reader.read_bits(8) << 16) | (reader.read_bits(8) << 8) | reader.read_bits(8)
		if header == Global.HEADER:
			copied_data_decode = JSON.stringify(Global.BitReader.decompress(content_raw))

		var json = JSON.new()
		var error = json.parse(copied_data_decode)

		if error == OK:
			var data = json.data
			# Verify it's a valid circuit data
			if "s" in data and "d" in data:
				if data['d'] == []:
					return
				offset = Vector2(0,0)
				rotated_offset =Vector2(0,0)
				offset = Vector2(%PreviewTileMap.get_used_rect().size * (Vector2i(cell_size) * Vector2i(data['s'][0], data['s'][1])) / 2)
				rotated_offset = offset.rotated(deg_to_rad(selected_rotation)) - offset

				%PreviewTileMap.position = target_pos - rotated_offset
				# Calculate the offset based on the first cell's position
				var offset_x = data['d'][0][0][0]  # x-coordinate of the first cell
				var offset_y = data['d'][0][0][1]  # y-coordinate of the first cell
				for i in data['d']:
					if not (i[1] is Array):
						return
					var cell = array_to_cell(i[1]) if len(i[1]) == 4 else i[1]
					var relative_pos = Vector2i(i[0][0] - offset_x, i[0][1] - offset_y)  # Adjusting the position based on offset
					%PreviewTileMap.set_cell(
						relative_pos,
						2,
						Global.CellTypesAtlCoords.get(int(cell['type']), Vector2i(0,0)),
						Global.RotationDict.get(int(cell['rotation']), 0)
					)
				return
	else:
		%PreviewTileMap.clear()
		# If no valid clipboard data, use selected cell from UI
		#var selected_texture = %CellOptions.get_item_icon(%CellOptions.selected)

		
		%PreviewTileMap.set_cell(
			Vector2i.ZERO,
			2,
			Global.CellTypesAtlCoords[%CellOptions.get_item_id(%CellOptions.selected)],
			0
		)

func change_tick_rate(value: float):
	Global.tick_speed = 1.0/value

## Create a cell array, inneficient, use only when needed
func create_tilemap_array(tilemap: TileMapLayer, colormap: TileMapLayer) -> Array:
	var used_rect: Rect2i = tilemap.get_used_rect()
	var result = Array()
	result.resize(used_rect.size.x)
	
	for x in range(used_rect.size.x):
		result[x] = Array()
		result[x].resize(used_rect.size.y)
		
		for y in range(used_rect.size.y):
			var current_pos := used_rect.position + Vector2i(x, y)
			var tile_atlas_coords := tilemap.get_cell_atlas_coords(current_pos)
			var tile_data := tilemap.get_cell_tile_data(current_pos)
			var tile_alt := tilemap.get_cell_alternative_tile(current_pos)
			var color_tile_atlas_coords := colormap.get_cell_atlas_coords(current_pos)
			var is_powered: int = Global.PowerTypes[color_tile_atlas_coords]

			var cell_type = Global.CellTypes[tile_data.get_custom_data("CellTypes")] if tile_atlas_coords != Vector2i(-1, -1) else -1
			if cell_type >= 0:
				result[x][y] = {
					"type": cell_type,
					"powered": is_powered,
					"rotation": Global.get_tile_data_rotation(tile_alt),
					"position": current_pos,
				}
			else:
				pass
				#result[x][y] = null
	
	#return Global.array_to_dict_recursive(result)
	return result


## Current state of the grid
@onready var curr_grid := create_tilemap_array(%CellMap, %ColorMap)
## Next state of the grid
@onready var next_grid: = curr_grid.duplicate(true)
const angle_dirs := [Vector2i.UP + Vector2i.RIGHT, Vector2i.RIGHT + Vector2i.DOWN, Vector2i.LEFT + Vector2i.DOWN, Vector2i.LEFT + Vector2i.UP]
func do_angledwire_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	
	var dir = angle_dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y

	if is_valid_cell(nx, ny, curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3, curr_cell['rotation'])

	if next_grid[x][y]['powered'] != 3:
		next_grid[x][y]['powered'] = 0

func do_wire_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	
	var dir = DIRECTIONS[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y

	if is_valid_cell(nx, ny, curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3,curr_cell['rotation'] )

	if next_grid[x][y]['powered'] != 3:
		next_grid[x][y]['powered'] = 0


func is_valid_cell(x, y, grid) -> bool:
	if x < 0 or x >= grid.size() or y < 0 or y >= grid[0].size() or grid[x][y] == null:
		return false

	# Check for active blockers
	
	for dir in DIRECTIONS:
		var bx = x + dir.x
		var by = y + dir.y
		if is_cell_in_grid(bx, by, grid) and grid[bx][by] != null and grid[bx][by]['type'] == Global.CellTypes.Blocker:
			var blocker_dir = DIRECTIONS[grid[bx][by]['rotation'] / 90]
			if blocker_dir == -dir and grid[bx][by]['powered']:
				return false
			
	return true

func is_cell_in_grid(x, y, grid) -> bool:

	return x >= 0 and x < grid.size() and y >= 0 and y < grid[0].size()

func do_generator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	for i in range(len(DIRECTIONS)):
		var dir = DIRECTIONS[i]
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			set_grid_cell_power(next_grid, nx, ny, 3, i * 90 )

func do_AND_cell(curr_cell, x, y) -> void:
	var powered_neighbors = 0
	var rot = curr_cell['rotation']
	var total_neighbors = 0

	for i in range(DIRECTIONS.size()):
		var dir = DIRECTIONS[i]
		var nx = x + dir.x
		var ny = y + dir.y
		if is_valid_cell(nx, ny, curr_grid) and curr_grid[nx][ny]['rotation'] == (i * 90 + 180) % 360:
			total_neighbors += 1
			if curr_grid[nx][ny]['powered'] == 1:
				powered_neighbors += 1

	if powered_neighbors == total_neighbors:
		var output_dir = DIRECTIONS[int(rot / 90)]
		var ox = x + output_dir.x
		var oy = y + output_dir.y
		if is_valid_cell(ox, oy, curr_grid):
			set_grid_cell_power(next_grid, x, y, 3)
			set_grid_cell_power(next_grid, ox, oy, 3, rot)
		else:
			next_grid[x][y]['powered'] = 0
	else:
		next_grid[x][y]['powered'] = 0



func do_XOR_cell(curr_cell, x, y):
	var powered_neighbors = 0
	var rot = curr_cell['rotation']
	for i in range(DIRECTIONS.size()):
		var dir = DIRECTIONS[i]
		var nx = x + dir.x
		var ny = y + dir.y

		# Only consider cells pointing towards this cell
		#var input_dir = DIRECTIONS[(curr_cell['rotation'] / 90 + 2) % 4]  # Opposite of output direction
		if is_valid_cell(nx, ny, curr_grid) and curr_grid[nx][ny]['rotation'] == (i * 90 + 180) % 360:
			if curr_grid[nx][ny]['powered'] == 1:
				powered_neighbors += 1
				if powered_neighbors >= 2:
					next_grid[x][y]['powered'] = 0
					return null;

	if powered_neighbors == 1:
		var output_dir = DIRECTIONS[int(rot / 90)]
		var ox = x + output_dir.x
		var oy = y + output_dir.y
		if is_valid_cell(ox, oy, curr_grid):
			set_grid_cell_power(next_grid, x, y, 3)
			set_grid_cell_power(next_grid, ox, oy, 3, rot)
		else:
			next_grid[x][y]['powered'] = 0
	else:
		next_grid[x][y]['powered'] = 0



			
func do_randgenerator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	if turn_off_if_invalid(x,y):
		return
	for i in range(len(DIRECTIONS)):
		var dir = DIRECTIONS[i]
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid) :
			var rand = randi_range(0,1)
			set_grid_cell_power(next_grid, nx, ny, 3, i * 90) if rand else set_grid_cell_power(next_grid, nx, ny, 0)
	if turn_off_if_invalid(x,y):
		return

func set_grid_cell_power(grid: Array, x:int,y:int, power:int, rot:int=0) -> void:
	if grid[x][y]['powered'] != 2:
		grid[x][y]['powered'] = power
	if grid[x][y]['type'] == Global.CellTypes.Flow:
		grid[x][y]['rotation'] = rot
		
	# FIXME: find a better way to do this
	if grid[x][y]['type'] == Global.CellTypes.TFlipFlop and power and curr_grid[x][y]['powered'] :
		grid[x][y]['powered'] = 0

		
	#var effect = AudioServer.get_bus_effect(1, 0)
	#effect.pitch_scale = (grid[x][y]['type'] + 1) / 5
	#%CellMap/ChangeStateSound.play()

func do_buffer_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return


	if curr_cell['powered'] == 2:
		next_grid[x][y]['powered'] = 0;
		var dir = DIRECTIONS[curr_cell['rotation'] / 90]
		var nx = x + (dir.x)
		var ny = y + (dir.y)
		if is_valid_cell(nx,ny,curr_grid):
			set_grid_cell_power(next_grid, nx, ny, 3, curr_cell['rotation'])
	if curr_cell['powered'] == 1:
		next_grid[x][y]['powered'] = 2
		


func do_jumppad_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	
	next_grid[x][y]['powered'] = 0 if next_grid[x][y]['powered'] != 3 else next_grid[x][y]['powered'];
	var dir = DIRECTIONS[curr_cell['rotation'] / 90]
	var nx = x + (dir.x*2)
	var ny = y + (dir.y*2)
	if is_valid_cell(nx,ny,curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3, curr_cell['rotation'])
		
func do_detector_cell(curr_cell, x, y) -> void:
	
	if curr_cell['powered']:
		do_wire_cell(curr_cell, x, y)
	
	#next_grid[x][y]['powered'] = 0;
	var dir = DIRECTIONS[curr_cell['rotation'] / 90]
	var bx = x - (dir.x)
	var by = y - (dir.y)
	if is_valid_cell(bx,by,curr_grid):
		if curr_grid[bx][by]['powered']:
			set_grid_cell_power(next_grid, x, y, 3, curr_cell['rotation'])
			
			#next_grid[bx][by]['powered'] = 0
			#next_grid[nx][ny]['powered'] = 1
func do_blocker_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return
	next_grid[x][y]['powered'] = 0 if next_grid[x][y]['powered'] != 3 else next_grid[x][y]['powered'];
	var dir = DIRECTIONS[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y
	if is_valid_cell(nx, ny, curr_grid):
		curr_grid[nx][ny]['powered'] = 0
		next_grid[nx][ny]['powered'] = 0
			
func do_dflipflop_cell(curr_cell, _x, _y) -> void:
	if not curr_cell['powered']:
		return
func do_tflipflop_cell(curr_cell, _x, _y) -> void:
	if not curr_cell['powered']:
		return
func replace_temp_energy(grid: Array) -> void:
	for x in range(grid.size()):
		for y in range(grid[0].size()):
			if grid[x][y] != null:
				if grid[x][y]['powered'] == 3:
					grid[x][y]['powered'] = 1

func process_cell(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array, x: int, y: int) -> void:
	var curr_cell = arr[x][y]
	if curr_cell != null:
		var atlas_coords = Global.CellTypesAtlCoords.get(int(curr_cell['type']), Vector2i(0,0))
		tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[int(curr_cell['rotation'])])
		colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl.get(int(curr_cell['powered']),Vector2i(-1,-1)))

func update_tiles(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Array) -> void:
	var width = arr.size()
	var height = arr[0].size()

	for x in range(width):
		for y in range(height):
			var curr_cell = arr[x][y]
			if curr_cell!= null:
				var atlas_coords = Global.CellTypesAtlCoords.get(int(curr_cell['type']), Vector2i(0,0))
				tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[int(curr_cell['rotation'])])
				colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl.get(int(curr_cell['powered']),Vector2i(-1,-1)))

func update_gamestate() -> void:
	if paused or curr_grid.size() < 1:
		return


	update_tiles(%CellMap, %ColorMap, curr_grid)

	var width = curr_grid.size()
	var height = curr_grid[0].size()


	for x in range(width):
		for y in range(height):
			if curr_grid[x][y] != null:
				process_game_cell(x, y)
	replace_temp_energy(next_grid)
	curr_grid = next_grid.duplicate(true)

## Returns true if is invalid and turns off the cell, else returns false
func turn_off_if_invalid(x,y) -> bool:
	if next_grid[x][y] == null:
		return true
	if !is_valid_cell(x,y,next_grid) :
		#curr_grid[x][y]['powered'] = 0
		next_grid[x][y]['powered'] = 0
		return true
	return false

func process_game_cell(x: int, y: int) -> void:
	var curr_cell = curr_grid[x][y]
	var next_cell = next_grid[x][y]
	if curr_cell['powered'] in [-1,0] and curr_cell['type'] not in [Global.CellTypes.Generator, Global.CellTypes.Randomizer
	, Global.CellTypes.AND, Global.CellTypes.XOR, Global.CellTypes.Blocker, Global.CellTypes.Detector, Global.CellTypes.TFlipFlop] and curr_cell['powered'] == (next_cell['powered'] if next_cell['powered'] != 3 else 1):
		return



	if curr_cell['type'] in CellFuncs.keys():
		CellFuncs[curr_cell['type']].call(curr_cell, x, y)
		if curr_cell['type'] in [Global.CellTypes.Generator, Global.CellTypes.Randomizer]:
			if is_valid_cell(x,y,next_grid):
				set_grid_cell_power(next_grid, x, y, 3)
				#update_tiles(%CellMap, %ColorMap, curr_grid)
	if turn_off_if_invalid(x,y):
		return

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	#Global.load_custom_cells("res://ModTest/Cells/")
	Global.connect("tick", update_gamestate)
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("selection_start"):
		var mouse_position = get_global_mouse_position()
		selection_start = %CellMap.local_to_map(mouse_position)
		if selection_end == null:
			selection_end = Vector2i(0,0)
		if selection_start > selection_end:
			var temp1 = selection_start
			var temp2 = selection_end
			selection_end = temp1 - Vector2i(1,1)
			selection_start = temp2 + Vector2i(1,1)

		display_selection()

	elif event.is_action_pressed("selection_end"):
		var mouse_position = get_global_mouse_position()
		selection_end = %CellMap.local_to_map(mouse_position)
		if selection_start == null:
			selection_start = Vector2i(0,0)
		if selection_end < selection_start:
			var temp1 = selection_start
			var temp2 = selection_end
			selection_end = temp1 - Vector2i(1,1)
			selection_start = temp2 + Vector2i(1,1)

		display_selection()

	elif event.is_action_pressed("copy"):
		copy_selection()
	elif event.is_action_pressed("del"):
		del_selection()
	elif event.is_action_pressed("randomize"):
		RAND_selection()
	elif event.is_action_pressed("remove_selection"):
		selection_start = null
		selection_end = null
		display_selection()
	elif event.is_action_pressed("clear_clipboard"):
		DisplayServer.clipboard_set("")


	elif event.is_action_pressed("paste"):
		var mouse_position = get_global_mouse_position()
		var target_position = %CellMap.local_to_map(mouse_position)
		paste_selection(target_position)

	elif event.is_action_pressed("pause"):
		paused = !paused

func copy_selection() -> void:
	if selection_start != Vector2i(-1, -1) and selection_end != Vector2i(-1, -1):
		var xsize = abs(selection_end.x - selection_start.x) + 1
		var ysize = abs(selection_end.y - selection_start.y) + 1
		var data_to_copy = {"s": [xsize, ysize], "d": []}
		
		for x in range(selection_start.x, selection_end.x+1):
			for y in range(selection_start.y, selection_end.y+1):
				var pos := Vector2i(x,y)
				var tile_atlas_coords = %CellMap.get_cell_atlas_coords(pos)
				var tile_data = %CellMap.get_cell_tile_data(pos)
				var tile_alt = %CellMap.get_cell_alternative_tile(pos)
				var color_tile_atlas_coords = %ColorMap.get_cell_atlas_coords(pos)
				var is_powered: int = Global.PowerTypes[color_tile_atlas_coords]
				var cell_type = Global.CellTypes[tile_data.get_custom_data("CellTypes")] if tile_atlas_coords != Vector2i(-1, -1) else -1
				if cell_type == -1:
					continue
				var cell = {"powered":is_powered, "position":Vector2i(x,y), "rotation":Global.get_tile_data_rotation(tile_alt), "type":cell_type}
				data_to_copy['d'].append([[x, y], cell_to_array(cell)])
		var compressedstring = JSON.stringify(data_to_copy)
		if preferred_type == DataType.Json:
			compressedstring = Marshalls.raw_to_base64(StringHelper.gzip_encode(compressedstring))
		else:
			compressedstring = Marshalls.raw_to_base64(Global.BitReader.compress(data_to_copy).compress(FileAccess.COMPRESSION_DEFLATE))
		DisplayServer.clipboard_set(compressedstring)
func del_selection() -> void:

	if !(selection_start == null and selection_end == null):
		#var xsize = abs(selection_end.x - selection_start.x) + 1
		#var ysize = abs(selection_end.y - selection_start.y) + 1
		for x in range(selection_start.x, selection_end.x+1):
			for y in range(selection_start.y, selection_end.y+1):
				if %CellMap.get_cell_atlas_coords(Vector2i(x,y)) != Vector2i(-1,-1):
					%CellMap.set_cell(Vector2i(x,y), 2, Vector2i(-1,-1), 0)
					%ColorMap.set_cell(Vector2i(x,y), 2, Vector2i(-1,-1), 0)
				curr_grid = create_tilemap_array(%CellMap, %ColorMap)
				next_grid = curr_grid.duplicate(true)
func RAND_selection() -> void:

	if !(selection_start == null and selection_end == null):
		#var xsize = abs(selection_end.x - selection_start.x) + 1
		#var ysize = abs(selection_end.y - selection_start.y) + 1
		for x in range(selection_start.x, selection_end.x+1):
			for y in range(selection_start.y, selection_end.y+1):
				%CellMap.set_cell(Vector2i(x,y), 2, Global.CellTypesAtlCoords[randi_range(-1,10) ], Global.RotationInd[randi_range(0,3)])
				%ColorMap.set_cell(Vector2i(x,y), 2, Vector2i(randi_range(0,1),0), 0)
				curr_grid = create_tilemap_array(%CellMap, %ColorMap)
				next_grid = curr_grid.duplicate(true)
				
func paste_selection(target_position: Vector2i) -> void:
	var copied_data = DisplayServer.clipboard_get()
	if copied_data == "":
		return
	var copied_data_decode = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()


	var content_raw = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data))
	var reader = Global.BitReader.new(content_raw)

	# Check header (big-endian)
	var header = (reader.read_bits(8) << 24) | (reader.read_bits(8) << 16) | (reader.read_bits(8) << 8) | reader.read_bits(8)
	if header == Global.HEADER:
		copied_data_decode = JSON.stringify(Global.BitReader.decompress(content_raw))

	paste_copied_data(copied_data_decode, target_position)
func paste_copied_data(copied_data, target_position, user_placing=false, event=null, tilemap=null, source_id=null, atlas_coords=null, alt_tile=null):
	var json = JSON.new()
	var error = json.parse(copied_data)

	if error == OK:
		var data = json.data
		# Get the current rotation from RotationOptions
		var selected_rotation = Global.RotToDeg[%RotationOptions.selected]
		
		# Calculate the offset based on the first cell's position 
		var offset_x = data['d'][0][0][0]  # x-coordinate of the first cell
		var offset_y = data['d'][0][0][1]  # y-coordinate of the first cell

		for i in data['d']:
			var cell = i[1]
			
			# Calculate the rotated position
			var relative_pos = Vector2(i[0][0] - offset_x, i[0][1] - offset_y)
			var rotated_pos = rotate_vector(relative_pos, selected_rotation)
			var new_position = adjust_rotation_offset(target_position + Vector2i(rotated_pos), selected_rotation)
			
			# Rotate the cell's rotation
			var original_rotation = int(cell[2])
			var new_rotation = (original_rotation + selected_rotation) % 360

			if user_placing:
				if not (cell is Array):
					tilemap.set_cell(target_position, source_id, atlas_coords, alt_tile)
					curr_grid = create_tilemap_array(%CellMap, %ColorMap)
					next_grid = curr_grid.duplicate(true)
					return
				if event.get("button_index")== MOUSE_BUTTON_LEFT or event.get("button_mask")== MOUSE_BUTTON_LEFT:
					%CellMap.set_cell(new_position, 2, Global.CellTypesAtlCoords.get(int(cell[3]), Vector2i(0,0)), Global.RotationDict[new_rotation])
					%ColorMap.set_cell(new_position, 2, Global.PowerTypesAtl.get(int(cell[1]),Vector2i(-1,-1)), 0)
				else:
					%CellMap.set_cell(new_position, 2, Vector2i(-1,-1), 0)
					%ColorMap.set_cell(new_position, 2, Vector2i(-1,-1), 0)
			else:
				%CellMap.set_cell(new_position, 2, Global.CellTypesAtlCoords.get(int(cell[3]), Vector2i(0,0)), Global.RotationDict[new_rotation])
				%ColorMap.set_cell(new_position, 2, Global.PowerTypesAtl.get(int(cell[1]),Vector2i(0,0)), 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
	else:
		print("Error parsing copied data")

func rotate_vector(vec: Vector2, degrees: int) -> Vector2:
	match degrees:
		90:  # Rotated 90 degrees clockwise
			return Vector2(-vec.y, vec.x)
		180:  # Rotated 180 degrees
			return -vec
		270:  # Rotated 270 degrees (counterclockwise)
			return Vector2(vec.y, -vec.x)
		_:  # 0 or 360 degrees
			return vec

func adjust_rotation_offset(pos: Vector2i, degrees: int) -> Vector2i:
	match degrees:
		90:
			return pos - Vector2i(1, 0)  # Adjust for left rotation
		180:
			return pos - Vector2i(1, 1)  # Adjust for down rotation
		270:
			return pos + Vector2i(0, -1)  # Adjust for right rotation
		_:
			return pos
##Save the new File Format
func _on_save() -> String:
	if !curr_grid:
		return ""
	var compresseddata = {"s":[curr_grid.size(), curr_grid[0].size()],"d":[]}
	for x in range(curr_grid.size()):
		for y in range(curr_grid[0].size()):
			if curr_grid[x][y] != null and curr_grid[x][y]['type'] != -1:
				compresseddata['d'].append([[x,y], cell_to_array(curr_grid[x][y])])

	#var compressedstring = JSON.stringify(compresseddata)
	#print(compressedstring)
	#print(compresseddata, " | END | ", Global.BitReader.decompress(Global.BitReader.compress(compresseddata)), " | END | ", Marshalls.raw_to_base64(Global.BitReader.compress(compresseddata)), " | END | ", Marshalls.raw_to_base64(Global.BitReader.compress(compresseddata).compress(FileAccess.COMPRESSION_DEFLATE)))
	return Marshalls.raw_to_base64(Global.BitReader.compress(compresseddata).compress(FileAccess.COMPRESSION_DEFLATE))

"""
func json_to_bytes(data: Dictionary) -> PackedByteArray:
	var packer = Global.BitPacker.new()
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	var bytes: PackedByteArray = PackedByteArray()
	buffer.big_endian = true

	# Write header
	buffer.put_u32(0x53570001)
	print(buffer.data_array.hex_encode())

	# Reset packer for cell data
	packer = Global.BitPacker.new()

	var cells = data['d']
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for cell in cells:
		var pos = cell[1][0]
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
		
	var x_bits = min(max(Global.bits_required(abs(min_x)), Global.bits_required(abs(max_x))) + 1, 16)
	var y_bits = min(max(Global.bits_required(abs(min_y)), Global.bits_required(abs(max_y))) + 1, 16)

	# Write x_bits and y_bits (5 bits each)
	var bits_data = (x_bits - 1) | ((y_bits - 1) << 5)
	var bytes_needed = (bits_data + 7) / 8  # Round up to nearest byte
	for j in range(bytes_needed):
		buffer.put_u8(bits_data & 0xFF)
		bits_data >>= 8

	for i in len(cells):
		var cell = cells[i]
		var pos = cell[1][0]
		var x = pos.x & Global.create_bitmask(x_bits)
		var y = pos.y & Global.create_bitmask(y_bits)

		packer.add_field("x", x_bits, true)
		packer.add_field("y", y_bits, true)
		packer.add_field("powered", 2)
		packer.add_field("rotation", 2)
		packer.add_field("type", 6)


		var cell_data = packer.pack({
			"x": x,
			"y": y,
			"powered": cell[1][1] & 0b11,
			"rotation": Global.DegToRot[cell[1][2]] & 0b11,
			"type": cell[1][3] & 0b111111,

		})
		print(cell_data)
		bytes_needed = (packer.total_bits + 7) / 8  # Round up to nearest byte
		for j in range(bytes_needed):
			buffer.put_u8(cell_data & 0xFF)
			cell_data >>= 8
		#bytes.append(cell_data)
		#buffer.put_data(bytes)
		# Reset packer for next cell
		packer = Global.BitPacker.new()
	print(buffer.data_array.hex_encode())
	return buffer.data_array
	"""


##File Format tool
func array_to_cell(arr: Array) -> Dictionary:
	return {
		"position": StringHelper.string_to_vector2i(arr[0]),
		"powered": arr[1],
		"rotation": arr[2],
		"type": arr[3],
	}
##File Format tool
func cell_to_array(dict: Dictionary) -> Array:
	return [dict['position'], dict['powered'], dict['rotation'], dict['type']]
	
## @deprecated 
## Open the old File Format
func legacy_format_open(_str):
	var content = StringHelper.gzip_decode(Marshalls.base64_to_raw(_str)).get_string_from_utf8()

	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		var data = json.data
		#var json_size = data['s']
		clear_tilemap()
		curr_grid = []
		#curr_grid.resize(json_size[0])
	
		#for i in range(curr_grid.size()):
			#curr_grid[i] = []
			#curr_grid[i].resize(json_size[1])
			
	
		for i in data['d']:
			var cell = i[1]
			cell['position'] = StringHelper.string_to_vector2i(cell['position'])
			%CellMap.set_cell(cell['position'], 2, Global.CellTypesAtlCoords.get(int(cell['type']), Vector2i(0,0)), Global.RotationDict[int(cell['rotation'])])
			%ColorMap.set_cell(cell['position'], 2,Global.PowerTypesAtl.get(int(cell['powered']),Vector2i(-1,-1)), 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
		update_tiles(%CellMap, %ColorMap, next_grid)
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())
##Open the new File Format
func _on_open(_str) -> void:
	if %OpenDialog.get_node("Control/CheckBox").button_pressed:
		legacy_format_open(_str)
		return
	var content = StringHelper.gzip_decode(Marshalls.base64_to_raw(_str)).get_string_from_utf8()
	var content_raw = StringHelper.gzip_decode(Marshalls.base64_to_raw(_str))
	var reader = Global.BitReader.new(content_raw)

	# Check header (big-endian)
	var header = (reader.read_bits(8) << 24) | (reader.read_bits(8) << 16) | (reader.read_bits(8) << 8) | reader.read_bits(8)
	if header == Global.HEADER:
		content = JSON.stringify(Global.BitReader.decompress(content_raw))
	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		var data = json.data
		#var json_size = data['s']
		clear_tilemap()
		curr_grid = []
		#curr_grid.resize(json_size[0])
	
		#for i in range(curr_grid.size()):
			#curr_grid[i] = []
			#curr_grid[i].resize(json_size[1])
			
	
		for i in data['d']:
			var cell = array_to_cell(i[1])
			%CellMap.set_cell(cell['position'], 2, Global.CellTypesAtlCoords.get(int(cell['type']), Vector2i(0,0)), Global.RotationDict[int(cell['rotation'])])
			%ColorMap.set_cell(cell['position'], 2, Global.PowerTypesAtl.get(int(cell['powered']),Vector2i(-1,-1)), 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
		update_tiles(%CellMap, %ColorMap, next_grid)
	else:
		#print(content)
		print("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())


func _on_selection_start_sprite_ready() -> void:
	display_selection()
	pass # Replace with function body.
