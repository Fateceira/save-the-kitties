@tool
extends Node2D  
class_name CutsceneManager

signal cutscene_started
signal intro_finished
signal outro_finished
signal level_completed

enum CutsceneState {
	IDLE,
	INTRO_MOVING_TO_POSITION,
	INTRO_FINISHED,
	GAMEPLAY_ACTIVE,
	OUTRO_MOVING_TO_CENTER,
	OUTRO_MOVING_UP,
	CUTSCENE_COMPLETE
}

@export_group("Visual Handles")
@export var show_handles: bool = true : set = _set_show_handles
@export var handle_color: Color = Color.CYAN : set = _set_handle_color
@export var handle_size: float = 20.0 : set = _set_handle_size
@export var line_color: Color = Color.YELLOW : set = _set_line_color
@export var line_width: float = 3.0 : set = _set_line_width

@export_group("Intro Cutscene")
@export var intro_start_position: Vector2 = Vector2(640, 600) : set = _set_intro_start
@export var intro_target_position: Vector2 = Vector2(640, 400) : set = _set_intro_target
@export var intro_movement_speed: float = 300.0
@export var intro_movement_smoothing: float = 8.0

@export_group("Outro Cutscene")  
@export var outro_center_position: Vector2 = Vector2(640, 400) : set = _set_outro_center
@export var outro_exit_position: Vector2 = Vector2(640, -200) : set = _set_outro_exit
@export var outro_movement_speed: float = 250.0
@export var outro_movement_smoothing: float = 2.5  
@export var outro_upward_speed: float = 600.0      
@export var completion_delay: float = .1

@export_group("Debug")
@export var debug_mode: bool = true
@export var auto_start_cutscene: bool = true

var current_state: CutsceneState = CutsceneState.IDLE
var player_ref: player = null
var enemy_spawner_ref: EnemySpawner = null
var screen_size: Vector2
var intro_tween: Tween
var outro_tween: Tween
var completion_timer: float = 0.0
var level_completed_flag: bool = false
var player_is_dead: bool = false
var signal_emitted: bool = false

static var instance: CutsceneManager

func _ready() -> void:
	instance = self
	screen_size = get_viewport().get_visible_rect().size
	
	if intro_start_position == Vector2(640, 600) or intro_target_position == Vector2(640, 400) or outro_center_position == Vector2(640, 400):
		_update_default_positions()
	
	if not Engine.is_editor_hint():
		call_deferred("setup_scene_references")
		
		if auto_start_cutscene:
			call_deferred("start_intro_cutscene")

func _update_default_positions() -> void:
	if intro_start_position == Vector2(640, 600):
		intro_start_position = Vector2(screen_size.x * 0.5, screen_size.y + 100)
	if intro_target_position == Vector2(640, 400):
		intro_target_position = screen_size * 0.5
	if outro_center_position == Vector2(640, 400):
		outro_center_position = screen_size * 0.5
	if outro_exit_position == Vector2(640, -200):
		outro_exit_position = Vector2(screen_size.x * 0.5, -200)

func _set_show_handles(value: bool):
	show_handles = value
	queue_redraw()

func _set_handle_color(value: Color):
	handle_color = value
	queue_redraw()

func _set_handle_size(value: float):
	handle_size = value
	queue_redraw()

func _set_line_color(value: Color):
	line_color = value
	queue_redraw()

func _set_line_width(value: float):
	line_width = value
	queue_redraw()

func _set_intro_start(value: Vector2):
	intro_start_position = value
	queue_redraw()

func _set_intro_target(value: Vector2):
	intro_target_position = value
	queue_redraw()

func _set_outro_center(value: Vector2):
	outro_center_position = value
	queue_redraw()

func _set_outro_exit(value: Vector2):
	outro_exit_position = value
	queue_redraw()

func _draw():
	if not show_handles or not Engine.is_editor_hint():
		return
	
	draw_line(intro_start_position, intro_target_position, line_color, line_width)
	draw_line(outro_center_position, outro_exit_position, line_color, line_width)
	
	_draw_handle(intro_start_position, "START", Color.GREEN)
	_draw_handle(intro_target_position, "CENTER", Color.BLUE)
	_draw_handle(outro_center_position, "CENTER", Color.BLUE)
	_draw_handle(outro_exit_position, "EXIT", Color.RED)
	
	_draw_arrow(intro_start_position, intro_target_position, line_color)
	_draw_arrow(outro_center_position, outro_exit_position, line_color)

func _draw_handle(pos: Vector2, label: String, color: Color):
	draw_circle(pos, handle_size, color)
	draw_circle(pos, handle_size, Color.BLACK, false, 2.0)
	
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = pos - Vector2(text_size.x * 0.5, -handle_size - 5)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_arrow(from: Vector2, to: Vector2, color: Color):
	var direction = (to - from).normalized()
	var arrow_length = 20.0
	var arrow_angle = 0.5
	
	var arrow_pos = to - direction * arrow_length
	var arrow_left = arrow_pos + Vector2(-direction.y, direction.x).rotated(arrow_angle) * arrow_length * 0.5
	var arrow_right = arrow_pos + Vector2(direction.y, -direction.x).rotated(-arrow_angle) * arrow_length * 0.5
	
	draw_line(arrow_pos, to, color, line_width)
	draw_line(to, arrow_left, color, line_width)
	draw_line(to, arrow_right, color, line_width)

func setup_scene_references() -> void:
	find_player_reference()
	find_enemy_spawner_reference()
	connect_player_death_signal()
	
	print("CutsceneManager Setup:")
	print("- Player found: ", player_ref != null)
	print("- EnemySpawner found: ", enemy_spawner_ref != null)

func connect_player_death_signal() -> void:
	if player_ref:
		var damageable = player_ref.get_node("DamageableComponent")
		if damageable and damageable.has_signal("died"):
			damageable.died.connect(_on_player_died)
			print("CutsceneManager: Player death signal conectado")

func _on_player_died() -> void:
	print("CutsceneManager: Player morreu - parando cutscenes")
	player_is_dead = true
	current_state = CutsceneState.CUTSCENE_COMPLETE

func find_player_reference() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as player
	else:
		player_ref = get_tree().current_scene.find_child("Player", true, false) as player
	
	if not player_ref:
		push_error("CutsceneManager: Player não encontrado na cena!")

func find_enemy_spawner_reference() -> void:
	var spawners = get_tree().get_nodes_in_group("enemy_spawner")
	if spawners.size() > 0:
		enemy_spawner_ref = spawners[0] as EnemySpawner
	else:
		enemy_spawner_ref = find_node_of_type(get_tree().current_scene, EnemySpawner) as EnemySpawner
	
	if not enemy_spawner_ref:
		print("CutsceneManager: EnemySpawner não encontrado - gameplay manual")

func find_node_of_type(node: Node, type) -> Node:
	if node.get_script() and node.get_script().get_global_name() == type.get_global_name():
		return node
	
	for child in node.get_children():
		var result = find_node_of_type(child, type)
		if result:
			return result
	
	return null

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if player_is_dead:
		return
		
	match current_state:
		CutsceneState.INTRO_MOVING_TO_POSITION:
			process_intro_movement(delta)
		
		CutsceneState.GAMEPLAY_ACTIVE:
			check_for_level_completion()
		
		CutsceneState.OUTRO_MOVING_TO_CENTER:
			process_outro_center_movement(delta)
		
		CutsceneState.OUTRO_MOVING_UP:
			process_outro_upward_movement(delta)
		
		CutsceneState.CUTSCENE_COMPLETE:
			process_completion_delay(delta)

func start_intro_cutscene() -> void:
	if not player_ref or player_is_dead:
		print("CutsceneManager: Não pode iniciar intro - Player ref: ", player_ref != null, " Player dead: ", player_is_dead)
		return
	
	player_ref.global_position = intro_start_position
	
	current_state = CutsceneState.INTRO_MOVING_TO_POSITION
	player_ref.set_cutscene_mode(true)
	cutscene_started.emit()
	
	print("CutsceneManager: Iniciando cutscene de intro")

func process_intro_movement(delta: float) -> void:
	if not player_ref or player_is_dead:
		return
	
	var current_pos = player_ref.global_position
	var distance_to_target = current_pos.distance_to(intro_target_position)
	
	if distance_to_target < .1:
		finish_intro_cutscene()
		return
	
	var lerp_factor = min(intro_movement_smoothing * delta, 1.0)
	player_ref.global_position = player_ref.global_position.lerp(intro_target_position, lerp_factor)

func finish_intro_cutscene() -> void:
	if player_is_dead:
		return
		
	current_state = CutsceneState.INTRO_FINISHED
	player_ref.global_position = intro_target_position
	
	print("CutsceneManager: Cutscene de intro finalizada")
	intro_finished.emit()
	start_gameplay()

func start_gameplay() -> void:
	if player_is_dead:
		return
		
	current_state = CutsceneState.GAMEPLAY_ACTIVE
	player_ref.set_cutscene_mode(false)
	
	if enemy_spawner_ref:
		enemy_spawner_ref.set_cutscene_active(false)
	
	print("CutsceneManager: Gameplay iniciado - controles liberados")

func check_for_level_completion() -> void:
	if not enemy_spawner_ref or level_completed_flag or player_is_dead:
		return
	
	var spawner_finished = enemy_spawner_ref.is_finished()
	var enemies_remaining = get_remaining_enemies_count()
	
	if spawner_finished:
		print("CutsceneManager: EnemySpawner finalizado. Inimigos restantes: ", enemies_remaining)
	
	if spawner_finished and enemies_remaining == 0:
		print("CutsceneManager: Condições para outro cutscene atendidas!")
		level_completed_flag = true
		start_outro_cutscene()

func get_remaining_enemies_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func start_outro_cutscene() -> void:
	if not player_ref or player_is_dead:
		print("CutsceneManager: Não pode iniciar outro - Player ref: ", player_ref != null, " Player dead: ", player_is_dead)
		complete_level()
		return
	
	print("CutsceneManager: Iniciando cutscene de outro")
	
	current_state = CutsceneState.OUTRO_MOVING_TO_CENTER
	player_ref.set_cutscene_mode(true)

func process_outro_center_movement(delta: float) -> void:
	if not player_ref or player_is_dead:
		print("CutsceneManager: Player perdido durante outro center - completando level")
		complete_level()
		return
	
	var current_pos = player_ref.global_position
	var distance_to_center = current_pos.distance_to(outro_center_position)
	
	if distance_to_center < 5.0:
		print("CutsceneManager: Player chegou ao centro, iniciando movimento para cima")
		start_outro_upward_movement()
		return
	
	var lerp_factor = min(outro_movement_smoothing * delta, 1.0)
	
	if distance_to_center < 80.0:
		var decel_factor = distance_to_center / 80.0
		lerp_factor *= max(decel_factor, 0.3)  
	
	player_ref.global_position = player_ref.global_position.lerp(outro_center_position, lerp_factor)

func start_outro_upward_movement() -> void:
	if player_is_dead:
		print("CutsceneManager: Player morto durante start upward - completando level")
		complete_level()
		return
		
	current_state = CutsceneState.OUTRO_MOVING_UP
	player_ref.global_position = outro_center_position
	
	if player_ref:
		player_ref.disable_collisions()
	
	print("CutsceneManager: Iniciando movimento para cima - destino: ", outro_exit_position)

func process_outro_upward_movement(delta: float) -> void:
	if not player_ref or player_is_dead:
		print("CutsceneManager: Player perdido durante upward movement - completando level")
		complete_level()
		return
	
	var current_pos = player_ref.global_position
	var distance_to_exit = current_pos.distance_to(outro_exit_position)
	
	if distance_to_exit < 5.0:
		print("CutsceneManager: Player chegou à posição de saída")
		finish_outro_cutscene()
		return
	
	var lerp_factor = min((outro_upward_speed / 100.0) * delta, 1.0)
	
	var movement_progress = 1.0 - (distance_to_exit / outro_center_position.distance_to(outro_exit_position))
	var acceleration_factor = min(movement_progress * 2.0 + 0.5, 1.0)
	
	lerp_factor *= acceleration_factor
	
	player_ref.global_position = player_ref.global_position.lerp(outro_exit_position, lerp_factor)

func finish_outro_cutscene() -> void:
	current_state = CutsceneState.CUTSCENE_COMPLETE
	completion_timer = completion_delay
	
	print("CutsceneManager: Cutscene de outro finalizada - Timer: ", completion_delay, " segundos")
	outro_finished.emit()

func process_completion_delay(delta: float) -> void:
	if signal_emitted:
		return
		
	completion_timer -= delta
	
	if completion_timer <= 0.0:
		print("CutsceneManager: Timer zerado - chamando complete_level()")
		complete_level()

func complete_level() -> void:
	if signal_emitted:
		print("CutsceneManager: Signal já foi emitido - ignorando")
		return
	
	signal_emitted = true
	level_completed_flag = true
	
	print("CutsceneManager: 🚀🚀🚀 EMITINDO SIGNAL level_completed!!! 🚀🚀🚀")
	level_completed.emit()
	
	print("CutsceneManager: === FASE COMPLETADA ===")

func show_completion_screen() -> void:
	if level_completed_flag:
		print("NÍVEL COMPLETADO!")
		current_state = CutsceneState.CUTSCENE_COMPLETE

func force_finish() -> void:
	current_state = CutsceneState.CUTSCENE_COMPLETE
	level_completed_flag = true
	player_is_dead = true
	print("CutsceneManager: Forçadamente finalizado")

func force_start_intro() -> void:
	if current_state == CutsceneState.IDLE and not player_is_dead:
		start_intro_cutscene()

func force_start_outro() -> void:
	if current_state == CutsceneState.GAMEPLAY_ACTIVE and not level_completed_flag and not player_is_dead:
		start_outro_cutscene()

func skip_intro() -> void:
	if current_state == CutsceneState.INTRO_MOVING_TO_POSITION:
		finish_intro_cutscene()

func is_cutscene_active() -> bool:
	return current_state != CutsceneState.IDLE and current_state != CutsceneState.GAMEPLAY_ACTIVE

func get_current_state() -> CutsceneState:
	return current_state

func set_intro_positions(start: Vector2, target: Vector2) -> void:
	intro_start_position = start
	intro_target_position = target
	queue_redraw()

func set_outro_positions(center: Vector2, exit: Vector2) -> void:
	outro_center_position = center
	outro_exit_position = exit
	queue_redraw()

func reset_level_completion() -> void:
	level_completed_flag = false
	player_is_dead = false
	signal_emitted = false
	current_state = CutsceneState.IDLE
	print("CutsceneManager: Flag de conclusão resetada")

static func start_intro() -> void:
	if instance:
		instance.force_start_intro()

static func start_outro() -> void:
	if instance:
		instance.force_start_outro()

static func is_active() -> bool:
	if instance:
		return instance.is_cutscene_active()
	return false
