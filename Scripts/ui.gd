extends CanvasLayer

var mouse_over = false

func _on_mouse_entered() -> void:
	mouse_over = true


func _on_mouse_exited() -> void:
	mouse_over = false


func _on_save_pressed() -> void:
	%SaveDialog.visible = true
	pass # Replace with function body.


func _on_load_pressed() -> void:
	%OpenDialog.visible = true
	pass # Replace with function body.
