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
@export var initial_spawn_delay: float = 2.0
@export var boss_spawn_position_offset: Vector2 = Vector2(0, -100)

enum SpawnerState {
	WAITING_TO_START,
	SPAWNING_WAVE,
	WAVE_BREAK,
	FINISHED
}

var current_state: SpawnerState = SpawnerState.WAITING_TO_START
var current_wave_index: int = 0
var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var screen_size: Vector2
var spawner_node: Node2D
var available_paths: Array[Path2D] = []
var last_used_path: Path2D = null
var path_usage_history: Array[Path2D] = []
var max_history_size: int = 3
var recent_spawn_positions: Array[Vector2] = []
var boss_spawned_in_current_wave: bool = false

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawner_node = get_node("Spawner")
	collect_available_paths()
	start_spawning()

func start_spawning() -> void:
	current_state = SpawnerState.WAITING_TO_START
	wave_timer = initial_spawn_delay
	current_wave_index = 0

func collect_available_paths() -> void:
	var paths_node = get_node("Paths")
	if paths_node:
		for child in paths_node.get_children():
			if child is Path2D:
				available_paths.append(child)

func _process(delta: float) -> void:
	wave_timer -= delta
	
	match current_state:
		SpawnerState.WAITING_TO_START:
			if wave_timer <= 0.0:
				start_current_wave()
		
		SpawnerState.SPAWNING_WAVE:
			handle_wave_spawning(delta)
		
		SpawnerState.WAVE_BREAK:
			if wave_timer <= 0.0:
				next_wave()
		
		SpawnerState.FINISHED:
			pass

func start_current_wave() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		return
	
	var current_wave = wave_list[current_wave_index]
	current_state = SpawnerState.SPAWNING_WAVE
	wave_timer = current_wave.wave_duration
	spawn_timer = 0.0
	boss_spawned_in_current_wave = false
	
	print("Iniciando ", current_wave.wave_name)
	
	if current_wave.is_boss_wave:
		spawn_boss_immediately(current_wave)

func spawn_boss_immediately(wave_data: WaveData) -> void:
	if wave_data.enemy_spawns.size() == 0:
		return
	
	var boss_spawn_data = wave_data.enemy_spawns[0]
	spawn_boss_enemy(boss_spawn_data)
	boss_spawned_in_current_wave = true
	
	print("Boss spawnado na wave: ", wave_data.wave_name)

func spawn_boss_enemy(data: SpawnData) -> void:
	if not data.enemy_scene:
		return
	
	var boss = data.enemy_scene.instantiate()
	boss.add_to_group("enemies")
	boss.add_to_group("boss")
	
	var boss_position = get_boss_spawn_position()
	boss.global_position = boss_position
	
	get_tree().current_scene.add_child(boss)
	
	print("Boss spawnado em posição fixa: ", boss_position)

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
	
	spawn_timer -= delta
	
	if spawn_timer <= 0.0:
		attempt_spawn_from_wave(current_wave)
		spawn_timer = current_wave.spawn_delay
	
	if wave_timer <= 0.0:
		end_current_wave()

func check_boss_wave_completion() -> void:
	var bosses = get_tree().get_nodes_in_group("boss")
	
	if bosses.size() == 0:
		end_current_wave()

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

func end_current_wave() -> void:
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		return
	
	var current_wave = wave_list[current_wave_index]
	current_state = SpawnerState.WAVE_BREAK
	wave_timer = current_wave.break_duration
	
	if current_wave.is_boss_wave:
		print("Boss da ", current_wave.wave_name, " foi derrotado! Intervalo: ", current_wave.break_duration, "s")
	else:
		print("Wave ", current_wave.wave_name, " finalizada. Intervalo: ", current_wave.break_duration, "s")

func next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= wave_list.size():
		current_state = SpawnerState.FINISHED
		print("Todas as waves concluídas!")
		return
	
	start_current_wave()

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
		SpawnerState.WAITING_TO_START:
			state_text = "Aguardando início"
		SpawnerState.SPAWNING_WAVE:
			if wave.is_boss_wave:
				state_text = "Boss em combate"
			else:
				state_text = "Em progresso"
		SpawnerState.WAVE_BREAK:
			state_text = "Intervalo"
		SpawnerState.FINISHED:
			state_text = "Finalizado"
	
	return wave.wave_name + " - " + state_text

func force_next_wave() -> void:
	if current_state == SpawnerState.SPAWNING_WAVE:
		end_current_wave()
