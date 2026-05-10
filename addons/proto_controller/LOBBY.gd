extends Control

const PORT = 4242
const MAX_PLAYERS = 8

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_joined)
	# Server also loads the game
	get_tree().change_scene_to_file("res://game.tscn")

func _on_join_pressed():
	var ip = $IPField.text
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)

func _on_connected():
	get_tree().change_scene_to_file("res://game.tscn")

func _on_failed():
	$Status.text = "Connection failed."

func _on_player_joined(id: int):
	print("Player joined: ", id)
