extends CanvasLayer
@onready var continue_button = $container_menu/pause_holder/continue_button

func _ready():
	visible=false


func _on_continue_button_pressed():
	get_tree().paused=false
	visible = false


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
				visible=true
				get_tree().paused = true


func _on_back_to_menu_pressed():
	get_tree().paused=false
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")
	visible = false
