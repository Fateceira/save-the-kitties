extends Control
# Called when the node enters the scene tree for the first time.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
func _on_jogar_pressed():
	get_tree().change_scene_to_file("res://Scenes/fases.tscn")

func _on_fechar_pressed():
	get_tree().quit()


func _on_options_pressed():
	get_tree().change_scene_to_file("res://Scenes/options_scene.tscn")
