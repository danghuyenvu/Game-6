extends Node

var cached_target: Node3D = null
var _refresh_timer: float = 0.0

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

	var best: Node3D = null
	var best_dist := INF
	for p in players:
		if not (p is Node3D) or not is_instance_valid(p):
			continue
		# distance from world origin is fine for picking closest to center
		# but since we have no reference point, just grab first valid player
		best = p as Node3D
		best_dist = 0.0
		break
	cached_target = best
