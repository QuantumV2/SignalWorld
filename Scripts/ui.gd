extends CanvasLayer

var mouse_over = false

func _process(delta: float) -> void:
	print(mouse_over)

func _on_area_2d_mouse_entered() -> void:
	mouse_over = true


func _on_area_2d_mouse_exited() -> void:
	mouse_over = false


func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	mouse_over = true
	pass # Replace with function body.


func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	mouse_over = false
	pass # Replace with function body.
