extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("enter"):
		get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
	pass # Replace with function body.
