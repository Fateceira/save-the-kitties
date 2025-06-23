extends Area2D

var projectile_stats: ProjectileStats
var direction: Vector2 = Vector2.UP
var player_luck: float = 0.0
var player_crit_multiplier: float = 2.0
var remaining_pierce: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_projectile(stats: ProjectileStats, luck: float = 0.0, crit_multiplier: float = 2.0) -> void:
	projectile_stats = stats
	player_luck = luck
	player_crit_multiplier = crit_multiplier
	remaining_pierce = stats.pierce

func _process(delta: float) -> void:
	if not projectile_stats:
		return
		
	global_position += direction * projectile_stats.speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not projectile_stats:
		return
		
	var damageable = body.get_node("DamageableComponent") as DamageableComponent
	if damageable:
		var is_crit = randf() < player_luck
		var final_damage = projectile_stats.damage

		if is_crit:
			final_damage *= player_crit_multiplier

		var damage_info = DamageInfo.new(final_damage, is_crit, remaining_pierce)
		damageable.apply_damage(damage_info)
		
		remaining_pierce -= 1
		if remaining_pierce < 0:
			queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
