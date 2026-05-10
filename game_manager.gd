extends Node

# Tracks all connected players: peer_id → info dict
var players: Dictionary = {}

func _ready():
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int):
	players.erase(id)
	print("Player removed: ", id)

@rpc("any_peer", "call_local", "reliable")
func register_player(player_name: String):
	var id = multiplayer.get_remote_sender_id()
	# get_remote_sender_id() returns 0 when called locally, use own id then
	if id == 0:
		id = multiplayer.get_unique_id()
	players[id] = { "name": player_name }
	print("Registered player ", id, " as ", player_name)
