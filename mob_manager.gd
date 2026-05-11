extends Node

var cached_target: Node3D = null
var _refresh_timer: float = 0.0

# Global nav request queue — limits pathfinding to N requests per frame
const MAX_NAV_REQUESTS_PER_FRAME := 3
var _nav_queue: Array = []  # Array of NavigationAgent3D
var _nav_processed: int = 0

func _ready() -> void:
	# Process nav queue in physics step so it aligns with CharacterBody3D
	set_physics_process(true)

func request_nav_path(agent: NavigationAgent3D, target_pos: Vector3) -> void:
	# Store as pair so we know what position to path to
	_nav_queue.append([agent, target_pos])

func _physics_process(_delta: float) -> void:
	# Drain up to MAX_NAV_REQUESTS_PER_FRAME per frame
	_nav_processed = 0
	while _nav_queue.size() > 0 and _nav_processed < MAX_NAV_REQUESTS_PER_FRAME:
		var entry = _nav_queue.pop_front()
		var agent: NavigationAgent3D = entry[0]
		var pos: Vector3 = entry[1]
		if is_instance_valid(agent):
			agent.target_position = pos
		_nav_processed += 1

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.25

	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		var scene := get_tree().current_scene
		if is_instance_valid(scene):
			var proto := scene.find_child("ProtoController", true, false)
			cached_target = proto as Node3D
		return

	for p in players:
		if p is Node3D and is_instance_valid(p):
			cached_target = p as Node3D
			break
