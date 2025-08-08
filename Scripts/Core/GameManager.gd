extends Node

@export var final_screen_scene: PackedScene

var score_manager: Node
var final_screen: Control
var player: Node
var cutscene_manager: CutsceneManager
var enemies_remaining: int = 0
var level_complete: bool = false
var current_level: int = 1
var player_died: bool = false
var game_progress_singleton: Node

func _ready() -> void:
	current_level = get_level_from_scene_name()
	game_progress_singleton = get_singleton_or_create()
	setup_game_components()
	count_initial_enemies()
	connect_player_signals()
	call_deferred("connect_cutscene_signals")
	
	print("GameManager iniciado - Level: ", current_level)

func get_singleton_or_create() -> Node:
	# Tenta encontrar na árvore
	var existing = get_tree().get_first_node_in_group("game_progress_singleton")
	if existing:
		print("GameManager: Usando GameProgress existente")
		return existing
	
	# Se não encontrar, cria um novo
	print("GameManager: Criando GameProgress temporário")
	var temp_progress = preload("res://Scripts/Core/GameProgress.gd").new()
	temp_progress.add_to_group("game_progress_singleton")
	get_tree().root.add_child(temp_progress)
	return temp_progress

func get_level_from_scene_name() -> int:
	var scene_file = get_tree().current_scene.scene_file_path
	var scene_name = scene_file.get_file().get_basename()
	
	if scene_name.begins_with("Level"):
		var level_string = scene_name.substr(5)
		return int(level_string)
	
	return 1

func setup_game_components() -> void:
	score_manager = get_tree().get_first_node_in_group("score_manager")
	if not score_manager:
		score_manager = preload("res://Scripts/Core/ScoreManager.gd").new()
		add_child(score_manager)
	
	if score_manager.has_method("reset_score"):
		score_manager.reset_score()
	
	setup_final_screen()
	
	var score_ui = get_tree().get_first_node_in_group("score_display")
	if score_ui and score_ui.has_method("get_score_label"):
		var score_label = score_ui.get_score_label()
		if score_manager.has_method("set_score_label"):
			score_manager.set_score_label(score_label)

func setup_final_screen() -> void:
	if not final_screen_scene:
		final_screen_scene = load("res://Scenes/FinalFase.tscn")
	
	if final_screen_scene:
		final_screen = final_screen_scene.instantiate()
		final_screen.visible = false
		add_child(final_screen)
		print("GameManager: Final screen configurado")

func connect_cutscene_signals() -> void:
	cutscene_manager = CutsceneManager.instance
	if cutscene_manager:
		cutscene_manager.level_completed.connect(_on_cutscene_level_completed)
		print("GameManager: Conectado ao CutsceneManager")

func count_initial_enemies() -> void:
	enemies_remaining = get_tree().get_nodes_in_group("enemies").size()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_signal("tree_exiting"):
			enemy.tree_exiting.connect(_on_enemy_destroyed)

func connect_player_signals() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		var damageable = player.get_node("DamageableComponent")
		if damageable and damageable.has_signal("died"):
			damageable.died.connect(_on_player_died)

func _on_enemy_destroyed() -> void:
	enemies_remaining -= 1

func _on_cutscene_level_completed() -> void:
	print("GameManager: 🎉 Fase completada!")
	if not player_died:
		trigger_victory()

func trigger_victory() -> void:
	print("GameManager: 🏆 TRIGGER VICTORY!")
	var final_score = 0
	if score_manager and score_manager.has_method("get_current_score"):
		final_score = score_manager.get_current_score()
	
	# USA A INSTÂNCIA DO GAMEPRROGRESS
	if game_progress_singleton and game_progress_singleton.has_method("complete_level"):
		game_progress_singleton.complete_level(current_level, final_score)
		print("GameManager: ✅ Progresso salvo! Desbloqueados: ", game_progress_singleton.unlocked_levels)
	else:
		print("GameManager: ❌ ERRO: GameProgress não encontrado!")
	
	if final_screen and final_screen.has_method("show_final_screen"):
		final_screen.show_final_screen(final_score, current_level, true)

func _on_player_died() -> void:
	print("GameManager: 💀 Player morreu!")
	player_died = true
	
	if cutscene_manager:
		cutscene_manager.force_finish()
	
	var final_score = 0
	if score_manager and score_manager.has_method("get_current_score"):
		final_score = score_manager.get_current_score()
	
	if final_screen and final_screen.has_method("show_final_screen"):
		final_screen.show_final_screen(final_score, current_level, false)

func add_enemy_to_count() -> void:
	enemies_remaining += 1

func get_enemies_remaining() -> int:
	return enemies_remaining
