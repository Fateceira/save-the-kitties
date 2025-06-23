extends Node2D
class_name ExplosionManager

@export var explosion_scene: PackedScene
var connected_damageables: Array[DamageableComponent] = []

func _ready() -> void:
	connect_existing_damageables()
	get_tree().node_added.connect(_on_node_added)

func connect_existing_damageables() -> void:
	var all_nodes = find_all_damageables()
	
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
	
	if not damageable.died.is_connected(_on_entity_died):
		damageable.died.connect(_on_entity_died.bind(damageable))
		connected_damageables.append(damageable)

func _on_entity_died(damageable: DamageableComponent) -> void:
	var dead_entity = damageable.get_parent()
	
	if not dead_entity.is_in_group("player"):
		spawn_explosion(dead_entity.global_position)

func spawn_explosion(pos: Vector2) -> void:
	if not explosion_scene:
		return
	
	var explosion = explosion_scene.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = pos
	
	var particles = find_particles_in_explosion(explosion)
	if particles:
		particles.emitting = true
		particles.restart()
		
		var lifetime = particles.lifetime
		var timer = Timer.new()
		timer.wait_time = lifetime + 0.5
		timer.one_shot = true
		timer.timeout.connect(_destroy_explosion.bind(explosion, timer))
		explosion.add_child(timer)
		timer.start()

func find_particles_in_explosion(explosion_node: Node) -> CPUParticles2D:
	if explosion_node is CPUParticles2D:
		return explosion_node
	
	for child in explosion_node.get_children():
		if child is CPUParticles2D:
			return child
		
		var found = find_particles_in_explosion(child)
		if found:
			return found
	
	return null

func _destroy_explosion(explosion: Node, timer: Timer) -> void:
	if is_instance_valid(explosion):
		explosion.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func _exit_tree() -> void:
	for damageable in connected_damageables:
		if is_instance_valid(damageable) and damageable.died.is_connected(_on_entity_died):
			damageable.died.disconnect(_on_entity_died)
	
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
