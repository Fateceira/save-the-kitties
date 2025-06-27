extends Control
class_name JuicyHealthBar

@export var animation_duration: float = 0.8
@export var bottom_layer_delay: float = 0.3

@onready var top_layer: ProgressBar = $TopLayer
@onready var bottom_layer: ProgressBar = $BottomLayer

var player_damageable: DamageableComponent
var health_tween: Tween
var bottom_tween: Tween

func _ready() -> void:
	call_deferred("find_and_connect_to_player")

func find_and_connect_to_player() -> void:
	var player = find_player_node()
	
	if player:
		setup_player_connection(player)
	else:
		print("JuicyHealthBar: Player não encontrado")

func find_player_node() -> Node:
	# Tenta pelo grupo primeiro
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player
	
	# Busca na cena toda por qualquer nó que tenha DamageableComponent
	var root = get_tree().current_scene
	return search_for_player(root)

func search_for_player(node: Node) -> Node:
	# Se este nó tem DamageableComponent, é o player
	if node.has_node("DamageableComponent"):
		return node
	
	# Procura nos filhos
	for child in node.get_children():
		var found = search_for_player(child)
		if found:
			return found
	
	return null

func setup_player_connection(player: Node) -> void:
	player_damageable = player.get_node_or_null("DamageableComponent")
	
	if player_damageable:
		player_damageable.damaged.connect(on_damage_taken)
		setup_initial_values()
		print("JuicyHealthBar: Conectado ao player com sucesso!")
	else:
		print("JuicyHealthBar: DamageableComponent não encontrado no player")

func setup_initial_values() -> void:
	var max_hp = player_damageable.max_hp
	var current_hp = player_damageable.current_hp
	
	top_layer.max_value = max_hp
	top_layer.value = current_hp
	bottom_layer.max_value = max_hp
	bottom_layer.value = current_hp

func on_damage_taken(damage_info: DamageInfo) -> void:
	var new_health = player_damageable.current_hp
	animate_health_bars(new_health)

func animate_health_bars(new_health: int) -> void:
	if health_tween:
		health_tween.kill()
	if bottom_tween:
		bottom_tween.kill()
	
	animate_top_layer(new_health)
	animate_bottom_layer(new_health)

func animate_top_layer(new_health: int) -> void:
	health_tween = create_tween()
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.set_trans(Tween.TRANS_QUART)
	
	health_tween.tween_property(
		top_layer,
		"value",
		new_health,
		animation_duration * 0.3
	)

func animate_bottom_layer(new_health: int) -> void:
	bottom_tween = create_tween()
	bottom_tween.set_ease(Tween.EASE_OUT)
	bottom_tween.set_trans(Tween.TRANS_EXPO)
	
	bottom_tween.tween_property(
		bottom_layer,
		"value",
		new_health,
		animation_duration
	).set_delay(bottom_layer_delay)
