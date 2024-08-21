extends Node2D

const speed = 0.3;

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		global_position.x -= speed;
	if event.is_action_pressed("ui_right"):
		global_position.x += speed;
	if event.is_action_pressed("ui_up"):
		global_position.y -= speed;
	if event.is_action_pressed("ui_down"):
		global_position.y -= speed;
