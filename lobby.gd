extends Control

const PORT = 4001
const MAX_PLAYERS = 8

func _ready():
	# Default IP for quick testing
	$VBox/IPField.text = "127.0.0.1"

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		$VBox/Status.text = "Failed to create server: " + str(err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	$VBox/Status.text = "Hosting on port " + str(PORT) + "..."
	# Host loads the game immediately
	get_tree().change_scene_to_file("res://Map.tscn")

func _on_join_pressed():
	print("JOIN PRESSED")
	
	#if multiplayer.has_multiplayer_peer():
		#return
	var ip = $VBox/IPField.text.strip_edges()
	if ip == "":
		$VBox/Status.text = "Enter an IP address."
		return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		$VBox/Status.text = "Failed to connect: " + str(err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	$VBox/Status.text = "Connecting to " + ip + "..."

func _on_connected():
	print("CONNECTED SUCCESS")
	$VBox/Status.text = "Connected!"
	get_tree().change_scene_to_file("res://Map.tscn")

func _on_failed():
	print("CONNECTED FAILED")
	$VBox/Status.text = "Connection failed. Is the host running?"
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
