extends EnemyBase
class_name BossEnemy

@export var projectile_stats: ProjectileStats
@export var shoot_sfx: AudioStream
@export var target_position_y: float = -250.0
@export var attack_range: float = 2000.0
@export var screen_margin: float = 100.0  
@export var min_y_position: float = -280.0
@export var max_y_position: float = -120.0

enum BossState {
	ENTERING,
	HUNTING,
	ATTACKING,
	LASER_CHARGE,
	LASER_ACTIVE,
	SPIRAL_ATTACK
}

var current_state: BossState = BossState.ENTERING
var state_timer: float = 0.0
var muzzles: Array[Node2D] = []
var player_ref: Node2D

var left_shapecast: ShapeCast2D
var right_shapecast: ShapeCast2D
var left_line: Line2D
var right_line: Line2D
var laser_charge_time: float = 1.2 
var laser_active_time: float = 2.5  
var laser_cooldown_timer: float = 0.0
var laser_cooldown: float = 6.0  
var max_laser_width: float = 50.0  
var max_shapecast_width: float = 22.0  
var laser_range: float = 900.0
var laser_damage: int = 1  
var laser_damage_timer: float = 0.0
var laser_damage_interval: float = 0.25

var move_target: Vector2
var orbit_radius: float = 280.0
var orbit_angle: float = 0.0
var orbit_speed: float = 1.8 

var attack_timer: float = 0.0
var attack_cooldown: float = 0.8  
var shots_fired: int = 0
var burst_size: int = 8
var burst_delay: float = 0.25
var burst_active: bool = false

var spiral_attack_timer: float = 0.0
var spiral_angle: float = 0.0
var spiral_shots_fired: int = 0
var max_spiral_shots: int = 16
var spiral_shot_interval: float = 0.2

var player_velocity: Vector2 = Vector2.ZERO
var previous_player_position: Vector2 = Vector2.ZERO
var prediction_strength: float = 0.25

var screen_left_limit: float
var screen_right_limit: float
var viewport_size: Vector2

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	setup_screen_limits()
	setup_components()
	find_player()
	setup_invulnerability()
	move_target = global_position

func setup_screen_limits() -> void:
	
	viewport_size = get_viewport().get_visible_rect().size
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		var camera_pos = camera.get_screen_center_position()
		
		screen_left_limit = camera_pos.x - (viewport_size.x / 2.0) + screen_margin
		screen_right_limit = camera_pos.x + (viewport_size.x / 2.0) - screen_margin
	else:
		screen_left_limit = -viewport_size.x / 2.0 + screen_margin
		screen_right_limit = viewport_size.x / 2.0 - screen_margin
	
	print("Screen limits: Left=", screen_left_limit, " Right=", screen_right_limit)

func update_screen_limits_if_needed() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var camera_pos = camera.get_screen_center_position()
		screen_left_limit = camera_pos.x - (viewport_size.x / 2.0) + screen_margin
		screen_right_limit = camera_pos.x + (viewport_size.x / 2.0) - screen_margin

func setup_components() -> void:
	collect_muzzles()
	setup_laser_components()
	if trigger_area:
		trigger_area.queue_free()
	set_physics_process(false)

func setup_invulnerability() -> void:
	if damageable_component:
		damageable_component.can_be_invulnerable = true
		damageable_component.start_silent_invulnerability(999.0)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
		if player_ref:
			previous_player_position = player_ref.global_position

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
	left_line = get_node_or_null("MuzzleLeft/Line2D")
	right_line = get_node_or_null("MuzzleRight/Line2D")
	
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast:
			shapecast.target_position = Vector2(0, laser_range)
			shapecast.enabled = false
			shapecast.collision_mask = 1
			shapecast.collide_with_areas = false
			shapecast.collide_with_bodies = true
	
	for line in [left_line, right_line]:
		if line:
			line.width = 0.0
			line.z_index = 10
			line.visible = true
			line.clear_points()
			line.add_point(Vector2.ZERO)
			line.add_point(Vector2(0, laser_range))

func _process(delta: float) -> void:
	state_timer += delta
	attack_timer += delta
	laser_cooldown_timer += delta
	laser_damage_timer += delta
	spiral_attack_timer += delta
	orbit_angle += orbit_speed * delta
	spiral_angle += 3.0 * delta  
	
	if not player_ref:
		find_player()
		return
	
	update_screen_limits_if_needed()
	
	update_player_velocity(delta)
	update_movement_target()
	
	match current_state:
		BossState.ENTERING:
			handle_entering(delta)
		BossState.HUNTING:
			handle_hunting(delta)
		BossState.ATTACKING:
			handle_attacking(delta)
		BossState.LASER_CHARGE:
			handle_laser_charge(delta)
		BossState.LASER_ACTIVE:
			handle_laser_active(delta)
		BossState.SPIRAL_ATTACK:
			handle_spiral_attack(delta)

func update_player_velocity(delta: float) -> void:
	if player_ref and delta > 0:
		var current_pos = player_ref.global_position
		player_velocity = (current_pos - previous_player_position) / delta
		previous_player_position = current_pos

func get_predicted_player_position() -> Vector2:
	if not player_ref:
		return Vector2.ZERO
	
	var prediction_time = 0.3  
	return player_ref.global_position + (player_velocity * prediction_time * prediction_strength)

func update_movement_target() -> void:
	if not player_ref:
		return
	
	var player_pos = player_ref.global_position
	
	match current_state:
		BossState.HUNTING, BossState.ATTACKING:
			var orbit_offset = Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
			move_target = player_pos + orbit_offset
			# Usa os limites calculados automaticamente
			move_target.x = clamp(move_target.x, screen_left_limit, screen_right_limit)
			move_target.y = clamp(move_target.y, min_y_position, max_y_position)
		
		BossState.LASER_CHARGE, BossState.LASER_ACTIVE:
			move_target.x = clamp(player_pos.x, screen_left_limit, screen_right_limit)
			move_target.y = target_position_y
		
		BossState.SPIRAL_ATTACK:
			var screen_center_x = (screen_left_limit + screen_right_limit) / 2.0
			move_target.x = screen_center_x
			move_target.y = target_position_y

func handle_entering(delta: float) -> void:
	if global_position.y < target_position_y:
		global_position.y += stats.speed * delta
	else:
		end_invulnerability()
		change_state(BossState.HUNTING)

func handle_hunting(delta: float) -> void:
	move_towards_target(delta)
	
	if spiral_attack_timer >= 8.0 and randf() < 0.4:
		change_state(BossState.SPIRAL_ATTACK)
		return
	
	if should_start_laser():
		change_state(BossState.LASER_CHARGE)
		return
	
	if attack_timer >= attack_cooldown:
		change_state(BossState.ATTACKING)

func handle_attacking(delta: float) -> void:
	move_towards_target(delta)
	
	if not burst_active:
		start_burst()
	
	if burst_active and state_timer >= burst_delay:
		fire_projectile()
		shots_fired += 1
		state_timer = 0.0
		
		if shots_fired >= burst_size:
			end_burst()
			change_state(BossState.HUNTING)

func handle_spiral_attack(delta: float) -> void:
	move_towards_target(delta)
	
	if state_timer >= spiral_shot_interval:
		fire_spiral_projectiles()
		spiral_shots_fired += 1
		state_timer = 0.0
		
		if spiral_shots_fired >= max_spiral_shots:
			spiral_shots_fired = 0
			spiral_attack_timer = 0.0
			change_state(BossState.HUNTING)

func handle_laser_charge(delta: float) -> void:
	move_towards_target(delta)
	
	var charge_progress = state_timer / laser_charge_time
	charge_progress = clamp(charge_progress, 0.0, 1.0)
	
	var current_width = charge_progress * max_laser_width
	var current_shapecast_width = charge_progress * max_shapecast_width
	
	for line in [left_line, right_line]:
		if line:
			line.width = current_width
	
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast:
			update_shapecast_width(shapecast, current_shapecast_width)
	
	if state_timer >= laser_charge_time:
		activate_laser()
		change_state(BossState.LASER_ACTIVE)

func handle_laser_active(delta: float) -> void:
	move_towards_target(delta)
	
	if laser_damage_timer >= laser_damage_interval:
		process_laser_damage()
		laser_damage_timer = 0.0
	
	if state_timer >= laser_active_time:
		deactivate_laser()
		change_state(BossState.HUNTING)

func move_towards_target(delta: float) -> void:
	var direction = (move_target - global_position).normalized()
	var distance = global_position.distance_to(move_target)
	
	if distance > 20.0:
		global_position += direction * stats.speed * delta
		global_position.x = clamp(global_position.x, screen_left_limit, screen_right_limit)
		global_position.y = clamp(global_position.y, min_y_position, max_y_position)

func should_start_laser() -> bool:
	if laser_cooldown_timer < laser_cooldown:
		return false
	if current_state in [BossState.LASER_CHARGE, BossState.LASER_ACTIVE]:
		return false
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	return distance_to_player > 180.0 and randf() < 0.45

func start_burst() -> void:
	burst_active = true
	shots_fired = 0
	state_timer = 0.0

func end_burst() -> void:
	burst_active = false
	attack_timer = 0.0

func fire_projectile() -> void:
	if muzzles.size() == 0 or not projectile_stats or not projectile_stats.projectile_scene:
		return
	
	var predicted_player_pos = get_predicted_player_position()
	
	for i in range(muzzles.size()):
		var muzzle = muzzles[i]
		var projectile = projectile_stats.projectile_scene.instantiate()
		projectile.global_position = muzzle.global_position
		
		if projectile.has_method("setup_as_enemy_projectile"):
			projectile.setup_as_enemy_projectile(projectile_stats)
		
		var spread_angle = randf_range(-0.2, 0.2)  
		var direction_to_player = (predicted_player_pos - muzzle.global_position).normalized()
		var rotated_direction = direction_to_player.rotated(spread_angle)
		
		projectile.direction = rotated_direction
		
		if projectile.has_method("set_rotation") or "rotation" in projectile:
			var angle = rotated_direction.angle() - PI/2  
			projectile.rotation = angle
		
		get_tree().current_scene.add_child(projectile)
	
	if shoot_sfx:
		emit_signal("request_sfx", shoot_sfx, global_position, Vector2(0.9, 1.3), -3.0)

func fire_spiral_projectiles() -> void:
	if muzzles.size() == 0 or not projectile_stats or not projectile_stats.projectile_scene:
		return
	
	var directions_count = 6
	for i in range(directions_count):
		var base_angle = (spiral_angle + (i * PI * 2 / directions_count))
		var direction = Vector2(cos(base_angle), sin(base_angle))
		
		for muzzle in muzzles:
			var projectile = projectile_stats.projectile_scene.instantiate()
			projectile.global_position = muzzle.global_position
			
			if projectile.has_method("setup_as_enemy_projectile"):
				projectile.setup_as_enemy_projectile(projectile_stats)
			
			projectile.direction = direction
			
			if projectile.has_method("set_rotation") or "rotation" in projectile:
				var angle = direction.angle() - PI/2  
				projectile.rotation = angle
			
			get_tree().current_scene.add_child(projectile)
	
	if shoot_sfx:
		emit_signal("request_sfx", shoot_sfx, global_position, Vector2(0.8, 1.2), -3.0)

func activate_laser() -> void:
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast:
			shapecast.enabled = true

func deactivate_laser() -> void:
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast:
			shapecast.enabled = false
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	for line in [left_line, right_line]:
		if line:
			tween.tween_property(line, "width", 0.0, 0.3)
	
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast:
			tween.tween_method(update_shapecast_width.bind(shapecast), max_shapecast_width, 0.0, 0.3)
	
	laser_cooldown_timer = 0.0

func process_laser_damage() -> void:
	for shapecast in [left_shapecast, right_shapecast]:
		if shapecast and shapecast.enabled and shapecast.is_colliding():
			var collision_count = shapecast.get_collision_count()
			for i in range(collision_count):
				var collider = shapecast.get_collider(i)
				if collider and collider.has_method("get_node"):
					var player_damageable = collider.get_node_or_null("DamageableComponent") as DamageableComponent
					if player_damageable:
						var damage_info = DamageInfo.new(laser_damage)
						player_damageable.apply_damage(damage_info)

func update_shapecast_width(shapecast: ShapeCast2D, width: float) -> void:
	if not shapecast or not shapecast.shape:
		return
	
	if shapecast.shape is CapsuleShape2D:
		var capsule = shapecast.shape as CapsuleShape2D
		capsule.radius = width / 2.0
	elif shapecast.shape is RectangleShape2D:
		var rectangle = shapecast.shape as RectangleShape2D
		rectangle.size.x = width

func change_state(new_state: BossState) -> void:
	current_state = new_state
	state_timer = 0.0

func end_invulnerability() -> void:
	if damageable_component:
		damageable_component.end_invulnerability()

func _on_died() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)
	remove_from_group("boss")
	super._on_died()

func _on_trigger_body_entered(body: Node2D) -> void:
	pass
