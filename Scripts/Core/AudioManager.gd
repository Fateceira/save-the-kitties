extends Node

@export var pool_size: int = 16
@export var default_pitch_range: Vector2 = Vector2(0.95, 1.05)

var audio_pool: Array[AudioStreamPlayer2D] = []
var pool_index: int = 0

func _ready() -> void:
	create_audio_pool()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("scan_existing_nodes")

func create_audio_pool() -> void:
	for i in pool_size:
		var player = AudioStreamPlayer2D.new()
		add_child(player)
		audio_pool.append(player)

func scan_existing_nodes() -> void:
	_scan_and_connect(get_tree().current_scene)

func _scan_and_connect(node: Node) -> void:
	if node == null:
		return
		
	_connect_node_if_needed(node)
	for child in node.get_children():
		_scan_and_connect(child)

func _on_node_added(node: Node) -> void:
	call_deferred("_connect_node_if_needed", node)

func _connect_node_if_needed(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
		
	if node.has_signal("request_sfx"):
		if not node.request_sfx.is_connected(_on_request_sfx):
			node.request_sfx.connect(_on_request_sfx)

func _on_request_sfx(audio_stream: AudioStream, position: Vector2 = Vector2.ZERO, pitch_range: Vector2 = default_pitch_range, volume_db: float = 0.0) -> void:
	play_sfx(audio_stream, position, pitch_range, volume_db)

func play_sfx(audio_stream: AudioStream, position: Vector2 = Vector2.ZERO, pitch_range: Vector2 = default_pitch_range, volume_db: float = 0.0) -> void:
	if audio_stream == null:
		return

	var player = audio_pool[pool_index]
	pool_index = (pool_index + 1) % pool_size

	player.stop()
	player.stream = audio_stream
	player.global_position = position
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.volume_db = volume_db
	player.play()

func connect_node_manually(node: Node) -> void:
	_connect_node_if_needed(node)
