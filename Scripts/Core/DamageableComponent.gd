extends Node
class_name DamageableComponent

@export var max_hp: int = 10
var current_hp: int

signal died
signal damaged(damage_info)

func _ready() -> void:
	current_hp = max_hp

func apply_damage(damage_info: DamageInfo) -> void:
	current_hp -= damage_info.amount

	emit_signal("damaged", damage_info)

	if damage_info.is_crit:
		print("Critou!")

	if current_hp <= 0:
		die()

func die() -> void:
	emit_signal("died")
	if owner:
		owner.queue_free()

func set_max_hp(value: int) -> void:
	max_hp = value
	current_hp = max_hp
