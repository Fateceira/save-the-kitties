extends CharacterBody2D

@export var ship_stats: ShipStats
@export var equipped_projectile: ProjectileStats
@export var shoot_sfx: AudioStream
@export var damage_sfx: AudioStream
@export var death_sfx: AudioStream
@export var dash_sfx: AudioStream 

signal shot_fired
signal request_sfx(audio_stream, position, pitch_range, volume_db)
signal dash_performed  

var shoot_timer: float = 0.0
var damageable_component: DamageableComponent
var muzzles: Array[Node2D] = []
var is_shooting_burst: bool = false

var current_velocity: Vector2 = Vector2.ZERO
var target_velocity: Vector2 = Vector2.ZERO

var dash_charges: int = 0  
var dash_cooldown_timer: float = 0.0 
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var engine_particles: Array[CPUParticles2D] = []
var target_engine_intensity: float = 0.0
var current_engine_intensity: float = 0.0
var engine_fade_speed: float = 6.0
var max_engine_particles: int = 100
var min_engine_particles: int = 15
var idle_engine_particles: int = 25
var side_engine_particles: int = 40
var engine_boost_multiplier: float = 1.8

func _ready() -> void:
	setup_player_components()
	find_and_setup_muzzles()
	connect_damage_signals()
	configure_invulnerability_behavior()
	setup_engine_system()
	
	if ship_stats:
		dash_charges = ship_stats.max_dash_charges

func setup_player_components() -> void:
	damageable_component = $DamageableComponent
	if ship_stats and damageable_component:
		damageable_component.set_max_hp(ship_stats.max_hp)

func find_and_setup_muzzles() -> void:
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

func connect_damage_signals() -> void:
	if damageable_component:
		damageable_component.damaged.connect(handle_player_damage)
		damageable_component.died.connect(handle_player_death)

func configure_invulnerability_behavior() -> void:
	if damageable_component:
		damageable_component.can_be_invulnerable = true
		damageable_component.invulnerability_on_damage = false
		damageable_component.invulnerability_started.connect(on_invulnerability_begin)
		damageable_component.invulnerability_ended.connect(on_invulnerability_end)

func setup_engine_system() -> void:
	engine_particles.clear()
	
	var left_engine = get_node_or_null("EngineLeft")
	var right_engine = get_node_or_null("EngineRight")
	
	if left_engine:
		var particle = find_particle_in_node(left_engine)
		if particle:
			engine_particles.append(particle)
	
	if right_engine:
		var particle = find_particle_in_node(right_engine)
		if particle:
			engine_particles.append(particle)
	
	initialize_engine_particles()

func find_particle_in_node(node: Node) -> CPUParticles2D:
	if node is CPUParticles2D:
		return node
	
	for child in node.get_children():
		if child is CPUParticles2D:
			return child
		var found = find_particle_in_node(child)
		if found:
			return found
	
	return null

func initialize_engine_particles() -> void:
	for particle in engine_particles:
		if particle:
			particle.emitting = true
			particle.amount = idle_engine_particles
			store_original_particle_values(particle)

func store_original_particle_values(particle: CPUParticles2D) -> void:
	if not particle.has_meta("original_scale_min"):
		particle.set_meta("original_scale_min", particle.scale_amount_min)
		particle.set_meta("original_scale_max", particle.scale_amount_max)
		particle.set_meta("original_velocity_min", particle.initial_velocity_min)
		particle.set_meta("original_velocity_max", particle.initial_velocity_max)

func on_invulnerability_begin(should_blink: bool) -> void:
	collision_layer = 0
	collision_mask = 8

func on_invulnerability_end() -> void:
	collision_layer = 1
	collision_mask = 9

func handle_player_damage(damage_info: DamageInfo) -> void:
	if damage_sfx:
		emit_signal("request_sfx", damage_sfx, global_position, Vector2(0.9, 1.1), 0.0)

func handle_player_death() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)

func _process(delta: float) -> void:
	process_player_movement(delta)
	process_dash_mechanics(delta)
	process_weapon_shooting(delta)
	process_engine_visual_effects(delta)

func process_player_movement(delta: float) -> void:
	if not ship_stats:
		return
	
	var input_vector = get_movement_input()
	target_velocity = input_vector * ship_stats.max_speed
	
	if input_vector.length() > 0:
		current_velocity = current_velocity.move_toward(target_velocity, ship_stats.acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, ship_stats.deceleration * delta)
	
	if not is_dashing:
		velocity = current_velocity
	
	move_and_slide()

func get_movement_input() -> Vector2:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()
	
	return input_vector

func process_dash_mechanics(delta: float) -> void:
	if not ship_stats:
		return
	
	update_dash_cooldown(delta)
	
	if Input.is_action_just_pressed("dash") and can_perform_dash():
		execute_dash()
	
	if is_dashing:
		update_active_dash(delta)

func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
		if dash_cooldown_timer <= 0 and dash_charges < ship_stats.max_dash_charges:
			dash_charges += 1
			if dash_charges < ship_stats.max_dash_charges:
				dash_cooldown_timer = ship_stats.dash_cooldown

func can_perform_dash() -> bool:
	return dash_charges > 0 and not is_dashing

func execute_dash() -> void:
	if not ship_stats:
		return
	
	var dash_input = get_movement_input()
	
	if dash_input.length() == 0:
		dash_direction = Vector2.UP
	else:
		dash_direction = dash_input.normalized()
	
	is_dashing = true
	dash_timer = ship_stats.dash_duration
	dash_charges -= 1
	
	if dash_charges == 0:
		dash_cooldown_timer = ship_stats.dash_cooldown
	
	velocity = dash_direction * ship_stats.dash_force
	
	activate_dash_invulnerability()
	emit_signal("dash_performed")
	
	if dash_sfx:
		emit_signal("request_sfx", dash_sfx, global_position, Vector2(0.9, 1.1), -5.0)

func activate_dash_invulnerability() -> void:
	if damageable_component:
		damageable_component.start_silent_invulnerability(ship_stats.dash_duration + .15)

func update_active_dash(delta: float) -> void:
	dash_timer -= delta
	
	if dash_timer <= 0:
		finish_dash()

func finish_dash() -> void:
	is_dashing = false
	dash_timer = 0.0
	deactivate_dash_invulnerability()

func deactivate_dash_invulnerability() -> void:
	if damageable_component:
		damageable_component.end_invulnerability()

func process_weapon_shooting(delta: float) -> void:
	if not ship_stats or not equipped_projectile or is_shooting_burst:
		return
		
	shoot_timer -= delta

	if Input.is_action_pressed("shoot") and shoot_timer <= 0:
		initiate_weapon_burst()
		shoot_timer = ship_stats.fire_rate

func initiate_weapon_burst() -> void:
	if not equipped_projectile or not equipped_projectile.projectile_scene:
		return
	
	is_shooting_burst = true
	var projectile_count = ship_stats.projectile_count
	var shot_groups = calculate_shot_distribution(projectile_count)
	
	execute_burst_sequence(shot_groups)

func calculate_shot_distribution(total_shots: int) -> Array:
	var groups = []
	
	if total_shots <= 3:
		groups.append(create_simple_shot_group(total_shots))
		return groups
	
	return create_complex_shot_groups(total_shots)

func create_simple_shot_group(shot_count: int) -> Array:
	var single_group = []
	
	match shot_count:
		1:
			single_group.append({"muzzle": muzzles[0], "count": 1})
		2:
			single_group.append({"muzzle": muzzles[1], "count": 1})
			single_group.append({"muzzle": muzzles[2], "count": 1})
		3:
			single_group.append({"muzzle": muzzles[1], "count": 1})
			single_group.append({"muzzle": muzzles[0], "count": 1})
			single_group.append({"muzzle": muzzles[2], "count": 1})
	
	return single_group

func create_complex_shot_groups(total_shots: int) -> Array:
	var groups = []
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

func execute_burst_sequence(shot_groups: Array) -> void:
	for i in range(shot_groups.size()):
		var group = shot_groups[i]
		
		for shot_data in group:
			for shot_num in range(shot_data.count):
				fire_projectile_from_position(shot_data.muzzle.global_position)
		
		if i < shot_groups.size() - 1:
			await get_tree().create_timer(ship_stats.burst_delay).timeout
	
	is_shooting_burst = false

func fire_projectile_from_position(spawn_position: Vector2) -> void:
	var projectile = equipped_projectile.projectile_scene.instantiate()
	projectile.global_position = spawn_position
	
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(equipped_projectile, ship_stats.luck)
	
	get_tree().current_scene.add_child(projectile)
	
	emit_signal("shot_fired")
	
	if shoot_sfx:
		emit_signal("request_sfx", shoot_sfx, global_position, Vector2(0.95, 1.05), 0.0)

func process_engine_visual_effects(delta: float) -> void:
	if not ship_stats:
		return
	
	calculate_engine_intensity_target()
	update_engine_intensity_smoothly(delta)
	apply_engine_effects()

func calculate_engine_intensity_target() -> void:
	var input_vector = get_movement_input()
	var forward_input = -input_vector.y
	var side_input = abs(input_vector.x)
	
	var base_intensity = 0.0
	
	if forward_input > 0.1:
		base_intensity = forward_input
	elif forward_input < -0.1:
		base_intensity = 0.0
	elif side_input > 0.1:
		base_intensity = 0.4
	else:
		base_intensity = 0.2
	
	if is_dashing:
		base_intensity *= engine_boost_multiplier
	
	target_engine_intensity = clamp(base_intensity, 0.0, 1.0)

func update_engine_intensity_smoothly(delta: float) -> void:
	current_engine_intensity = move_toward(current_engine_intensity, target_engine_intensity, engine_fade_speed * delta)

func apply_engine_effects() -> void:
	for particle in engine_particles:
		if not particle:
			continue
		
		var should_emit = current_engine_intensity > 0.05
		
		if should_emit and not particle.emitting:
			particle.emitting = true
		elif not should_emit and particle.emitting:
			particle.emitting = false
		
		if particle.emitting:
			update_particle_properties(particle)

func update_particle_properties(particle: CPUParticles2D) -> void:
	var new_amount: int
	
	if current_engine_intensity >= 0.8:
		new_amount = max_engine_particles
	elif current_engine_intensity >= 0.5:
		new_amount = int(lerp(side_engine_particles, max_engine_particles, current_engine_intensity))
	elif current_engine_intensity >= 0.3:
		new_amount = side_engine_particles
	elif current_engine_intensity >= 0.15:
		new_amount = idle_engine_particles
	else:
		new_amount = min_engine_particles
	
	if is_dashing:
		new_amount = int(new_amount * 1.5)
	
	if particle.amount != new_amount:
		particle.amount = new_amount
	
	adjust_particle_visual_properties(particle)

func adjust_particle_visual_properties(particle: CPUParticles2D) -> void:
	var original_scale_min = particle.get_meta("original_scale_min", 0.5)
	var original_scale_max = particle.get_meta("original_scale_max", 1.0)
	var original_velocity_min = particle.get_meta("original_velocity_min", 50.0)
	var original_velocity_max = particle.get_meta("original_velocity_max", 100.0)
	
	var scale_multiplier = lerp(0.6, 1.4, current_engine_intensity)
	particle.scale_amount_min = original_scale_min * scale_multiplier
	particle.scale_amount_max = original_scale_max * scale_multiplier
	
	var speed_multiplier = lerp(0.7, 1.6, current_engine_intensity)
	particle.initial_velocity_min = original_velocity_min * speed_multiplier
	particle.initial_velocity_max = original_velocity_max * speed_multiplier
	
	if is_dashing:
		particle.scale_amount_min *= 1.3
		particle.scale_amount_max *= 1.3

func equip_projectile(new_projectile: ProjectileStats) -> void:
	equipped_projectile = new_projectile

func get_dash_charges() -> int:
	return dash_charges

func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_timer

func get_dash_cooldown_percentage() -> float:
	if not ship_stats:
		return 0.0
	return dash_cooldown_timer / ship_stats.dash_cooldown

func is_dash_available() -> bool:
	return dash_charges > 0

func get_max_dash_charges() -> int:
	if not ship_stats:
		return 0
	return ship_stats.max_dash_charges

func is_invulnerable() -> bool:
	if damageable_component:
		return damageable_component.is_invulnerable
	return false

func enable_damage_invulnerability() -> void:
	if damageable_component:
		damageable_component.invulnerability_on_damage = true
		damageable_component.invulnerability_duration = 1.0

func set_engine_fade_speed(speed: float) -> void:
	engine_fade_speed = speed

func get_current_engine_intensity() -> float:
	return current_engine_intensity
