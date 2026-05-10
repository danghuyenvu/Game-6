extends Node

var players: Dictionary = {}   # peer_id → {name, team, …}

func _ready():
	multiplayer.peer_disconnected.connect(_remove_player)

func register_player(id: int, info: Dictionary):
	players[id] = info

func _remove_player(id: int):
	players.erase(id)

# Called by each client after connecting to tell server their info
@rpc("any_peer", "call_local", "reliable")
func send_player_info(name: String):
	var id = multiplayer.get_remote_sender_id()
	register_player(id, {"name": name})
