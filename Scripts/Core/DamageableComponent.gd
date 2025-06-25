extends Node
class_name DamageableComponent

@export var max_hp: int = 10
@export var can_be_invulnerable: bool = false
@export var invulnerability_duration: float = 1.0
@export var invulnerability_on_damage: bool = false

var current_hp: int
var is_invulnerable: bool = false
var invulnerability_timer: Timer
var should_blink_on_invulnerability: bool = true 

signal died
signal damaged(damage_info)
signal invulnerability_started(should_blink: bool) 
signal invulnerability_ended

func _ready() -> void:
	current_hp = max_hp
	setup_invulnerability_timer()

func setup_invulnerability_timer() -> void:
	if can_be_invulnerable:
		invulnerability_timer = Timer.new()
		invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
		add_child(invulnerability_timer)

func apply_damage(damage_info: DamageInfo) -> void:
	if is_invulnerable:
		return
	
	current_hp -= damage_info.amount
	emit_signal("damaged", damage_info)

	if damage_info.is_crit:
		print("Critou!")

	if invulnerability_on_damage and can_be_invulnerable:
		start_invulnerability()

	if current_hp <= 0:
		die()

func start_invulnerability(duration: float = -1.0, enable_blink: bool = true) -> void:
	if not can_be_invulnerable:
		return
	
	is_invulnerable = true
	should_blink_on_invulnerability = enable_blink
	emit_signal("invulnerability_started", should_blink_on_invulnerability)
	
	if invulnerability_timer:
		if duration > 0:
			invulnerability_timer.wait_time = duration
		else:
			invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.start()

func start_silent_invulnerability(duration: float = -1.0) -> void:
	start_invulnerability(duration, false)

func end_invulnerability() -> void:
	if not is_invulnerable:
		return
	
	is_invulnerable = false
	should_blink_on_invulnerability = true 
	emit_signal("invulnerability_ended")
	
	if invulnerability_timer and not invulnerability_timer.is_stopped():
		invulnerability_timer.stop()

func _on_invulnerability_timeout() -> void:
	end_invulnerability()

func die() -> void:
	emit_signal("died")
	if owner:
		owner.queue_free()

func set_max_hp(value: int) -> void:
	max_hp = value
	current_hp = max_hp

func get_hp_percentage() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

func is_alive() -> bool:
	return current_hp > 0
