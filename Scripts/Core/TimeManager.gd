extends Node
class_name TimeManager

var is_hitstop: bool = false
var hitstop_timer: float = 0.0
var connected_components: Array = []

@export var HITSTOP_DURATION: float = 0.02
@export var HITSTOP_TIMESCALE: float = 0.2

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _process(delta: float) -> void:
	if is_hitstop:
		hitstop_timer -= delta
		if hitstop_timer <= 0.0:
			reset_timescale()

func trigger_hitstop() -> void:
	if is_hitstop:
		return
	is_hitstop = true
	hitstop_timer = HITSTOP_DURATION
	Engine.time_scale = HITSTOP_TIMESCALE

func reset_timescale() -> void:
	Engine.time_scale = 1.0
	is_hitstop = false

func _on_node_added(node: Node) -> void:
	if node is DamageableComponent and node.owner and node.owner is EnemyBase:
		if not connected_components.has(node):
			node.damaged.connect(_on_enemy_damaged.bind(node))
			connected_components.append(node)

func _on_node_removed(node: Node) -> void:
	if node is DamageableComponent and connected_components.has(node):
		connected_components.erase(node)

func _on_enemy_damaged(damage_info: DamageInfo, node: Node) -> void:
	trigger_hitstop()
