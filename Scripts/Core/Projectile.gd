extends Area2D

var projectile_stats: ProjectileStats
var direction: Vector2 = Vector2.UP
var player_luck: float = 0.0
var player_crit_multiplier: float = 2.0
var remaining_pierce: int = 0
var is_enemy_projectile: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_projectile(stats: ProjectileStats, luck: float = 0.0, crit_multiplier: float = 2.0) -> void:
	projectile_stats = stats
	player_luck = luck
	player_crit_multiplier = crit_multiplier
	remaining_pierce = stats.pierce

func setup_as_enemy_projectile(stats: ProjectileStats) -> void:
	projectile_stats = stats
	remaining_pierce = stats.pierce
	is_enemy_projectile = true
	direction = Vector2.DOWN
	collision_layer = 4
	collision_mask = 1

func _process(delta: float) -> void:
	if not projectile_stats:
		return
	global_position += direction * projectile_stats.speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not projectile_stats:
		return
	
	if is_enemy_projectile:
		if not body.is_in_group("player"):
			return
	else:
		if not body.is_in_group("enemies"):
			return
	
	var damageable = body.get_node("DamageableComponent") as DamageableComponent
	if damageable:
		var is_crit = randf() < player_luck
		var final_damage = projectile_stats.damage

		if is_crit:
			final_damage *= player_crit_multiplier

		var damage_info = DamageInfo.new(final_damage, is_crit, remaining_pierce)
		damageable.apply_damage(damage_info)

		spawn_impact_spark(global_position)

		remaining_pierce -= 1
		if remaining_pierce < 0:
			queue_free()

func spawn_impact_spark(pos: Vector2) -> void:
	if projectile_stats and projectile_stats.impact_spark_scene:
		var spark = projectile_stats.impact_spark_scene.instantiate()
		spark.global_position = pos
		get_tree().current_scene.add_child(spark)

		var particles = find_particles_in_node(spark)
		if particles:
			particles.emitting = true
			particles.restart()

			var timer = Timer.new()
			timer.wait_time = particles.lifetime + 0.3
			timer.one_shot = true
			timer.timeout.connect(_destroy_node.bind(spark, timer))
			spark.add_child(timer)
			timer.start()

func find_particles_in_node(node: Node) -> CPUParticles2D:
	if node is CPUParticles2D:
		return node
	for child in node.get_children():
		var found = find_particles_in_node(child)
		if found:
			return found
	return null

func _destroy_node(target_node: Node, timer: Timer) -> void:
	if is_instance_valid(target_node):
		target_node.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
