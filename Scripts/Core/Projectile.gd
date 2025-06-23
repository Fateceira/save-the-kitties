extends Area2D

var projectile_stats: ProjectileStats
var direction: Vector2 = Vector2.UP
var player_luck: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_projectile(stats: ProjectileStats, luck: float = 0.0) -> void:
	projectile_stats = stats
	player_luck = luck

func _process(delta: float) -> void:
	if not projectile_stats:
		return
		
	global_position += direction * projectile_stats.speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not projectile_stats:
		return
		
	var damageable = body.get_node("DamageableComponent") as DamageableComponent
	if damageable:
		var final_crit_chance = projectile_stats.crit_chance + player_luck
		var is_crit = randf() < final_crit_chance
		
		var damage_info = DamageInfo.new(projectile_stats.damage, is_crit, projectile_stats.pierce)
		damageable.apply_damage(damage_info)
		
		projectile_stats.pierce -= 1
		if projectile_stats.pierce < 0:
			queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
