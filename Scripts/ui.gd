extends CanvasLayer

var mouse_over = false

func _on_mouse_entered() -> void:
	mouse_over = true


func _on_mouse_exited() -> void:
	mouse_over = false


func _on_save_pressed() -> void:
	%SaveDialog.visible = true
	var save = %GameHandler._on_save()
	%SaveDialog.get_node("Control/Label/TextEdit").text = save[0]
	%SaveDialog.get_node("Control/Label2/TextEdit").text = save[1]
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

func _input(event: InputEvent):
	if event.is_action_pressed("up"):
		%RotationOptions.selected = 0
	elif event.is_action_pressed("left"):
		%RotationOptions.selected = 3
	elif event.is_action_pressed("right"):
		%RotationOptions.selected = 1
	elif event.is_action_pressed("down"):
		%RotationOptions.selected = 2
	%GameHandler.display_cell_preview()

func _on_pause_pressed() -> void:
	%GameHandler.paused = !%GameHandler.paused
	pass # Replace with function body.
