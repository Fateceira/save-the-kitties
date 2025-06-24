extends CharacterBody2D

@export var ship_stats: ShipStats
@export var equipped_projectile: ProjectileStats
@export var shoot_sfx: AudioStream
@export var damage_sfx: AudioStream
@export var death_sfx: AudioStream

signal shot_fired
signal request_sfx(audio_stream, position, pitch_range, volume_db) 

var shoot_timer: float = 0.0
var damageable_component: DamageableComponent
var muzzles: Array[Node2D] = []
var is_shooting_burst: bool = false

func _ready() -> void:
	setup_components()
	collect_muzzles()
	connect_audio_signals()

func setup_components() -> void:
	damageable_component = $DamageableComponent
	if ship_stats and damageable_component:
		damageable_component.set_max_hp(ship_stats.max_hp)

func connect_audio_signals() -> void:
	if damageable_component:
		damageable_component.damaged.connect(_on_player_damaged)
		damageable_component.died.connect(_on_player_died)

func _on_player_damaged(damage_info: DamageInfo) -> void:
	if damage_sfx:
		emit_signal("request_sfx", damage_sfx, global_position, Vector2(0.9, 1.1), 0.0)

func _on_player_died() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)

func collect_muzzles() -> void:
	muzzles.clear()
	
	var center_muzzle = get_node_or_null("Muzzle")
	var left_muzzle = get_node_or_null("MuzzleLeft") 
	var right_muzzle = get_node_or_null("MuzzleRight")
	
	if center_muzzle:
		muzzles.append(center_muzzle)
	if left_muzzle:
		muzzles.append(left_muzzle)
	if right_muzzle:
		muzzles.append(right_muzzle)

func _process(delta: float) -> void:
	handle_movement(delta)
	handle_shooting(delta)

func handle_movement(delta: float) -> void:
	if not ship_stats:
		return
		
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()

	velocity = input_vector * ship_stats.speed
	move_and_slide()

func handle_shooting(delta: float) -> void:
	if not ship_stats or not equipped_projectile or is_shooting_burst:
		return
		
	shoot_timer -= delta

	if Input.is_action_pressed("shoot") and shoot_timer <= 0:
		shoot_burst()
		shoot_timer = ship_stats.fire_rate

func shoot_burst() -> void:
	if not equipped_projectile or not equipped_projectile.projectile_scene:
		return
	
	is_shooting_burst = true
	var projectile_count = ship_stats.projectile_count
	var shot_groups = distribute_shots(projectile_count)
	
	execute_shot_sequence(shot_groups)

func distribute_shots(total_shots: int) -> Array:
	var groups = []
	
	if total_shots <= 3:
		var single_group = []
		if total_shots == 1:
			single_group.append({"muzzle": muzzles[0], "count": 1})
		elif total_shots == 2:
			single_group.append({"muzzle": muzzles[1], "count": 1})
			single_group.append({"muzzle": muzzles[2], "count": 1})
		elif total_shots == 3:
			single_group.append({"muzzle": muzzles[1], "count": 1})
			single_group.append({"muzzle": muzzles[0], "count": 1})
			single_group.append({"muzzle": muzzles[2], "count": 1})
		groups.append(single_group)
		return groups
	
	var shots_per_muzzle = total_shots / 3
	var remaining_shots = total_shots % 3
	
	var left_shots = shots_per_muzzle
	var center_shots = shots_per_muzzle + remaining_shots
	var right_shots = shots_per_muzzle
	
	var max_shots_per_group = max(left_shots, max(center_shots, right_shots))
	
	for wave in range(max_shots_per_group):
		var wave_group = []
		
		if wave < left_shots:
			wave_group.append({"muzzle": muzzles[1], "count": 1})
		if wave < center_shots:
			wave_group.append({"muzzle": muzzles[0], "count": 1})
		if wave < right_shots:
			wave_group.append({"muzzle": muzzles[2], "count": 1})
		
		if wave_group.size() > 0:
			groups.append(wave_group)
	
	return groups

func execute_shot_sequence(shot_groups: Array) -> void:
	for i in range(shot_groups.size()):
		var group = shot_groups[i]
		
		for shot_data in group:
			for shot_num in range(shot_data.count):
				shoot_from_position(shot_data.muzzle.global_position)
		
		if i < shot_groups.size() - 1:
			await get_tree().create_timer(ship_stats.burst_delay).timeout
	
	is_shooting_burst = false

func shoot_from_position(spawn_position: Vector2) -> void:
	var projectile = equipped_projectile.projectile_scene.instantiate()
	projectile.global_position = spawn_position
	
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(equipped_projectile, ship_stats.luck)
	
	get_tree().current_scene.add_child(projectile)
	
	emit_signal("shot_fired")
	
	if shoot_sfx:
		emit_signal("request_sfx", shoot_sfx, global_position, Vector2(0.95, 1.05), 0.0)

func equip_projectile(new_projectile: ProjectileStats) -> void:
	equipped_projectile = new_projectile
