extends Node2D
class_name EnemySpawner

@export var spawn_area_width: float = 1145.0
@export var spawn_area_height: float = 100.0
@export var spawn_data_list: Array[SpawnData] = []
@export var debug_draw_color: Color = Color(1, 0, 0, 0.5)

var game_time: float = 0.0
var first_spawn_done: bool = false

func _ready() -> void:
	reset_spawn_timers()

func _process(delta: float) -> void:
	game_time += delta
	
	for data in spawn_data_list:
		if can_spawn_enemy(data):
			spawn_enemy_from_data(data)
			data.last_spawn_time = game_time

func can_spawn_enemy(data: SpawnData) -> bool:
	if game_time < data.min_spawn_time:
		return false
	
	if not first_spawn_done and not data.can_be_first_spawn:
		return false
	
	if game_time - data.last_spawn_time < data.spawn_interval:
		return false
	
	return randf() <= data.spawn_chance

func spawn_enemy_from_data(data: SpawnData) -> void:
	if not data.enemy_scene:
		return
	
	if data.formation_count <= 1:
		spawn_single_enemy(data.enemy_scene)
	else:
		spawn_formation(data)
	
	first_spawn_done = true

func spawn_single_enemy(enemy_scene: PackedScene) -> void:
	var enemy = enemy_scene.instantiate()
	var enemy_size_x = get_enemy_width(enemy)
	var spawn_position = get_random_spawn_position(enemy_size_x)
	
	enemy.global_position = spawn_position
	get_tree().current_scene.add_child(enemy)

func spawn_formation(data: SpawnData) -> void:
	var total_width = (data.formation_count - 1) * data.formation_spacing
	var start_x = -total_width * 0.5
	
	for i in data.formation_count:
		var enemy = data.enemy_scene.instantiate()
		var offset_x = start_x + i * data.formation_spacing
		var spawn_pos = global_position + Vector2(offset_x, 0)
		
		if enemy is ViperEnemy:
			enemy.formation_delay = i * 0.2
		
		enemy.global_position = spawn_pos
		get_tree().current_scene.add_child(enemy)

func get_enemy_width(enemy: Node2D) -> float:
	var enemy_size_x: float = 32.0
	
	if enemy.has_node("CollisionShape2D"):
		var collision_node = enemy.get_node("CollisionShape2D")
		var shape = collision_node.shape
		if shape is RectangleShape2D:
			enemy_size_x = shape.size.x
		elif shape is CircleShape2D:
			enemy_size_x = shape.radius * 2.0
	elif enemy.has_node("Sprite2D"):
		var sprite = enemy.get_node("Sprite2D")
		if sprite.texture:
			enemy_size_x = sprite.texture.get_width() * sprite.scale.x
	
	return enemy_size_x

func get_random_spawn_position(enemy_width: float) -> Vector2:
	var half_area = spawn_area_width * 0.5
	var spawn_x = randf_range(-half_area + enemy_width * 0.5, half_area - enemy_width * 0.5)
	return global_position + Vector2(spawn_x, 0)

func reset_spawn_timers() -> void:
	for data in spawn_data_list:
		data.last_spawn_time = 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2(-spawn_area_width * 0.5, 0), 
		Vector2(spawn_area_width, spawn_area_height)),
		debug_draw_color, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()
