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
	Global.CellTypes.Switch: do_switch_cell,
	Global.CellTypes.AND: do_AND_cell,
	Global.CellTypes.XOR: do_XOR_cell,
	Global.CellTypes.AngledWire: do_angledwire_cell,
}

var paused = false;

var selection_start: Vector2i = Vector2i(-1, -1)
var selection_end: Vector2i = Vector2i(-1, -1)

func select_area(start: Vector2i, end: Vector2i) -> void:
	selection_start = start
	selection_end = end
	


func user_place_tile_tilemap(tilemap: TileMapLayer, event: InputEvent, atlas_coords: Vector2i, alt_tile: int, source_id: int = 2):
	var camera_zoom = %Camera2D.zoom
	var event_position = event.position / camera_zoom + %CamOrigin.position - get_viewport().get_visible_rect().size / (2 * camera_zoom)
	var pos = tilemap.local_to_map(tilemap.to_local(event_position))
	var copied_data = DisplayServer.clipboard_get()
	var isbase64 = StringHelper.is_base64(copied_data)
	if copied_data != "" and isbase64:
		copied_data = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(copied_data)

		paste_copied_data(copied_data, pos, true, event, tilemap, source_id, atlas_coords, alt_tile)
			
	else:
		tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)
	
	curr_grid = create_tilemap_array(%CellMap, %ColorMap)
	next_grid = curr_grid.duplicate(true)
func clear_tilemap():
	curr_grid = {}
	next_grid = {}
	var rct = %CellMap.get_used_rect()
	for x in rct.size.x:
		for y in rct.size.y:
			%CellMap.set_cell(Vector2i(x,y)+rct.position)
			%ColorMap.set_cell(Vector2i(x,y)+rct.position)

func display_selection():
	var pos1 = selection_start
	var pos2 = selection_end
	if pos1 == Vector2i(-1,-1):
		%SelectionStartSprite.visible = false

	else:
		%SelectionStartSprite.visible = true
	if pos2 == Vector2i(-1,-1):
		%SelectionEndSprite.visible = false
	else:
		%SelectionEndSprite.visible = true
	var cell_size = Vector2(128, 128)

	# Position the preview
	%SelectionStartSprite.position = (Vector2(pos1).floor() * cell_size) if pos1 != Vector2i(0,0) else (Vector2(pos1).floor() + cell_size)
	%SelectionEndSprite.position = (Vector2(pos2).floor() * cell_size) + cell_size


func display_cell_preview(copypasteinvalid = false):
	var camera_zoom = %Camera2D.zoom
	var origin_pos = %CamOrigin.position
	var event_pos = get_viewport().get_mouse_position() / camera_zoom + origin_pos - get_viewport().get_visible_rect().size / (2 * camera_zoom)
	
	var cell_size = Vector2(128, 128)
	var half_cell = cell_size / 2

	# Position the preview
	%PreviewTileMap.position = (event_pos / cell_size).floor() * cell_size

	# Check for clipboard data
	var copied_data = DisplayServer.clipboard_get()
	var isbase64 = StringHelper.is_base64(copied_data)
	if copied_data != "" and isbase64 and !copypasteinvalid:
		%PreviewTileMap.clear()
		copied_data = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(copied_data)

		if error == OK:
			var data = json.data
			# Verify it's a valid circuit data
			if "s" in data and "d" in data:
				if data['d'] == []:
					display_cell_preview(true)
					return

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
						Global.CellTypesAtlCoords[int(cell['type'])],
						Global.RotationDict[int(cell['rotation'])]
					)
				return
	else:
		%PreviewTileMap.clear()
		# If no valid clipboard data, use selected cell from UI
		var selected_texture = %CellOptions.get_item_icon(%CellOptions.selected)
		var selected_rotation = Global.RotToDeg[%RotationOptions.selected]
		
		%PreviewTileMap.set_cell(
			Vector2i.ZERO,
			2,
			Global.CellTypesAtlCoords[%CellOptions.selected],
			Global.RotationDict[selected_rotation]
		)

func change_tick_rate(value: float):
	Global.tick_speed = value*60

## Create a cell array, inneficient, use only when needed
func create_tilemap_array(tilemap: TileMapLayer, colormap: TileMapLayer) -> Dictionary:
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
	
	return Global.array_to_dict_recursive(result)


## Current state of the grid
@onready var curr_grid: Dictionary = create_tilemap_array(%CellMap, %ColorMap)
## Next state of the grid
@onready var next_grid: Dictionary = curr_grid.duplicate(true)

func do_angledwire_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	var dirs := [Vector2i.UP + Vector2i.RIGHT, Vector2i.RIGHT + Vector2i.DOWN, Vector2i.LEFT + Vector2i.DOWN, Vector2i.LEFT + Vector2i.UP]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y

	if is_valid_cell(nx, ny, curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3)

	if next_grid[x][y]['powered'] != 3:
		next_grid[x][y]['powered'] = 0

func do_wire_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y

	if is_valid_cell(nx, ny, curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3)

	if next_grid[x][y]['powered'] != 3:
		next_grid[x][y]['powered'] = 0

func is_valid_cell(x, y, grid) -> bool:
	if x < 0 or x >= grid.size() or y < 0 or y >= grid[0].size():
		return false
	if grid[x][y] == null:
		return false
	# Check for active blockers
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for dir in dirs:
		var bx = x + dir.x
		var by = y + dir.y
		if is_cell_in_grid(bx, by, grid) and grid[bx][by] != null and grid[bx][by]['type'] == Global.CellTypes.Blocker:
			var blocker_dir = dirs[grid[bx][by]['rotation'] / 90]
			if blocker_dir == -dir and grid[bx][by]['powered']:
				return false
	return true

func is_cell_in_grid(x, y, grid) -> bool:
	return x >= 0 and x < grid.size() and y >= 0 and y < grid[0].size()

func do_generator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid):
			set_grid_cell_power(next_grid, nx, ny, 3)

func do_AND_cell(curr_cell, x, y) -> void:
	var powered_neighbors = 0
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var total_neighbors = 0

	for i in range(dirs.size()):
		var dir = dirs[i]
		var nx = x + dir.x
		var ny = y + dir.y
		if is_valid_cell(nx, ny, curr_grid) and curr_grid[nx][ny]['rotation'] == (i * 90 + 180) % 360:
			total_neighbors += 1
			if curr_grid[nx][ny]['powered'] == 1:
				powered_neighbors += 1

	var output_dir = dirs[int(curr_cell['rotation'] / 90)]
	var ox = x + output_dir.x
	var oy = y + output_dir.y

	if is_valid_cell(ox, oy, curr_grid) and powered_neighbors == total_neighbors:
		set_grid_cell_power(next_grid, x, y, 3)
		set_grid_cell_power(next_grid, ox, oy, 3)
	else:
		next_grid[x][y]['powered'] = 0



func do_XOR_cell(curr_cell, x, y) -> void:
	var powered_neighbors = 0
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

	for i in range(dirs.size()):
		var dir = dirs[i]
		var nx = x + dir.x
		var ny = y + dir.y

		# Only consider cells pointing towards this cell
		#var input_dir = dirs[(curr_cell['rotation'] / 90 + 2) % 4]  # Opposite of output direction
		if is_valid_cell(nx, ny, curr_grid) and curr_grid[nx][ny]['rotation'] == (i * 90 + 180) % 360:
			if curr_grid[nx][ny]['powered'] == 1:
				powered_neighbors += 1

	var output_dir = dirs[int(curr_cell['rotation'] / 90)]
	var ox = x + output_dir.x
	var oy = y + output_dir.y

	if is_valid_cell(ox, oy, curr_grid) and powered_neighbors == 1:
		set_grid_cell_power(next_grid, x, y, 3)
		set_grid_cell_power(next_grid, ox, oy, 3)
	else:
		next_grid[x][y]['powered'] = 0


			
func do_randgenerator_cell(curr_cell: Dictionary, x: int, y: int) -> void:
	if not curr_cell['powered']:
		return
	if turn_off_if_invalid(x,y):
		return
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nx = x + dir.x
		var ny = y + dir.y

		if is_valid_cell(nx, ny, curr_grid) :
			var rand = randi_range(0,1)
			set_grid_cell_power(next_grid, nx, ny, 3) if rand else set_grid_cell_power(next_grid, nx, ny, 0)
	if turn_off_if_invalid(x,y):
		return

func set_grid_cell_power(grid: Dictionary, x:int,y:int, power:int) -> void:
	if grid[x][y]['powered'] != 2:
		grid[x][y]['powered'] = power

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
			set_grid_cell_power(next_grid, nx, ny, 3)
	if curr_cell['powered'] == 1:
		next_grid[x][y]['powered'] = 2
		


func do_jumppad_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return

	
	next_grid[x][y]['powered'] = 0 if next_grid[x][y]['powered'] != 3 else next_grid[x][y]['powered'];
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + (dir.x*2)
	var ny = y + (dir.y*2)
	if is_valid_cell(nx,ny,curr_grid):
		set_grid_cell_power(next_grid, nx, ny, 3)
		
func do_detector_cell(curr_cell, x, y) -> void:
	
	if curr_cell['powered']:
		do_wire_cell(curr_cell, x, y)
	
	#next_grid[x][y]['powered'] = 0;
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var bx = x - (dir.x)
	var by = y - (dir.y)
	if is_valid_cell(bx,by,curr_grid):
		if curr_grid[bx][by]['powered']:
			set_grid_cell_power(next_grid, x, y, 3)
			
			#next_grid[bx][by]['powered'] = 0
			#next_grid[nx][ny]['powered'] = 1
func do_blocker_cell(curr_cell, x, y) -> void:
	if not curr_cell['powered']:
		return
	next_grid[x][y]['powered'] = 0 if next_grid[x][y]['powered'] != 3 else next_grid[x][y]['powered'];
	var dirs = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var dir = dirs[curr_cell['rotation'] / 90]
	var nx = x + dir.x
	var ny = y + dir.y
	if is_valid_cell(nx, ny, curr_grid):
		curr_grid[nx][ny]['powered'] = 0
		next_grid[nx][ny]['powered'] = 0
			
func do_switch_cell(curr_cell, _x, _y) -> void:
	if not curr_cell['powered']:
		return
			
func replace_temp_energy(grid: Dictionary) -> void:
	for x in range(grid.size()):
		for y in range(grid[0].size()):
			if grid[x][y] != null:
				if grid[x][y]['powered'] == 3:
					grid[x][y]['powered'] = 1

func process_cell(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Dictionary, x: int, y: int) -> void:
	var curr_cell = arr[x][y]
	if curr_cell != null:
		var atlas_coords = Global.CellTypesAtlCoords[int(curr_cell["type"])]
		tilemap.set_cell(curr_cell['position'], 2, atlas_coords, Global.RotationDict[int(curr_cell['rotation'])])
		colormap.set_cell(curr_cell['position'], 0, Global.PowerTypesAtl[int(curr_cell['powered'])])

func update_tiles(tilemap: TileMapLayer, colormap: TileMapLayer, arr: Dictionary) -> void:
	var width = arr.size()
	var height = arr[0].size()

	for x in range(width):
		for y in range(height):
			if arr[x][y] != null:
				process_cell(tilemap, colormap, arr, x, y)

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
	if curr_cell['powered'] == -1 :
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
	Global.connect("tick", update_gamestate)
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("selection_start"):
		var mouse_position = get_global_mouse_position()
		selection_start = %CellMap.local_to_map(mouse_position)
		if selection_end == Vector2i(-1,-1):
			selection_end = Vector2i(0,0)
		display_selection()

	elif event.is_action_pressed("selection_end"):
		var mouse_position = get_global_mouse_position()
		selection_end = %CellMap.local_to_map(mouse_position)
		if selection_start == Vector2i(-1,-1):
			selection_start = Vector2i(0,0)
		display_selection()

	elif event.is_action_pressed("copy"):
		copy_selection()
	elif event.is_action_pressed("del"):
		del_selection()
	elif event.is_action_pressed("remove_selection"):
		selection_start = Vector2i(-1,-1)
		selection_end = Vector2i(-1,-1)
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
		compressedstring = Marshalls.raw_to_base64(StringHelper.gzip_encode(compressedstring))
		DisplayServer.clipboard_set(compressedstring)
func del_selection() -> void:

	if !(selection_start == Vector2i(-1, -1) and selection_end == Vector2i(-1, -1)):
		var xsize = abs(selection_end.x - selection_start.x) + 1
		var ysize = abs(selection_end.y - selection_start.y) + 1
		for x in range(selection_start.x, selection_end.x+1):
			for y in range(selection_start.y, selection_end.y+1):
				%CellMap.set_cell(Vector2i(x,y), 2, Vector2i(-1,-1), 0)
				%ColorMap.set_cell(Vector2i(x,y), 2, Vector2i(-1,-1), 0)
				curr_grid = create_tilemap_array(%CellMap, %ColorMap)
				next_grid = curr_grid.duplicate(true)
				
func paste_selection(target_position: Vector2i) -> void:
	var copied_data = DisplayServer.clipboard_get()
	copied_data = StringHelper.gzip_decode(Marshalls.base64_to_raw(copied_data)).get_string_from_utf8()
	if copied_data == "":
		return

	paste_copied_data(copied_data, target_position)
func paste_copied_data(copied_data, target_position, user_placing=false, event=null, tilemap=null, source_id=null, atlas_coords=null, alt_tile=null):
	var json = JSON.new()
	var error = json.parse(copied_data)

	if error == OK:
		var data = json.data
		var json_size = data['s']
		
		# Calculate the offset based on the first cell's position
		var offset_x = data['d'][0][0][0]  # x-coordinate of the first cell
		var offset_y = data['d'][0][0][1]  # y-coordinate of the first cell
		
		for i in data['d']:
			var cell = i[1]
			var new_position = target_position + Vector2i(i[0][0] - offset_x, i[0][1] - offset_y)
			if user_placing:
				if not (cell is Array):
					tilemap.set_cell(target_position, source_id, atlas_coords, alt_tile)
					curr_grid = create_tilemap_array(%CellMap, %ColorMap)
					next_grid = curr_grid.duplicate(true)
					return
				if event.get("button_index")== MOUSE_BUTTON_LEFT or event.get("button_mask")== MOUSE_BUTTON_LEFT:
					%CellMap.set_cell(new_position, 2, Global.CellTypesAtlCoords[int(cell[3])], Global.RotationDict[int(cell[2])])
					%ColorMap.set_cell(new_position, 2, Global.PowerTypesAtl[int(cell[1])], 0)
				else:
					%CellMap.set_cell(new_position, 2, Vector2i(-1,-1), 0)
					%ColorMap.set_cell(new_position, 2, Vector2i(-1,-1), 0)	
			else:
				# Adjust the position based on the offset

				%CellMap.set_cell(new_position, 2, Global.CellTypesAtlCoords[int(cell[3])], Global.RotationDict[int(cell[2])])
				%ColorMap.set_cell(new_position, 2, Global.PowerTypesAtl[int(cell[1])], 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", copied_data, " at line ", json.get_error_line())
		
##Save the new File Format
func _on_save() -> String:
	if !curr_grid:
		return ""
	var compresseddata = {"s":[curr_grid.size(), curr_grid[0].size()],"d":[]}
	for x in range(curr_grid.size()):
		for y in range(curr_grid[0].size()):
			if curr_grid[x][y] != null and curr_grid[x][y]['type'] != -1:
				compresseddata['d'].append([[x,y], cell_to_array(curr_grid[x][y])])

	var compressedstring = JSON.stringify(compresseddata)
	return Marshalls.raw_to_base64(StringHelper.gzip_encode(compressedstring))



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
		var json_size = data['s']
		clear_tilemap()
		curr_grid = {}
		#curr_grid.resize(json_size[0])
	
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
##Open the new File Format
func _on_open(_str) -> void:
	if %OpenDialog.get_node("Control/CheckBox").button_pressed:
		legacy_format_open(_str)
		return
	var content = StringHelper.gzip_decode(Marshalls.base64_to_raw(_str)).get_string_from_utf8()

	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		var data = json.data
		var json_size = data['s']
		clear_tilemap()
		curr_grid = {}
		#curr_grid.resize(json_size[0])
	
		for i in range(curr_grid.size()):
			curr_grid[i] = []
			curr_grid[i].resize(json_size[1])
			
	
		for i in data['d']:
			var cell = array_to_cell(i[1])
			%CellMap.set_cell(cell['position'], 2, Global.CellTypesAtlCoords[int(cell['type'])], Global.RotationDict[int(cell['rotation'])])
			%ColorMap.set_cell(cell['position'], 2, Global.PowerTypesAtl[int(cell['powered'])], 0)

		curr_grid = create_tilemap_array(%CellMap, %ColorMap)
		next_grid = curr_grid.duplicate(true)
		update_tiles(%CellMap, %ColorMap, next_grid)
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())


func _on_selection_start_sprite_ready() -> void:
	display_selection()
	pass # Replace with function body.
