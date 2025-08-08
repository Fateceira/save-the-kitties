extends Control

@onready var score_label: Label = $Label

var score_manager: Node

func _ready() -> void:
	add_to_group("score_display")
	setup_score_manager()
	score_label.text = "Score: 0"

func setup_score_manager() -> void:
	score_manager = get_tree().get_first_node_in_group("score_manager")
	
	if not score_manager:
		score_manager = preload("res://Scripts/Core/ScoreManager.gd").new()
		score_manager.name = "ScoreManager"
		get_tree().current_scene.add_child(score_manager)
	
	if score_manager.has_method("set_score_label"):
		score_manager.set_score_label(score_label)
	
	if score_manager.has_signal("score_changed"):
		score_manager.score_changed.connect(_on_score_changed)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

func get_score_label() -> Label:
	return score_label
