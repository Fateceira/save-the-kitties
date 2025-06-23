extends CharacterBody2D

@export var ship_stats: ShipStats
@export var equipped_projectile: ProjectileStats

var shoot_timer: float = 0.0
var damageable_component: DamageableComponent

func _ready() -> void:
	setup_components()

func setup_components() -> void:
	damageable_component = $DamageableComponent
	if ship_stats and damageable_component:
		damageable_component.set_max_hp(ship_stats.max_hp)

func _process(delta: float) -> void:
	handle_movement(delta)
	handle_shooting(delta)

func handle_movement(delta: float) -> void:
	if not ship_stats:
		return
		
	var input_vector = Vector2.ZERO

	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()

	velocity = input_vector * ship_stats.speed
	move_and_slide()

func handle_shooting(delta: float) -> void:
	if not ship_stats or not equipped_projectile:
		return
		
	shoot_timer -= delta

	if Input.is_action_pressed("shoot") and shoot_timer <= 0:
		shoot()
		shoot_timer = ship_stats.fire_rate

func shoot() -> void:
	if not equipped_projectile or not equipped_projectile.projectile_scene:
		return

	var projectile = equipped_projectile.projectile_scene.instantiate()
	projectile.global_position = $Muzzle.global_position
	
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(equipped_projectile, ship_stats.luck)
	
	get_tree().current_scene.add_child(projectile)

func equip_projectile(new_projectile: ProjectileStats) -> void:
	equipped_projectile = new_projectile
