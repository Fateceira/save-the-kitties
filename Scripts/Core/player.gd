extends CharacterBody2D
class_name player

@export var ship_stats: ShipStats
@export var equipped_projectile: ProjectileStats
@export var shoot_sfx: AudioStream
@export var damage_sfx: AudioStream
@export var death_sfx: AudioStream
@export var dash_sfx: AudioStream 

@export var animation_blend_speed: float = 8.0
@export var turn_threshold: float = 0.1

@export_group("Engine System")
@export var engine_transition_speed: float = 8.0
@export var forward_lifetime: float = 0.25
@export var backward_lifetime: float = 0.01
@export var side_lifetime: float = 0.15
@export var idle_lifetime: float = 0.08
@export var dash_lifetime_multiplier: float = 1.8

@export_group("Tutorial/Progression")
@export var dash_unlocked: bool = false 

@export_group("Cutscene Control")
@export var cutscene_mode: bool = false 

signal shot_fired
signal request_sfx(audio_stream, position, pitch_range, volume_db)
signal dash_performed  
signal dash_unlocked_signal 

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
var engine_containers: Array[Node2D] = []
var target_engine_lifetime: float = 0.0
var current_engine_lifetime: float = 0.0

var animated_sprite: AnimatedSprite2D
var current_animation_state: String = "Center"
var target_animation_state: String = "Center"

var previous_input_vector: Vector2 = Vector2.ZERO
var input_change_timer: float = 0.0
var input_stability_threshold: float = 0.1

var original_collision_layer: int
var original_collision_mask: int
var collisions_disabled: bool = false

var dialog_manager_connected: bool = false

func _ready() -> void:
	add_to_group("player")
	
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	setup_player_components()
	setup_animation_system()
	find_and_setup_muzzles()
	connect_damage_signals()
	configure_invulnerability_behavior()
	setup_engine_system()
	setup_dash_system()
	
	connect_to_dialog_events()
	
	if not dialog_manager_connected:
		await get_tree().process_frame
		connect_to_dialog_events()

func setup_dash_system() -> void:
	if ship_stats:
		if dash_unlocked:
			dash_charges = ship_stats.max_dash_charges
		else:
			dash_charges = 0
	
	print("Dash inicializado - Desbloqueado: ", dash_unlocked, " | Cargas: ", dash_charges)

func connect_to_dialog_events() -> void:
	print("Tentando conectar aos eventos do DialogManager...")
	
	if DialogManager == null:
		push_error("DialogManager class não encontrada!")
		return
	
	if DialogManager.instance == null:
		print("DialogManager.instance ainda é null, tentando novamente...")
		return
	
	if dialog_manager_connected:
		print("Já conectado ao DialogManager")
		return
	
	var connection_result = DialogManager.instance.dialog_event_triggered.connect(_on_dialog_event)
	if connection_result == OK:
		dialog_manager_connected = true
		print("✅ Conectado com sucesso aos eventos do DialogManager!")
	else:
		push_error("❌ Falha ao conectar aos eventos do DialogManager: " + str(connection_result))

func _on_dialog_event(event_name: String) -> void:
	print("🎯 Player recebeu evento de diálogo: ", event_name)
	
	match event_name:
		"unlock_dash":
			print("Processando evento unlock_dash...")
			unlock_dash()
		"tutorial_complete":
			print("Tutorial completado!")
		_:
			print("Evento não reconhecido: ", event_name)

func unlock_dash() -> void:
	print("🚀 Função unlock_dash chamada!")
	
	if not dash_unlocked:
		dash_unlocked = true
		if ship_stats:
			dash_charges = ship_stats.max_dash_charges
		
		print("✨ DASH DESBLOQUEADO! Cargas disponíveis: ", dash_charges)
		dash_unlocked_signal.emit()
		
		if dash_sfx:
			emit_signal("request_sfx", dash_sfx, global_position, Vector2(0.8, 1.2), -10.0)
	else:
		print("⚠️ Dash já estava desbloqueado")

func debug_unlock_dash() -> void:
	print("🔧 DEBUG: Forçando desbloqueio do dash...")
	unlock_dash()

func debug_check_dialog_connection() -> void:
	print("=== DEBUG CONEXÃO DIALOG ===")
	print("DialogManager existe: ", DialogManager != null)
	print("DialogManager.instance existe: ", DialogManager.instance != null)
	print("Conectado: ", dialog_manager_connected)
	
	if DialogManager.instance:
		print("Listeners no DialogManager: ")
		DialogManager.instance.debug_check_connections()
	print("============================")

func force_reconnect_dialog_manager() -> void:
	dialog_manager_connected = false
	connect_to_dialog_events()

func setup_player_components() -> void:
	damageable_component = $DamageableComponent
	if ship_stats and damageable_component:
		damageable_component.set_max_hp(ship_stats.max_hp)

func setup_animation_system() -> void:
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		push_error("Player precisa ter AnimatedSprite2D como filho")
		return
	
	animated_sprite.play("Center")
	current_animation_state = "Center"
	target_animation_state = "Center"

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
	engine_containers.clear()
	
	find_all_engine_containers(self)
	initialize_engine_particles()
	current_engine_lifetime = idle_lifetime

func find_all_engine_containers(node: Node) -> void:
	for child in node.get_children():
		var node_name = child.name.to_lower()
		
		if "engine" in node_name and child is Node2D:
			engine_containers.append(child)
			var particle = find_particle_in_container(child)
			if particle:
				engine_particles.append(particle)
		
		find_all_engine_containers(child)

func find_particle_in_container(container: Node2D) -> CPUParticles2D:
	for child in container.get_children():
		if child is CPUParticles2D:
			return child
		
		var nested_particle = find_particle_in_container(child)
		if nested_particle:
			return nested_particle
	
	return null

func initialize_engine_particles() -> void:
	for particle in engine_particles:
		if particle:
			particle.emitting = true
			store_original_particle_settings(particle)
			particle.lifetime = idle_lifetime

func store_original_particle_settings(particle: CPUParticles2D) -> void:
	if not particle.has_meta("original_lifetime"):
		particle.set_meta("original_lifetime", particle.lifetime)
		particle.set_meta("original_amount", particle.amount)

func on_invulnerability_begin(should_blink: bool) -> void:
	collision_layer = 0
	collision_mask = 8

func on_invulnerability_end() -> void:
	if not cutscene_mode and not collisions_disabled:
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask

func handle_player_damage(damage_info: DamageInfo) -> void:
	if damage_sfx:
		emit_signal("request_sfx", damage_sfx, global_position, Vector2(0.9, 1.1), 0.0)

func handle_player_death() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)

func _process(delta: float) -> void:
	if cutscene_mode:
		process_engine_system_cutscene(delta)
		process_ship_animations_cutscene()
		return
	
	process_player_movement(delta)
	process_dash_mechanics(delta)
	process_weapon_shooting(delta)
	process_engine_system(delta)
	process_ship_animations(delta)

# ============ NOVOS MÉTODOS PARA CUTSCENE ============

func set_cutscene_mode(enabled: bool) -> void:
	cutscene_mode = enabled
	
	if enabled:
		velocity = Vector2.ZERO
		current_velocity = Vector2.ZERO
		target_velocity = Vector2.ZERO
		is_dashing = false
		is_shooting_burst = false
		
		force_animation("Center")
		
		print("Player em modo cutscene: ATIVO")
	else:
		print("Player em modo cutscene: DESATIVO - controles liberados")

func disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	collisions_disabled = true
	print("Colisões do player desabilitadas")

func enable_collisions() -> void:
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	collisions_disabled = false
	print("Colisões do player reabilitadas")

func process_engine_system_cutscene(delta: float) -> void:
	target_engine_lifetime = idle_lifetime
	update_current_engine_lifetime(delta)
	apply_engine_lifetime_to_particles()

func process_ship_animations_cutscene() -> void:
	target_animation_state = "Center"
	update_animation_state()

func get_movement_input() -> Vector2:
	if cutscene_mode:
		return Vector2.ZERO
	
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()
	
	return input_vector

func process_ship_animations(delta: float) -> void:
	if not animated_sprite:
		return
	
	var input_vector = get_movement_input()
	determine_target_animation(input_vector)
	update_animation_state()

func determine_target_animation(input_vector: Vector2) -> void:
	var horizontal_input = input_vector.x
	
	if abs(horizontal_input) < turn_threshold:
		target_animation_state = "Center"
	elif horizontal_input > turn_threshold:
		target_animation_state = "Right"
	elif horizontal_input < -turn_threshold:
		target_animation_state = "Left"

func update_animation_state() -> void:
	if current_animation_state != target_animation_state:
		current_animation_state = target_animation_state
		animated_sprite.play(current_animation_state)

func process_player_movement(delta: float) -> void:
	if not ship_stats or cutscene_mode:
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

func process_engine_system(delta: float) -> void:
	calculate_target_engine_lifetime(delta)
	update_current_engine_lifetime(delta)
	apply_engine_lifetime_to_particles()

func calculate_target_engine_lifetime(delta: float) -> void:
	var input_vector = get_movement_input()
	var input_change = input_vector.distance_to(previous_input_vector)
	
	if input_change > 0.05:
		input_change_timer = 0.0
	else:
		input_change_timer += delta
	
	var input_stability = min(input_change_timer / input_stability_threshold, 1.0)
	var smoothed_input = previous_input_vector.lerp(input_vector, 1.0 - input_stability * 0.7)
	previous_input_vector = smoothed_input
	
	var forward_movement = -smoothed_input.y
	var backward_movement = smoothed_input.y
	var side_movement = abs(smoothed_input.x)
	
	if forward_movement > 0.1:
		target_engine_lifetime = lerp(idle_lifetime, forward_lifetime, forward_movement)
	elif backward_movement > 0.1:
		target_engine_lifetime = lerp(idle_lifetime, backward_lifetime, backward_movement)
	elif side_movement > 0.1:
		target_engine_lifetime = lerp(idle_lifetime, side_lifetime, side_movement)
	else:
		target_engine_lifetime = idle_lifetime
	
	if is_dashing:
		target_engine_lifetime *= dash_lifetime_multiplier

func update_current_engine_lifetime(delta: float) -> void:
	var transition_speed = engine_transition_speed * delta
	
	if target_engine_lifetime < current_engine_lifetime:
		transition_speed *= 1.5
	
	current_engine_lifetime = move_toward(current_engine_lifetime, target_engine_lifetime, transition_speed)

func apply_engine_lifetime_to_particles() -> void:
	for particle in engine_particles:
		if not particle:
			continue
		
		var should_emit = current_engine_lifetime > 0.02
		
		if should_emit:
			if not particle.emitting:
				particle.emitting = true
			particle.lifetime = current_engine_lifetime
		else:
			if particle.emitting:
				particle.emitting = false

func process_dash_mechanics(delta: float) -> void:
	if not ship_stats or cutscene_mode:
		return
	
	update_dash_cooldown(delta)
	
	if Input.is_action_just_pressed("dash") and can_perform_dash():
		execute_dash()
	
	if is_dashing:
		update_active_dash(delta)

func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
		if dash_cooldown_timer <= 0 and dash_charges < ship_stats.max_dash_charges and dash_unlocked:
			dash_charges += 1
			if dash_charges < ship_stats.max_dash_charges:
				dash_cooldown_timer = ship_stats.dash_cooldown

func can_perform_dash() -> bool:
	return dash_unlocked and dash_charges > 0 and not is_dashing and not cutscene_mode

func execute_dash() -> void:
	if not ship_stats or not dash_unlocked or cutscene_mode:
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
	if not ship_stats or not equipped_projectile or is_shooting_burst or cutscene_mode:
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

# ============ MÉTODOS UTILITÁRIOS ============

func get_current_animation() -> String:
	return current_animation_state

func force_animation(animation_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation(animation_name):
		current_animation_state = animation_name
		target_animation_state = animation_name
		animated_sprite.play(animation_name)

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
	return dash_unlocked and dash_charges > 0

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

func get_current_engine_lifetime() -> float:
	return current_engine_lifetime

# ============ MÉTODOS ESPECÍFICOS PARA CONTROLE DO DASH ============

func is_dash_unlocked() -> bool:
	return dash_unlocked

func force_unlock_dash() -> void:
	unlock_dash()

func lock_dash() -> void:
	dash_unlocked = false
	dash_charges = 0
	print("Dash bloqueado!")

# ============ MÉTODOS PÚBLICOS PARA CUTSCENE ============

func is_in_cutscene_mode() -> bool:
	return cutscene_mode

func are_collisions_disabled() -> bool:
	return collisions_disabled
