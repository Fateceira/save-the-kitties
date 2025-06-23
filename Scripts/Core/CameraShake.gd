extends Camera2D
class_name CameraShake

@export var max_shake: float = 3.0
@export var fade_speed: float = 12.0
@export var enemy_hit_shake: float = 2.5

var _shake_strength: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO
var connected_damageables: Array[DamageableComponent] = []

func _ready() -> void:
	_base_offset = offset
	setup_pixel_perfect()
	connect_existing_damageables()
	get_tree().node_added.connect(_on_node_added)

func setup_pixel_perfect() -> void:
	enabled = true
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	force_update_scroll()

func connect_existing_damageables() -> void:
	var all_nodes = get_tree().get_nodes_in_group("damageable")
	
	if all_nodes.is_empty():
		all_nodes = find_all_damageables()
	
	for node in all_nodes:
		if node is DamageableComponent:
			connect_damageable(node)

func find_all_damageables() -> Array:
	var damageables = []
	var scene_root = get_tree().current_scene
	_find_damageables_recursive(scene_root, damageables)
	return damageables

func _find_damageables_recursive(node: Node, damageables: Array) -> void:
	if node is DamageableComponent:
		damageables.append(node)
	
	for child in node.get_children():
		_find_damageables_recursive(child, damageables)

func _on_node_added(node: Node) -> void:
	if node is DamageableComponent:
		connect_damageable(node)

func connect_damageable(damageable: DamageableComponent) -> void:
	if damageable in connected_damageables:
		return
	
	if not damageable.damaged.is_connected(_on_damage_received):
		damageable.damaged.connect(_on_damage_received.bind(damageable))
		connected_damageables.append(damageable)

func _on_damage_received(damage_info, damageable: DamageableComponent) -> void:
	var damaged_entity = damageable.get_parent()
	
	if not damaged_entity.is_in_group("player"):
		shake(enemy_hit_shake)

func shake(intensity: float = max_shake) -> void:
	_shake_strength = max(_shake_strength, intensity)

func _process(delta: float) -> void:
	if _shake_strength > 0:
		_shake_strength = lerp(_shake_strength, 0.0, fade_speed * delta)
		
		var shake_x = round(randf_range(-_shake_strength, _shake_strength))
		var shake_y = round(randf_range(-_shake_strength, _shake_strength))
		var shake_offset = Vector2(shake_x, shake_y)
		
		offset = _base_offset + shake_offset
		force_update_scroll()
		
		if _shake_strength < 0.1:
			_shake_strength = 0.0
			offset = _base_offset
			force_update_scroll()

func _exit_tree() -> void:
	for damageable in connected_damageables:
		if is_instance_valid(damageable) and damageable.damaged.is_connected(_on_damage_received):
			damageable.damaged.disconnect(_on_damage_received)
	
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func connect_to(damageable: DamageableComponent) -> void:
	connect_damageable(damageable)
