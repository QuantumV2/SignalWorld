extends Node2D

const speed = 50;

func _process(_delta : float) -> void:
	if Input.is_action_pressed("ui_left"):
		global_position.x -= speed;
	if Input.is_action_pressed("ui_right"):
		global_position.x += speed;
	if Input.is_action_pressed("ui_up"):
		global_position.y -= speed;
	if Input.is_action_pressed("ui_down"):
		global_position.y += speed;
