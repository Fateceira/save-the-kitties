extends CharacterBody2D
class_name EnemyBase

@export var stats: EnemyStats
@export var damage_sfx: AudioStream
@export var death_sfx: AudioStream

signal request_sfx(audio_stream, position, pitch_range, volume_db) 

var damageable_component: DamageableComponent
var trigger_area: Area2D
var trigger_collision: CollisionShape2D

func _ready() -> void:
	damageable_component = $DamageableComponent
	if stats and damageable_component:
		damageable_component.set_max_hp(stats.max_hp)
	
	damageable_component.died.connect(_on_died)
	damageable_component.damaged.connect(_on_enemy_damaged)
	setup_trigger_area()

func _on_enemy_damaged(damage_info: DamageInfo) -> void:
	if damage_sfx:
		emit_signal("request_sfx", damage_sfx, global_position, Vector2(0.9, 1.1), 0.0)

func setup_trigger_area() -> void:
	trigger_area = Area2D.new()
	trigger_collision = CollisionShape2D.new()
	
	add_child(trigger_area)
	trigger_area.add_child(trigger_collision)
	
	var main_collision = $CollisionShape2D
	if main_collision and main_collision.shape:
		trigger_collision.shape = main_collision.shape.duplicate()
	
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 1
	
	trigger_area.body_entered.connect(_on_trigger_body_entered)

func _physics_process(delta: float) -> void:
	if stats:
		velocity.y = stats.speed
		move_and_slide()

func _on_trigger_body_entered(body: Node2D) -> void:
	if body.has_method("get_node"):
		var player_damageable = body.get_node("DamageableComponent") as DamageableComponent
		if player_damageable and stats:
			var damage_info = DamageInfo.new(stats.contact_damage)
			player_damageable.apply_damage(damage_info)
			damageable_component.die()

func _on_died() -> void:
	if death_sfx:
		emit_signal("request_sfx", death_sfx, global_position, Vector2(1.0, 1.0), 0.0)
	queue_free()

func setup_enemy(given_stats: EnemyStats) -> void:
	stats = given_stats.duplicate()
