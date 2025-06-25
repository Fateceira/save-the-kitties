extends Node

@export var punch_scale: Vector2 = Vector2(1.4, 0.6)
@export var return_duration: float = 0.12
@export var return_ease: Tween.EaseType = Tween.EASE_OUT
@export var return_transition: Tween.TransitionType = Tween.TRANS_BACK

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("scan_existing_nodes")

func scan_existing_nodes() -> void:
	if get_tree().current_scene:
		scan_and_connect(get_tree().current_scene)

func scan_and_connect(node: Node) -> void:
	connect_node_if_needed(node)
	for child in node.get_children():
		scan_and_connect(child)

func _on_node_added(node: Node) -> void:
	call_deferred("connect_node_if_needed", node)

func connect_node_if_needed(node: Node) -> void:
	if node is DamageableComponent and not node.damaged.is_connected(_on_damage_received):
		node.damaged.connect(_on_damage_received.bind(node))

func _on_damage_received(_damage_info: DamageInfo, component: DamageableComponent) -> void:
	var root = component.get_owner() if component.get_owner() else component
	if not is_instance_valid(root):
		return
	
	var tween = create_tween()
	
	root.scale = punch_scale
	
	tween.tween_property(root, "scale", Vector2.ONE, return_duration)\
		.set_ease(return_ease)\
		.set_trans(return_transition)
