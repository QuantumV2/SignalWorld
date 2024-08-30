extends Node2D

var _target_zoom: float = 1.0
const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 1.0
const ZOOM_INCREMENT: float = 0.1
const ZOOM_RATE: float = 8.0


func zoom_in():
	_target_zoom = max(_target_zoom - ZOOM_INCREMENT, MIN_ZOOM);
	set_physics_process(true)
func zoom_out():
	_target_zoom = min(_target_zoom + ZOOM_INCREMENT, MAX_ZOOM);
	set_physics_process(true)

func _input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		
		if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			position -= event.relative / %Camera2D.zoom
		if not %UI.mouse_over:
			if event.button_mask == MOUSE_BUTTON_LEFT:
				%GameHandler.user_place_tile_tilemap(%CellMap, event, Global.CellTypesAtlCoords[%CellOptions.selected], Global.RotationInd[%RotationOptions.selected])
				%GameHandler.user_place_tile_tilemap(%ColorMap, event, Global.PowerTypesAtl[%ColorOptions.selected], 0,0)
			if event.button_mask == MOUSE_BUTTON_RIGHT:
				%GameHandler.user_place_tile_tilemap(%CellMap, event, Vector2i(-1,-1),0)
				%GameHandler.user_place_tile_tilemap(%ColorMap, event, Vector2i(-1,-1),0)
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_out()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_in()
			if not %UI.mouse_over:
				if event.button_index == MOUSE_BUTTON_LEFT:
					%GameHandler.user_place_tile_tilemap(%CellMap, event, Global.CellTypesAtlCoords[%CellOptions.selected], Global.RotationInd[%RotationOptions.selected])
					%GameHandler.user_place_tile_tilemap(%ColorMap, event, Global.PowerTypesAtl[%ColorOptions.selected], 0,0)
				if event.button_index == MOUSE_BUTTON_RIGHT:
					%GameHandler.user_place_tile_tilemap(%CellMap, event, Vector2i(-1,-1),0)
					%GameHandler.user_place_tile_tilemap(%ColorMap, event, Vector2i(-1,-1),0)

			
func _physics_process(delta: float) -> void:
	%Camera2D.zoom = lerp(%Camera2D.zoom, _target_zoom * Vector2.ONE, ZOOM_RATE * delta)

	set_physics_process(not is_equal_approx(%Camera2D.zoom.x, _target_zoom))
