extends Node2D
class_name EnemySpawner

@export var spawn_area_width: float = 1145.0
@export var spawn_area_height: float = 100.0
@export var wave_list: Array[WaveData] = []
@export var debug_draw_color: Color = Color(1, 0, 0, 0.5)
@export var screen_margin: float = 50.0
@export var viper_path_spacing: float = 0.15
@export var max_total_enemies: int = 8
@export var min_spawn_distance: float = 80.0
@export var max_spawn_attempts: int = 10
@export var zigzag_spawn_variation: float = 150.0
@export var initial_spawn_delay: float = 0
@export var boss_spawn_position_offset: Vector2 = Vector2(0, -100)

@export_group("Cutscene Integration")
@export var wait_for_cutscene: bool = true
@export var cutscene_delay: float = 0 

@export_group("Enemy Cleanup")
@export var cleanup_enabled: bool = true
@export var cleanup_margin: float = 200.0 
@export var cleanup_interval: float = 1.0  
@export var debug_cleanup: bool = false     

enum SpawnerState {
	WAITING_FOR_CUTSCENE,
	WAITING_TO_START,
	SHOWING_DIALOG,
	SPAWNING_WAVE,
	WAVE_BREAK,
	WAITING_FOR_ENEMIES_TO_DIE,  
	SHOWING_POST_WAVE_DIALOG,    
	FINISHED
}

var current_state: SpawnerState = SpawnerState.WAITING_FOR_CUTSCENE
var current_wave_index: int = 0
var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var cleanup_timer: float = 0.0
var screen_size: Vector2
var spawner_node: Node2D
var available_paths: Array[Path2D] = []
var last_used_path: Path2D = null
var path_usage_history: Array[Path2D] = []
var max_history_size: int = 3
var recent_spawn_positions: Array[Vector2] = []
var boss_spawned_in_current_wave: bool = false
var dialog_connection_made: bool = false
var cutscene_active: bool = true

var wave_spawn_finished: bool = false
var post_wave_dialog_delay: float = 0.0

func _ready() -> void:
	add_to_group("enemy_spawner")
	
	screen_size = get_viewport().get_visible_rect().size
	spawner_node = get_node("Spawner")
	collect_available_paths()
	call_deferred("setup_dialog_connection")
	call_deferred("setup_cutscene_connection")
	
	if wait_for_cutscene:
		current_state = SpawnerState.WAITING_FOR_CUTSCENE
		print("EnemySpawner: Aguardando cutscene de intro...")
	else:
		start_spawning()

func setup_dialog_connection() -> void:
	if DialogManager.instance and not dialog_connection_made:
		DialogManager.instance.dialog_finished.connect(_on_dialog_finished)
		dialog_connection_made = true

func setup_cutscene_connection() -> void:
	if CutsceneManager.instance:
		CutsceneManager.instance.intro_finished.connect(_on_cutscene_intro_finished)
		print("EnemySpawner: Conectado ao CutsceneManager")

func _on_cutscene_intro_finished() -> void:
	if current_state == SpawnerState.WAITING_FOR_CUTSCENE:
		print("EnemySpawner: Cutscene de intro finalizada - iniciando spawning")
		cutscene_active = false
		start_spawning()

func start_spawning() -> void:
	current_wave_index = 0
	cleanup_timer = cleanup_interval
	
	if current_wave_index < wave_list.size():
		var first_wave = wave_list[current_wave_index]
		
		if should_show_dialog(first_wave):
			current_state = SpawnerState.SHOWING_DIALOG
			show_wave_dialog(first_wave)
			print("EnemySpawner: Mostrando diálogo pré-wave imediatamente após cutscene")
			return
	
	current_state = SpawnerState.WAITING_TO_START
	wave_timer = initial_spawn_delay
	
	print("EnemySpawner: Aguardando ", wave_timer, " segundos para iniciar primeira wave")

func collect_available_paths() -> void:
	var paths_node = get_node("Paths")
	if paths_node:
		for child in paths_node.get_children():
			if child is Path2D:
				available_paths.append(child)

func _process(delta: float) -> void:
	wave_timer -= delta
	post_wave_dialog_delay -= delta
	
	if cleanup_enabled:
		cleanup_timer -= delta
		if cleanup_timer <= 0.0:
			cleanup_offscreen_enemies()
			cleanup_timer = cleanup_interval
	
	match current_state:
		SpawnerState.WAITING_FOR_CUTSCENE:
			pass
		
		SpawnerState.WAITING_TO_START:
			if wave_timer <= 0.0:
				start_next_wave()
		
		SpawnerState.SHOWING_DIALOG:
			pass
		
		SpawnerState.SPAWNING_WAVE:
			handle_wave_spawning(delta)
		
		SpawnerState.WAITING_FOR_ENEMIES_TO_DIE:
			check_if_all_enemies_dead()
		
		SpawnerState.SHOWING_POST_WAVE_DIALOG:
			pass
		
		SpawnerState.WAVE_BREAK:
			if wave_timer <= 0.0:
				advance_to_next_wave()
		
		SpawnerState.FINISHED:
			pass


func cleanup_offscreen_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var camera = get_viewport().get_camera_2d()
	var cleanup_bounds = get_cleanup_bounds(camera)
	var enemies_removed = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		if enemy.is_in_group("boss"):
			continue
		
		var enemy_pos = enemy.global_position
		
		if is_enemy_outside_bounds(enemy_pos, cleanup_bounds):
			if debug_cleanup:
				print("EnemySpawner: Removendo inimigo fora da tela em ", enemy_pos)
			
			enemy.queue_free()
			enemies_removed += 1
	
	if debug_cleanup and enemies_removed > 0:
		print("EnemySpawner: ", enemies_removed, " inimigos removidos da tela")

func get_cleanup_bounds(camera: Camera2D) -> Rect2:
	var bounds: Rect2
	
	if camera:
		var camera_pos = camera.global_position
		var half_screen = screen_size * 0.5
		
		bounds = Rect2(
			camera_pos.x - half_screen.x - cleanup_margin,
			camera_pos.y - half_screen.y - cleanup_margin,
			screen_size.x + cleanup_margin * 2,
			screen_size.y + cleanup_margin * 2
		)
	else:
		bounds = Rect2(
			-cleanup_margin,
			-cleanup_margin,
			screen_size.x + cleanup_margin * 2,
			screen_size.y + cleanup_margin * 2
		)
	
	return bounds

func is_enemy_outside_bounds(enemy_pos: Vector2, bounds: Rect2) -> bool:
	return not bounds.has_point(enemy_pos)


func start_next_wave() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		print("EnemySpawner: Todas as waves foram completadas! Estado: FINISHED")
		return
	
	var current_wave = wave_list[current_wave_index]
	
	print("EnemySpawner: Iniciando wave ", current_wave_index + 1, "/", wave_list.size(), " - ", current_wave.wave_name)
	
	if should_show_dialog(current_wave):
		show_wave_dialog(current_wave)
	else:
		begin_wave_spawning()

func should_show_dialog(wave_data: WaveData) -> bool:
	return wave_data.has_pre_wave_dialog and wave_data.pre_wave_dialog_id != ""

func show_wave_dialog(wave_data: WaveData) -> void:
	current_state = SpawnerState.SHOWING_DIALOG
	if DialogManager.instance:
		DialogManager.start_dialog(wave_data.pre_wave_dialog_id)

func begin_wave_spawning() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		return
	
	var current_wave = wave_list[current_wave_index]
	current_state = SpawnerState.SPAWNING_WAVE
	wave_timer = current_wave.wave_duration
	spawn_timer = 0.0
	boss_spawned_in_current_wave = false
	wave_spawn_finished = false 
	
	print("EnemySpawner: Wave ", current_wave_index + 1, " em progresso")
	
	if current_wave.is_boss_wave:
		spawn_boss_immediately(current_wave)
		wave_spawn_finished = true 

func spawn_boss_immediately(wave_data: WaveData) -> void:
	if wave_data.enemy_spawns.size() == 0:
		return
	
	var boss_spawn_data = wave_data.enemy_spawns[0]
	spawn_boss_enemy(boss_spawn_data)
	boss_spawned_in_current_wave = true
	
	print("EnemySpawner: Boss spawnado para wave ", current_wave_index + 1)

func spawn_boss_enemy(data: SpawnData) -> void:
	if not data.enemy_scene:
		return
	
	var boss = data.enemy_scene.instantiate()
	boss.add_to_group("enemies")
	boss.add_to_group("boss")
	
	var boss_position = get_boss_spawn_position()
	boss.global_position = boss_position
	
	get_tree().current_scene.add_child(boss)

func get_boss_spawn_position() -> Vector2:
	var center_x = spawner_node.global_position.x
	var boss_y = spawner_node.global_position.y + boss_spawn_position_offset.y
	return Vector2(center_x, boss_y)

func handle_wave_spawning(delta: float) -> void:
	if current_wave_index >= wave_list.size():
		return
	
	var current_wave = wave_list[current_wave_index]
	
	if current_wave.is_boss_wave:
		check_boss_wave_completion()
		return
	
	if not wave_spawn_finished:
		spawn_timer -= delta
		
		if spawn_timer <= 0.0:
			attempt_spawn_from_wave(current_wave)
			spawn_timer = current_wave.spawn_delay
		
		if wave_timer <= 0.0:
			wave_spawn_finished = true
			print("EnemySpawner: Tempo da wave ", current_wave_index + 1, " esgotado - parando spawn, aguardando inimigos morrerem")
	
	if wave_spawn_finished:
		var remaining_enemies = get_total_enemy_count()
		if remaining_enemies == 0:
			print("EnemySpawner: Todos os inimigos da wave ", current_wave_index + 1, " foram eliminados")
			finish_current_wave()

func check_boss_wave_completion() -> void:
	var bosses = get_tree().get_nodes_in_group("boss")
	
	if bosses.size() == 0:
		print("EnemySpawner: Boss derrotado - wave ", current_wave_index + 1, " completada")
		finish_current_wave()

func finish_current_wave() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		return
	
	var current_wave = wave_list[current_wave_index]
	
	print("EnemySpawner: Wave ", current_wave_index + 1, " finalizada")
	
	if current_wave.has_post_wave_dialog and current_wave.post_wave_dialog_id != "":
		current_state = SpawnerState.WAITING_FOR_ENEMIES_TO_DIE
		post_wave_dialog_delay = 0.01  
		print("EnemySpawner: Preparando diálogo pós-wave...")
	else:
		start_wave_break()

func check_if_all_enemies_dead() -> void:
	var remaining_enemies = get_total_enemy_count()
	
	if remaining_enemies > 0:
		print("EnemySpawner: Ainda há ", remaining_enemies, " inimigos na cena - aguardando...")
		return
	
	if post_wave_dialog_delay <= 0.0:
		show_post_wave_dialog()

func show_post_wave_dialog() -> void:
	if current_wave_index >= wave_list.size():
		return
		
	var current_wave = wave_list[current_wave_index]
	
	if current_wave.has_post_wave_dialog and current_wave.post_wave_dialog_id != "":
		current_state = SpawnerState.SHOWING_POST_WAVE_DIALOG
		print("EnemySpawner: Mostrando diálogo pós-wave: ", current_wave.post_wave_dialog_id)
		DialogManager.start_dialog(current_wave.post_wave_dialog_id)
	else:
		start_wave_break()

func start_wave_break() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		return
	
	var current_wave = wave_list[current_wave_index]
	current_state = SpawnerState.WAVE_BREAK
	wave_timer = current_wave.break_duration
	
	print("EnemySpawner: Intervalo entre waves - ", wave_timer, " segundos")

func advance_to_next_wave() -> void:
	current_wave_index += 1
	
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		print("EnemySpawner: Todas as waves completadas! Estado: FINISHED")
		return
	
	start_next_wave()

func _on_dialog_finished() -> void:
	match current_state:
		SpawnerState.SHOWING_DIALOG:
			print("EnemySpawner: Diálogo pré-wave finalizado - iniciando wave")
			begin_wave_spawning()
		
		SpawnerState.SHOWING_POST_WAVE_DIALOG:
			print("EnemySpawner: Diálogo pós-wave finalizado - iniciando intervalo")
			start_wave_break()


func attempt_spawn_from_wave(wave_data: WaveData) -> void:
	if get_total_enemy_count() >= max_total_enemies:
		return
	
	var valid_spawns: Array[SpawnData] = []
	for spawn_data in wave_data.enemy_spawns:
		if randf() <= spawn_data.spawn_chance:
			valid_spawns.append(spawn_data)
	
	if valid_spawns.size() == 0:
		return
	
	var enemies_to_spawn = min(wave_data.enemies_per_spawn, max_total_enemies - get_total_enemy_count())
	
	for i in enemies_to_spawn:
		var selected_spawn = valid_spawns[randi() % valid_spawns.size()]
		spawn_enemy_from_data(selected_spawn)

func get_total_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func cleanup_old_spawn_positions() -> void:
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	var active_positions: Array[Vector2] = []
	
	for enemy in current_enemies:
		if is_instance_valid(enemy) and enemy.has_method("get_global_position"):
			active_positions.append(enemy.global_position)
	
	recent_spawn_positions = active_positions

func is_position_too_close(position: Vector2) -> bool:
	cleanup_old_spawn_positions()
	
	for spawn_pos in recent_spawn_positions:
		if position.distance_to(spawn_pos) < min_spawn_distance:
			return true
	return false

func get_valid_spawn_position() -> Vector2:
	var attempts = 0
	var spawn_position: Vector2
	
	while attempts < max_spawn_attempts:
		spawn_position = get_spawn_position()
		
		if not is_position_too_close(spawn_position):
			recent_spawn_positions.append(spawn_position)
			return spawn_position
		
		attempts += 1
	
	spawn_position = get_spawn_position()
	recent_spawn_positions.append(spawn_position)
	return spawn_position

func get_zigzag_spawn_position() -> Vector2:
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var camera = get_viewport().get_camera_2d()
	
	var center_x: float
	if camera:
		center_x = camera.global_position.x
	else:
		center_x = viewport_size.x / 2.0
	
	var variation_x = randf_range(-zigzag_spawn_variation * 0.5, zigzag_spawn_variation * 0.5)
	var final_x = center_x + variation_x
	
	var spawn_y = spawner_node.global_position.y
	
	return Vector2(final_x, spawn_y)

func get_best_path_for_spawn() -> Path2D:
	if available_paths.size() == 0:
		return null
	
	if available_paths.size() == 1:
		return available_paths[0]
	
	var valid_paths: Array[Path2D] = []
	
	for path in available_paths:
		if not path_usage_history.has(path):
			valid_paths.append(path)
	
	if valid_paths.size() == 0:
		for path in available_paths:
			if path != last_used_path:
				valid_paths.append(path)
	
	if valid_paths.size() == 0:
		valid_paths = available_paths.duplicate()
	
	var selected_path = valid_paths[randi() % valid_paths.size()]
	update_path_history(selected_path)
	return selected_path

func update_path_history(used_path: Path2D) -> void:
	last_used_path = used_path
	path_usage_history.append(used_path)
	while path_usage_history.size() > max_history_size:
		path_usage_history.pop_front()

func spawn_enemy_from_data(data: SpawnData) -> void:
	if not data.enemy_scene:
		return
	
	var temp_enemy = data.enemy_scene.instantiate()
	var is_viper = temp_enemy is ViperEnemy
	var is_zigzag = temp_enemy is ZigZagEnemy
	temp_enemy.queue_free()
	
	if is_viper:
		spawn_viper_formation(data)
	elif is_zigzag:
		spawn_zigzag_formation(data)
	elif data.formation_count <= 1:
		spawn_single_enemy(data)
	else:
		spawn_formation(data)

func spawn_zigzag_formation(data: SpawnData) -> void:
	var formation_size = max(1, data.formation_count)
	
	for i in formation_size:
		var spawn_position = get_zigzag_spawn_position()
		
		var enemy = data.enemy_scene.instantiate()
		enemy.add_to_group("enemies")
		enemy.global_position = spawn_position
		get_tree().current_scene.add_child(enemy)
		
		if enemy.has_method("set_movement_direction"):
			var direction = 1 if i % 2 == 0 else -1
			enemy.set_movement_direction(direction)
		
		recent_spawn_positions.append(spawn_position)

func spawn_viper_formation(data: SpawnData) -> void:
	var selected_path = get_best_path_for_spawn()
	if not selected_path:
		spawn_formation(data)
		return
	
	var formation_size = max(1, data.formation_count)
	
	if selected_path.curve:
		var initial_position = selected_path.global_position + selected_path.curve.sample_baked(0)
		recent_spawn_positions.append(initial_position)
	
	for i in formation_size:
		var enemy = data.enemy_scene.instantiate()
		enemy.add_to_group("enemies")
		get_tree().current_scene.add_child(enemy)
		var progress_offset = i * viper_path_spacing
		if enemy.has_method("setup_path_follow"):
			enemy.setup_path_follow(selected_path, progress_offset)

func spawn_single_enemy(data: SpawnData) -> void:
	var enemy = data.enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	
	var spawn_position = get_valid_spawn_position()
	enemy.global_position = spawn_position
	get_tree().current_scene.add_child(enemy)

func spawn_formation(data: SpawnData) -> void:
	var formation_size = data.formation_count
	var total_width = (formation_size - 1) * data.enemy_spacing
	
	var formation_start = get_valid_spawn_position()
	var start_x = formation_start.x - total_width * 0.5
	
	for i in formation_size:
		var enemy = data.enemy_scene.instantiate()
		enemy.add_to_group("enemies")
		
		var offset_x = start_x + i * data.enemy_spacing
		var spawn_pos = Vector2(offset_x, formation_start.y)
		
		enemy.global_position = spawn_pos
		get_tree().current_scene.add_child(enemy)
		
		recent_spawn_positions.append(spawn_pos)

func get_spawn_position() -> Vector2:
	var spawn_width = spawn_area_width - screen_margin * 2
	var random_x = randf_range(-spawn_width * 0.5, spawn_width * 0.5)
	return spawner_node.global_position + Vector2(random_x, 0)

func _draw() -> void:
	if spawner_node:
		var rect_pos = spawner_node.position + Vector2(-spawn_area_width * 0.5, 0)
		draw_rect(Rect2(rect_pos, Vector2(spawn_area_width, spawn_area_height)), debug_draw_color, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func get_current_wave_info() -> String:
	if current_wave_index >= wave_list.size():
		return "Finalizado"
	
	var wave = wave_list[current_wave_index]
	var state_text = ""
	
	match current_state:
		SpawnerState.WAITING_FOR_CUTSCENE:
			state_text = "Aguardando cutscene"
		SpawnerState.WAITING_TO_START:
			state_text = "Aguardando início"
		SpawnerState.SHOWING_DIALOG:
			state_text = "Mostrando diálogo pré-wave"
		SpawnerState.SPAWNING_WAVE:
			if wave.is_boss_wave:
				state_text = "Boss em combate"
			else:
				state_text = "Em progresso"
		SpawnerState.WAITING_FOR_ENEMIES_TO_DIE:
			state_text = "Aguardando inimigos morrerem"
		SpawnerState.SHOWING_POST_WAVE_DIALOG:
			state_text = "Mostrando diálogo pós-wave"
		SpawnerState.WAVE_BREAK:
			state_text = "Intervalo"
		SpawnerState.FINISHED:
			state_text = "Finalizado"
	
	return wave.wave_name + " - " + state_text

func force_next_wave() -> void:
	if current_state == SpawnerState.SPAWNING_WAVE:
		finish_current_wave()


func set_cutscene_active(active: bool) -> void:
	cutscene_active = active
	
	if not active and current_state == SpawnerState.WAITING_FOR_CUTSCENE:
		start_spawning()
	
	print("EnemySpawner: Cutscene mode ", "ATIVO" if active else "INATIVO")

func is_finished() -> bool:
	return current_state == SpawnerState.FINISHED

func get_current_state() -> SpawnerState:
	return current_state

func force_finish() -> void:
	current_state = SpawnerState.FINISHED
	print("EnemySpawner: Forçadamente finalizado")

func restart_spawning() -> void:
	current_wave_index = 0
	current_state = SpawnerState.WAITING_TO_START
	wave_timer = initial_spawn_delay
	boss_spawned_in_current_wave = false
	wave_spawn_finished = false
	recent_spawn_positions.clear()
	cleanup_timer = cleanup_interval
	
	print("EnemySpawner: Sistema reiniciado")

func enable_cleanup(enabled: bool) -> void:
	cleanup_enabled = enabled
	print("EnemySpawner: Sistema de limpeza ", "ATIVADO" if enabled else "DESATIVADO")

func set_cleanup_margin(margin: float) -> void:
	cleanup_margin = margin
	print("EnemySpawner: Margem de limpeza alterada para ", margin)

func set_cleanup_interval(interval: float) -> void:
	cleanup_interval = interval
	cleanup_timer = interval
	print("EnemySpawner: Intervalo de limpeza alterado para ", interval)

func force_cleanup() -> void:
	cleanup_offscreen_enemies()
	print("EnemySpawner: Limpeza forçada executada")

static func get_spawner() -> EnemySpawner:
	var spawners = Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("enemy_spawner")
	if spawners.size() > 0:
		return spawners[0] as EnemySpawner
	return null
