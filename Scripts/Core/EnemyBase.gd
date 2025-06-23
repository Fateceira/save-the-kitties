extends CharacterBody2D
class_name EnemyBase

@export var stats: EnemyStats

var damageable_component: DamageableComponent

func _ready() -> void:
	damageable_component = $DamageableComponent
	if stats and damageable_component:
		damageable_component.set_max_hp(stats.max_hp)
	
	damageable_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if stats:
		velocity.y = stats.speed
		move_and_slide()
		check_collisions()

func check_collisions() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		_check_player_collision(body)

func _check_player_collision(body: Node2D) -> void:
	if body and body.has_method("get_node"):
		var player_damageable = body.get_node("DamageableComponent") as DamageableComponent
		if player_damageable and stats:
			var damage_info = DamageInfo.new(stats.contact_damage)
			player_damageable.apply_damage(damage_info)
			damageable_component.die()

func _on_died() -> void:
	queue_free()

func setup_enemy(given_stats: EnemyStats) -> void:
	stats = given_stats.duplicate()
