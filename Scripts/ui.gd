extends CanvasLayer

var mouse_over = false

func _on_mouse_entered() -> void:
	mouse_over = true


func _on_mouse_exited() -> void:
	mouse_over = false


func _on_save_pressed() -> void:
	%SaveDialog.visible = true
	%SaveDialog.get_node("Control/TextEdit").text = %GameHandler._on_save()
	pass # Replace with function body.


func _on_load_pressed() -> void:
	%OpenDialog.visible = true
	pass # Replace with function body.


func _on_load_button_dialog_pressed() -> void:
	%GameHandler._on_open(%OpenDialog.get_node("Control/TextEdit").text)
	pass # Replace with function body.


func _on_save_close_pressed() -> void:
	%SaveDialog.visible = false
	pass # Replace with function body.


func _on_load_close_pressed() -> void:
	%OpenDialog.visible = false
	pass # Replace with function body.
