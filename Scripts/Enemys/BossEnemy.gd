extends EnemyBase
class_name BossEnemy

@export var projectile_stats: ProjectileStats
@export var shoot_sfx: AudioStream
@export var target_position_y: float = -250.0
@export var follow_delay: float = .5
@export var attack_range: float = 2000.0

@export var screen_width: float = 1200.0
@export var min_y_position: float = -250.0
@export var max_y_position: float = -160.0

enum BossState {
	ENTERING,
	FOLLOWING,
	ATTACKING,
	REPOSITIONING,
	DODGING,
	CHARGING_LASER,
	LASER_ATTACK
}

enum MovementPattern {
	HORIZONTAL_SWEEP,
	ZIGZAG,
	CIRCLE_STRAFE,
	AGGRESSIVE_CHASE
}

var current_state: BossState = BossState.ENTERING
var current_movement_pattern: MovementPattern = MovementPattern.HORIZONTAL_SWEEP
var state_timer: float = 0.0
var pattern_timer: float = 0.0
var muzzles: Array[Node2D] = []
var player_ref: Node2D

var left_shapecast: ShapeCast2D
var right_shapecast: ShapeCast2D
var left_line: Line2D
var right_line: Line2D
var laser_charge_time: float = 1.5
var laser_active_time: float = 2
var laser_cooldown_timer: float = 0.0
var laser_cooldown: float = 6
var max_laser_width: float = 30.0
var max_shapecast_width: float = 15.0
var laser_range: float = 800.0 
var laser_damage: int = 1
var using_single_laser: bool = false
var active_laser_side: String = ""

var players_hit_by_laser: Array[Node2D] = []
var laser_damage_timer: float = 0.0
var laser_damage_interval: float = .2

var target_position: Vector2
var follow_timer: float = 0.0
var movement_target: Vector2

var pattern_change_interval: float = 4
var dodge_distance: float = 160.0
var strafe_radius: float = 200.0
var zigzag_amplitude: float = 200.0
var aggressive_threshold: float = 300.0

var attack_timer: float = 0.0
var attack_cooldown: float = .8
var shots_in_burst: int = 0
var max_shots_in_burst: int = 10
var shot_interval: float = 0.2
var burst_active: bool = false
var continuous_shooting: bool = false
var continuous_shot_timer: float = 0.0
var continuous_shot_interval: float = 0.4

var dodge_timer: float = 0.0
var dodge_cooldown: float = .5
var is_dodging: bool = false
var dodge_direction: Vector2

var player_cornered_threshold: float = 100.0
var boss_proximity_threshold: float = 100.0
var mercy_timer: float = 0.0
var mercy_cooldown: float = 1.5
var difficulty_scale: float = 1.5

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	collect_muzzles()
	setup_laser_components()
	setup_boss_behavior()
	find_player()
	setup_boss_invulnerability()
	
	target_position = global_position
	movement_target = global_position
	choose_random_movement_pattern()
	calculate_difficulty_scale()

func calculate_difficulty_scale() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_health_component = players[0].get_node_or_null("DamageableComponent") as DamageableComponent
		if player_health_component:
			var health_ratio = float(player_health_component.current_hp) / float(player_health_component.max_hp)
			difficulty_scale = lerp(0.7, 1.2, 1.0 - health_ratio)

func setup_boss_invulnerability() -> void:
	if damageable_component:
		damageable_component.can_be_invulnerable = true
		damageable_component.start_silent_invulnerability(999.0)

func setup_boss_behavior() -> void:
	if trigger_area:
		trigger_area.queue_free()
	set_physics_process(false)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func collect_muzzles() -> void:
	muzzles.clear()
	var left_muzzle = get_node_or_null("MuzzleLeft")
	var right_muzzle = get_node_or_null("MuzzleRight")
	if left_muzzle:
		muzzles.append(left_muzzle)
	if right_muzzle:
		muzzles.append(right_muzzle)

func setup_laser_components() -> void:
	left_shapecast = get_node_or_null("MuzzleLeft/ShapeCast2D")
	right_shapecast = get_node_or_null("MuzzleRight/ShapeCast2D")
	
	if left_shapecast:
		left_shapecast.target_position = Vector2(0, laser_range)
		left_shapecast.enabled = false
		left_shapecast.collision_mask = 1
		left_shapecast.collide_with_areas = false
		left_shapecast.collide_with_bodies = true
	
	if right_shapecast:
		right_shapecast.target_position = Vector2(0, laser_range)
		right_shapecast.enabled = false
		right_shapecast.collision_mask = 1
		right_shapecast.collide_with_areas = false
		right_shapecast.collide_with_bodies = true
	
	left_line = get_node_or_null("MuzzleLeft/Line2D")
	right_line = get_node_or_null("MuzzleRight/Line2D")
	
	if left_line:
		left_line.width = 0.0
		left_line.z_index = 10
		left_line.visible = true
		left_line.clear_points()
		left_line.add_point(Vector2.ZERO)
		left_line.add_point(Vector2(0, laser_range))
	
	if right_line:
		right_line.width = 0.0
		right_line.z_index = 10
		right_line.visible = true
		right_line.clear_points()
		right_line.add_point(Vector2.ZERO)
		right_line.add_point(Vector2(0, laser_range))

func _process(delta: float) -> void:
	state_timer += delta
	pattern_timer += delta
	follow_timer += delta
	attack_timer += delta
	dodge_timer += delta
	laser_cooldown_timer += delta
	laser_damage_timer += delta
	mercy_timer += delta
	
	if not player_ref:
		find_player()
		return
	
	calculate_difficulty_scale()
	
	if current_state == BossState.LASER_ATTACK:
		process_laser_damage()
		if should_show_mercy():
			deactivate_laser()
			change_state(BossState.REPOSITIONING)
			mercy_timer = 0.0
	
	if pattern_timer >= pattern_change_interval * difficulty_scale and current_state not in [BossState.CHARGING_LASER, BossState.LASER_ATTACK]:
		choose_random_movement_pattern()
		pattern_timer = 0.0
	
	if should_dodge() and dodge_timer >= dodge_cooldown * difficulty_scale and current_state not in [BossState.CHARGING_LASER, BossState.LASER_ATTACK]:
		start_dodge()
		dodge_timer = 0.0
	
	if should_use_laser():
		start_laser_attack()
	
	update_movement_target()
	
	match current_state:
		BossState.ENTERING:
			handle_entering_state(delta)
		BossState.FOLLOWING:
			handle_following_state(delta)
		BossState.ATTACKING:
			handle_attacking_state(delta)
		BossState.REPOSITIONING:
			handle_repositioning_state(delta)
		BossState.DODGING:
			handle_dodging_state(delta)
		BossState.CHARGING_LASER:
			handle_charging_laser_state(delta)
		BossState.LASER_ATTACK:
			handle_laser_attack_state(delta)

func should_show_mercy() -> bool:
	if mercy_timer < mercy_cooldown:
		return false
	
	if not player_ref:
		return false
	
	var player_pos = player_ref.global_position
	var boss_to_player_distance = global_position.distance_to(player_pos)
	
	var is_player_cornered = (
		abs(player_pos.x) > (screen_width/2 - player_cornered_threshold) or
		player_pos.y > (max_y_position + player_cornered_threshold)
	)
	
	var boss_too_close = boss_to_player_distance < boss_proximity_threshold
	
	var laser_active_too_long = state_timer > laser_active_time * 0.7
	
	return is_player_cornered and boss_too_close and laser_active_too_long

func process_laser_damage() -> void:
	if laser_damage_timer < laser_damage_interval:
		return
	
	laser_damage_timer = 0.0
	
	if using_single_laser:
		if active_laser_side == "left" and left_shapecast and left_shapecast.enabled:
			check_laser_collision(left_shapecast)
		elif active_laser_side == "right" and right_shapecast and right_shapecast.enabled:
			check_laser_collision(right_shapecast)
	else:
		if left_shapecast and left_shapecast.enabled:
			check_laser_collision(left_shapecast)
		if right_shapecast and right_shapecast.enabled:
			check_laser_collision(right_shapecast)

func check_laser_collision(shapecast: ShapeCast2D) -> void:
	if not shapecast.is_colliding():
		return
	
	var collision_count = shapecast.get_collision_count()
	for i in range(collision_count):
		var collider = shapecast.get_collider(i)
		if collider and collider.has_method("get_node"):
			var player_damageable = collider.get_node_or_null("DamageableComponent") as DamageableComponent
			if player_damageable:
				var damage_info = DamageInfo.new(laser_damage)
				player_damageable.apply_damage(damage_info)

func choose_random_movement_pattern() -> void:
	var patterns = [
		MovementPattern.HORIZONTAL_SWEEP,
		MovementPattern.ZIGZAG,
		MovementPattern.CIRCLE_STRAFE,
		MovementPattern.AGGRESSIVE_CHASE
	]
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var weights = [1.0, 1.0, 1.0, 1.0]
	
	if distance_to_player > aggressive_threshold:
		weights[3] = 2.0
	else:
		weights[0] = 1.5
		weights[1] = 1.5
		weights[2] = 2.0
		weights[3] = 0.5
	
	var total_weight = weights.reduce(func(a, b): return a + b)
	var random_value = randf() * total_weight
	var accumulated_weight = 0.0
	
	for i in range(patterns.size()):
		accumulated_weight += weights[i]
		if random_value <= accumulated_weight:
			current_movement_pattern = patterns[i]
			return

func should_dodge() -> bool:
	if not player_ref:
		return false
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var dodge_chance = lerp(0.15, 0.35, difficulty_scale)
	return distance_to_player < dodge_distance and randf() < dodge_chance

func should_use_laser() -> bool:
	if laser_cooldown_timer < laser_cooldown / difficulty_scale:
		return false
	if current_state in [BossState.CHARGING_LASER, BossState.LASER_ATTACK, BossState.ENTERING]:
		return false
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var laser_chance = lerp(0.25, 0.45, difficulty_scale)
	
	var player_pos = player_ref.global_position
	var is_player_cornered = (
		abs(player_pos.x) > (screen_width/2 - player_cornered_threshold * 1.5) or
		player_pos.y > (max_y_position + player_cornered_threshold * 1.5)
	)
	
	if is_player_cornered:
		laser_chance *= 0.6
	
	return distance_to_player > 180.0 and randf() < laser_chance

func start_laser_attack() -> void:
	change_state(BossState.CHARGING_LASER)
	laser_cooldown_timer = 0.0
	players_hit_by_laser.clear()
	laser_damage_timer = 0.0
	
	var player_pos = player_ref.global_position
	
	if player_pos.x < -screen_width/4:
		using_single_laser = true
		active_laser_side = "left"
	elif player_pos.x > screen_width/4:
		using_single_laser = true
		active_laser_side = "right"  
	else:
		using_single_laser = false
		active_laser_side = ""
	
	movement_target.x = global_position.x
	movement_target.y = target_position_y

func start_dodge() -> void:
	change_state(BossState.DODGING)
	is_dodging = true
	
	var to_player = (player_ref.global_position - global_position).normalized()
	dodge_direction = Vector2(-to_player.y, to_player.x) * (1 if randf() > 0.5 else -1)

func update_movement_target() -> void:
	if not player_ref or is_dodging:
		return
	
	var player_pos = player_ref.global_position
	
	match current_movement_pattern:
		MovementPattern.HORIZONTAL_SWEEP:
			update_horizontal_sweep_target(player_pos)
		MovementPattern.ZIGZAG:
			update_zigzag_target(player_pos)
		MovementPattern.CIRCLE_STRAFE:
			update_circle_strafe_target(player_pos)
		MovementPattern.AGGRESSIVE_CHASE:
			update_aggressive_chase_target(player_pos)

func update_horizontal_sweep_target(player_pos: Vector2) -> void:
	var sweep_offset = sin(pattern_timer * 1.5) * 180.0
	movement_target.x = clamp(player_pos.x + sweep_offset, -screen_width/2, screen_width/2)
	movement_target.y = clamp(target_position_y, min_y_position, max_y_position)

func update_zigzag_target(player_pos: Vector2) -> void:
	var zigzag_x = sin(pattern_timer * 2.5) * zigzag_amplitude
	var zigzag_y = cos(pattern_timer * 1.8) * 40.0
	
	movement_target.x = clamp(player_pos.x + zigzag_x, -screen_width/2, screen_width/2)
	movement_target.y = clamp(target_position_y + zigzag_y, min_y_position, max_y_position)

func update_circle_strafe_target(player_pos: Vector2) -> void:
	var angle = pattern_timer * 1.2
	var circle_x = cos(angle) * strafe_radius
	var circle_y = sin(angle) * 25.0
	
	movement_target.x = clamp(player_pos.x + circle_x, -screen_width/2, screen_width/2)
	movement_target.y = clamp(target_position_y + circle_y, min_y_position, max_y_position)

func update_aggressive_chase_target(player_pos: Vector2) -> void:
	var distance_to_player = global_position.distance_to(player_pos)
	
	if distance_to_player > aggressive_threshold:
		movement_target.x = clamp(player_pos.x, -screen_width/2, screen_width/2)
		movement_target.y = clamp(player_pos.y - 80.0, min_y_position, max_y_position)
	else:
		var retreat_direction = (global_position - player_pos).normalized()
		movement_target = global_position + retreat_direction * 40.0
		movement_target.x = clamp(movement_target.x, -screen_width/2, screen_width/2)
		movement_target.y = clamp(movement_target.y, min_y_position, max_y_position)

func handle_entering_state(delta: float) -> void:
	if global_position.y < target_position_y:
		global_position.y += stats.speed * 0.5 * delta
	else:
		end_boss_invulnerability()
		change_state(BossState.FOLLOWING)

func end_boss_invulnerability() -> void:
	if damageable_component:
		damageable_component.end_invulnerability()

func handle_following_state(delta: float) -> void:
	move_toward_target(delta, 0.6)
	
	if attack_timer >= attack_cooldown / difficulty_scale:
		start_attack_burst()

func handle_attacking_state(delta: float) -> void:
	move_toward_target(delta, 0.3)
	
	if not burst_active:
		return
	
	if state_timer >= shot_interval * difficulty_scale:
		fire_shot()
		shots_in_burst += 1
		state_timer = 0.0
		
		if shots_in_burst >= max_shots_in_burst:
			end_attack_burst()

func handle_repositioning_state(delta: float) -> void:
	move_toward_target(delta, 0.7)
	
	var distance = global_position.distance_to(movement_target)
	if distance < 40.0:
		change_state(BossState.FOLLOWING)

func handle_dodging_state(delta: float) -> void:
	if is_dodging:
		var dodge_speed = stats.speed * 1.1
		var new_position = global_position + dodge_direction * dodge_speed * delta
		
		new_position.x = clamp(new_position.x, -screen_width/2, screen_width/2)
		new_position.y = clamp(new_position.y, min_y_position, max_y_position)
		
		global_position = new_position
		
		if state_timer >= 0.6:
			is_dodging = false
			change_state(BossState.REPOSITIONING)

func move_toward_target(delta: float, speed_multiplier: float) -> void:
	var direction = (movement_target - global_position).normalized()
	var distance = global_position.distance_to(movement_target)
	
	if distance > 25.0:
		var new_position = global_position + direction * stats.speed * speed_multiplier * delta
		
		new_position.x = clamp(new_position.x, -screen_width/2, screen_width/2)
		new_position.y = clamp(new_position.y, min_y_position, max_y_position)
		
		global_position = new_position

func start_attack_burst() -> void:
	change_state(BossState.ATTACKING)
	burst_active = true
	shots_in_burst = 0
	attack_timer = 0.0

func end_attack_burst() -> void:
	burst_active = false
	shots_in_burst = 0
	change_state(BossState.FOLLOWING)

func fire_shot() -> void:
	if muzzles.size() == 0:
		return
	
	if shots_in_burst % 2 == 0:
		var muzzle_index = (shots_in_burst / 2) % muzzles.size()
		fire_from_muzzle(muzzles[muzzle_index])
	else:
		for muzzle in muzzles:
			fire_from_muzzle(muzzle)

func fire_from_muzzle(muzzle: Node2D) -> void:
	if not projectile_stats or not projectile_stats.projectile_scene:
		return
	
	var projectile = projectile_stats.projectile_scene.instantiate()
	projectile.global_position = muzzle.global_position
	
	if projectile.has_method("setup_as_enemy_projectile"):
		projectile.setup_as_enemy_projectile(projectile_stats)
	
	projectile.direction = Vector2.DOWN
	
	get_tree().current_scene.add_child(projectile)
	
	if shoot_sfx:
		emit_signal("request_sfx", shoot_sfx, global_position, Vector2(0.8, 1.2), -5.0)

func change_state(new_state: BossState) -> void:
	current_state = new_state
	state_timer = 0.0

func _on_died() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)
	remove_from_group("boss")
	super._on_died()

func _on_trigger_body_entered(body: Node2D) -> void:
	pass

func handle_charging_laser_state(delta: float) -> void:
	var distance_to_target = global_position.distance_to(movement_target)
	if distance_to_target > 15.0:
		move_toward_target(delta, 0.5)
	
	var charge_progress = state_timer / laser_charge_time
	charge_progress = clamp(charge_progress, 0.0, 1.0)
	
	var current_width = charge_progress * max_laser_width
	var current_shapecast_width = charge_progress * max_shapecast_width
	
	if using_single_laser:
		if active_laser_side == "left":
			if left_line:
				left_line.width = current_width
			if left_shapecast:
				update_shapecast_width(left_shapecast, current_shapecast_width)
		elif active_laser_side == "right":
			if right_line:
				right_line.width = current_width
			if right_shapecast:
				update_shapecast_width(right_shapecast, current_shapecast_width)
	else:
		if left_line:
			left_line.width = current_width
		if left_shapecast:
			update_shapecast_width(left_shapecast, current_shapecast_width)
		if right_line:
			right_line.width = current_width
		if right_shapecast:
			update_shapecast_width(right_shapecast, current_shapecast_width)
	
	if state_timer >= laser_charge_time:
		activate_laser()
		change_state(BossState.LASER_ATTACK)

func handle_laser_attack_state(delta: float) -> void:
	if player_ref:
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		
		if distance_to_player > 85.0:
			movement_target.x = player_ref.global_position.x
			movement_target.y = target_position_y
			move_toward_target(delta, 0.25)
	
	if state_timer >= laser_active_time:
		deactivate_laser()
		change_state(BossState.FOLLOWING)

func update_shapecast_width(shapecast: ShapeCast2D, width: float) -> void:
	if shapecast and shapecast.shape is CapsuleShape2D:
		var capsule = shapecast.shape as CapsuleShape2D
		capsule.radius = width / 2.0
	elif shapecast and shapecast.shape is RectangleShape2D:
		var rectangle = shapecast.shape as RectangleShape2D
		rectangle.size.x = width

func activate_laser() -> void:
	if using_single_laser:
		if active_laser_side == "left" and left_shapecast:
			left_shapecast.enabled = true
		elif active_laser_side == "right" and right_shapecast:
			right_shapecast.enabled = true
	else:
		if left_shapecast:
			left_shapecast.enabled = true
		if right_shapecast:
			right_shapecast.enabled = true

func deactivate_laser() -> void:
	if left_shapecast:
		left_shapecast.enabled = false
	if right_shapecast:
		right_shapecast.enabled = false
	
	players_hit_by_laser.clear()
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	if left_line:
		tween.tween_property(left_line, "width", 0.0, 0.3)
	if right_line:
		tween.tween_property(right_line, "width", 0.0, 0.3)
	
	if left_shapecast:
		tween.tween_method(update_shapecast_width.bind(left_shapecast), max_shapecast_width, 0.0, 0.3)
	if right_shapecast:
		tween.tween_method(update_shapecast_width.bind(right_shapecast), max_shapecast_width, 0.0, 0.3)
