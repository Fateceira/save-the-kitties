extends Node2D
class_name EnemySpawner

@export var spawn_area_width: float = 1145.0
@export var spawn_area_height: float = 100.0
@export var spawn_data_list: Array[SpawnData] = []
@export var debug_draw_color: Color = Color(1, 0, 0, 0.5)
@export var screen_margin: float = 50.0
@export var viper_path_spacing: float = 0.15
@export var max_total_enemies: int = 15
@export var min_spawn_distance: float = 80.0  
@export var max_spawn_attempts: int = 10   

var game_time: float = 0.0
var screen_size: Vector2
var spawner_node: Node2D
var available_paths: Array[Path2D] = []
var unlocked_enemies: Array[PackedScene] = []
var spawn_timers: Dictionary = {}
var last_used_path: Path2D = null
var path_usage_history: Array[Path2D] = []
var max_history_size: int = 3
var recent_spawn_positions: Array[Vector2] = []
var position_history_duration: float = 2.0      

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawner_node = get_node("Spawner")
	collect_available_paths()
	initialize_spawn_timers()
	perform_initial_spawns()

func initialize_spawn_timers() -> void:
	for i in range(spawn_data_list.size()):
		spawn_timers[i] = 0.0

func collect_available_paths() -> void:
	var paths_node = get_node("Paths")
	if paths_node:
		for child in paths_node.get_children():
			if child is Path2D:
				available_paths.append(child)

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

func get_valid_formation_start_position(formation_width: float) -> Vector2:
	var attempts = 0
	var start_position: Vector2
	
	while attempts < max_spawn_attempts:
		start_position = get_spawn_position()
		var formation_start_x = start_position.x - formation_width * 0.5
		
		var formation_valid = true
		for x_offset in range(0, int(formation_width), int(min_spawn_distance / 3)):
			var check_pos = Vector2(formation_start_x + x_offset, start_position.y)
			if is_position_too_close(check_pos):
				formation_valid = false
				break
		
		if formation_valid:
			return start_position
		
		attempts += 1
	
	return get_spawn_position()

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

func perform_initial_spawns() -> void:
	for i in range(spawn_data_list.size()):
		var data = spawn_data_list[i]
		if data.can_be_first_spawn and can_spawn_enemy_type(data):
			spawn_enemy_from_data(data)
			spawn_timers[i] = game_time

func _process(delta: float) -> void:
	game_time += delta
	
	for i in range(spawn_data_list.size()):
		var data = spawn_data_list[i]
		if should_spawn_enemy(data, i):
			spawn_enemy_from_data(data)
			spawn_timers[i] = game_time

func should_spawn_enemy(data: SpawnData, index: int) -> bool:
	if game_time < data.min_spawn_time:
		return false
	if game_time - spawn_timers[index] < data.spawn_interval:
		return false
	if not can_spawn_enemy_type(data):
		return false
	return randf() <= data.spawn_chance

func can_spawn_enemy_type(data: SpawnData) -> bool:
	if unlocked_enemies.size() > 0 and not unlocked_enemies.has(data.enemy_scene):
		return false
	var current_total = get_total_enemy_count()
	var formation_size = max(1, data.formation_count)
	if current_total + formation_size > max_total_enemies:
		return false
	return true

func get_total_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func spawn_enemy_from_data(data: SpawnData) -> void:
	if not data.enemy_scene:
		return
	
	var temp_enemy = data.enemy_scene.instantiate()
	var is_viper = temp_enemy is ViperEnemy
	temp_enemy.queue_free()
	
	if is_viper:
		spawn_viper_formation(data)
	elif data.formation_count <= 1:
		spawn_single_enemy(data)
	else:
		spawn_formation(data)

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
	
	var formation_start = get_valid_formation_start_position(total_width)
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
		
		if Engine.is_editor_hint() or OS.is_debug_build():
			for pos in recent_spawn_positions:
				var local_pos = to_local(pos)
				draw_circle(local_pos, min_spawn_distance, Color(1, 1, 0, 0.2))

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func unlock_enemy(enemy_scene: PackedScene) -> void:
	if not unlocked_enemies.has(enemy_scene):
		unlocked_enemies.append(enemy_scene)

func unlock_all_enemies() -> void:
	unlocked_enemies.clear()
	for data in spawn_data_list:
		if data.enemy_scene and not unlocked_enemies.has(data.enemy_scene):
			unlocked_enemies.append(data.enemy_scene)

func clear_unlocked_enemies() -> void:
	unlocked_enemies.clear()
