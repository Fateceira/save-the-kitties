extends Node

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
#	elif Input.is_action_just_pressed("quit"):
#		get_tree().quit()
