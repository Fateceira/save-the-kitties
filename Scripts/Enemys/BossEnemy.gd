extends EnemyBase
class_name BossEnemy

@export var projectile_stats: ProjectileStats
@export var shoot_sfx: AudioStream
@export var target_position_y: float = -250.0
@export var follow_delay: float = 1.2
@export var attack_range: float = 2000.0

enum BossState {
	ENTERING,
	FOLLOWING,
	ATTACKING
}

var current_state: BossState = BossState.ENTERING
var state_timer: float = 0.0
var muzzles: Array[Node2D] = []
var player_ref: Node2D

var target_position: Vector2
var follow_timer: float = 0.0

var attack_timer: float = 0.0
var attack_cooldown: float = 1.8
var shots_in_burst: int = 0
var max_shots_in_burst: int = 4
var shot_interval: float = 0.3
var burst_active: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	collect_muzzles()
	setup_boss_behavior()
	find_player()
	
	target_position = global_position

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

func _process(delta: float) -> void:
	state_timer += delta
	follow_timer += delta
	attack_timer += delta
	
	if not player_ref:
		find_player()
		return
	
	update_target_position()
	
	match current_state:
		BossState.ENTERING:
			handle_entering_state(delta)
		BossState.FOLLOWING:
			handle_following_state(delta)
		BossState.ATTACKING:
			handle_attacking_state(delta)

func update_target_position() -> void:
	if not player_ref or follow_timer < follow_delay:
		return
	
	var player_pos = player_ref.global_position
	target_position.x = player_pos.x
	target_position.y = target_position_y
	
	follow_timer = 0.0

func handle_entering_state(delta: float) -> void:
	if global_position.y < target_position_y:
		global_position.y += stats.speed * 0.5 * delta
	else:
		change_state(BossState.FOLLOWING)

func handle_following_state(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	
	if distance > 30.0:
		global_position += direction * stats.speed * 0.7 * delta
	
	if attack_timer >= attack_cooldown:
		start_attack_burst()

func handle_attacking_state(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	
	if distance > 30.0:
		global_position += direction * stats.speed * 0.4 * delta
	
	if not burst_active:
		return
	
	if state_timer >= shot_interval:
		fire_shot()
		shots_in_burst += 1
		state_timer = 0.0
		
		if shots_in_burst >= max_shots_in_burst:
			end_attack_burst()

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
