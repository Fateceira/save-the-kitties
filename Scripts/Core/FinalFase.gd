extends Control

@export var level_select_scene: PackedScene

@export var mission_label: Label
@export var final_score_label: Label
@export var star1: TextureRect
@export var star2: TextureRect
@export var star3: TextureRect
@export var home_button: TextureButton
@export var restart_button: TextureButton
@export var level_select_button: TextureButton
@export var next_level_button: TextureButton

var current_level: int = 1
var final_score: int = 0
var is_victory: bool = true
var game_progress_singleton: Node

var star_empty_texture: Texture2D = preload("res://assets/sprites/UI/Estrelinha_BG.png")
var star_filled_texture: Texture2D = preload("res://assets/sprites/UI/Estrelinha.png")

var level_scenes: Array[String] = [
	"res://Scenes/Fases/Level1.tscn",
	"res://Scenes/Fases/Level2.tscn", 
	"res://Scenes/Fases/Level3.tscn",
	"res://Scenes/Fases/Level4.tscn",
	"res://Scenes/Fases/Level5.tscn"
]

func _ready() -> void:
	game_progress_singleton = get_singleton_or_create()
	
	if home_button:
		home_button.pressed.connect(_on_home_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if level_select_button:
		level_select_button.pressed.connect(_on_level_select_pressed)
	if next_level_button:
		next_level_button.pressed.connect(_on_next_level_pressed)
	
	setup_stars()

func get_singleton_or_create() -> Node:
	var existing = get_tree().get_first_node_in_group("game_progress_singleton")
	if existing:
		print("FinalFase: Usando GameProgress existente")
		return existing
	
	print("FinalFase: Criando GameProgress temporário")
	var temp_progress = preload("res://Scripts/Core/GameProgress.gd").new()
	temp_progress.add_to_group("game_progress_singleton")
	get_tree().root.add_child(temp_progress)
	return temp_progress

func setup_stars() -> void:
	if star1:
		star1.texture = star_empty_texture
	if star2:
		star2.texture = star_empty_texture
	if star3:
		star3.texture = star_empty_texture

func show_final_screen(score: int, level: int, victory: bool) -> void:
	final_score = score
	current_level = level
	is_victory = victory
	
	if is_victory:
		if mission_label:
			mission_label.text = "Missão Concluída"
		handle_victory_logic()
		update_stars_display()
	else:
		if mission_label:
			mission_label.text = "Missão Falhada"
		clear_stars_display()
	
	if final_score_label:
		final_score_label.text = "Final Score: " + str(final_score)
	
	if next_level_button:
		next_level_button.visible = is_victory and (current_level < level_scenes.size())
	
	visible = true

func handle_victory_logic() -> void:
	if not game_progress_singleton:
		print("FinalFase: ERRO - GameProgress não encontrado!")
		return
	
	if game_progress_singleton.has_method("get_max_unlocked_level") and game_progress_singleton.has_method("unlock_level"):
		if current_level >= game_progress_singleton.get_max_unlocked_level():
			game_progress_singleton.unlock_level(current_level + 1)
	
	if game_progress_singleton.has_method("set_level_score"):
		game_progress_singleton.set_level_score(current_level, final_score)
	
	print("FinalFase: Progresso atualizado!")

func update_stars_display() -> void:
	var stars_earned = calculate_stars(final_score)
	
	var star_nodes = [star1, star2, star3]
	for i in range(star_nodes.size()):
		if star_nodes[i]:
			if i < stars_earned:
				star_nodes[i].texture = star_filled_texture
			else:
				star_nodes[i].texture = star_empty_texture

func clear_stars_display() -> void:
	var star_nodes = [star1, star2, star3]
	for star_node in star_nodes:
		if star_node:
			star_node.texture = star_empty_texture

func calculate_stars(score: int) -> int:
	if score >= 1000:
		return 3
	elif score >= 500:
		return 2
	elif score >= 100:
		return 1
	else:
		return 0

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_level_select_pressed() -> void:
	if level_select_scene:
		get_tree().change_scene_to_packed(level_select_scene)
	else:
		get_tree().change_scene_to_file("res://Scenes/fases.tscn")

func _on_next_level_pressed() -> void:
	if current_level < level_scenes.size():
		get_tree().change_scene_to_file(level_scenes[current_level])
	else:
		print("No more levels available")
