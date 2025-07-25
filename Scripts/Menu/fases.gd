extends Control


func _on_fase_1_pressed():
	get_tree().change_scene_to_file("res://Scenes/Gameplay.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")
