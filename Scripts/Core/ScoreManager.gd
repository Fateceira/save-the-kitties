extends Node

signal score_changed(new_score)
signal level_completed(final_score)

var current_score: int = 0
var score_label: Label

func _ready() -> void:
	add_to_group("score_manager")
	reset_score()

func add_score(points: int) -> void:
	current_score += points
	emit_signal("score_changed", current_score)
	update_score_display()

func get_current_score() -> int:
	return current_score

func reset_score() -> void:
	current_score = 0
	emit_signal("score_changed", current_score)
	update_score_display()
	print("ScoreManager: Score resetado para 0")

func set_score_label(label: Label) -> void:
	score_label = label
	update_score_display()

func update_score_display() -> void:
	if score_label:
		score_label.text = "Score: " + str(current_score)

func complete_level() -> void:
	emit_signal("level_completed", current_score)
