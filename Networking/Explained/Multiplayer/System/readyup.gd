extends Control

@export
var PlayerScene = preload("res://Characters/Player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_start_game_button_pressed():
	if multiplayer.has_multiplayer_peer():
		print("yo.... Its connected bro")
	get_node("/root/main_menu/HolePunch").finalize_peers()

func _on_cancel_button_pressed():
	get_tree().change_scene_to_file("res://System/main_menu.tscn")
	
func _on_ready_button_pressed():
	print("ready pressed")

func _player_connected(id):
	print("Player " + id + " connected!")

func setup_player_spawning(server: bool) -> void:
	var peer = ENetMultiplayerPeer.new()
	if server:
		# Listen to peer connections, and create new player for them
		multiplayer.peer_connected.connect(self.create_player)
		# Listen to peer disconnections, and destroy their players
		multiplayer.peer_disconnected.connect(self.destroy_player)

	multiplayer.set_multiplayer_peer(peer)
	
func create_player(id : int) -> void:
	# Instantiate a new player for this client.
	var p = PlayerScene.instantiate()

	# Set the name, so players can figure out their local authority
	p.name = str(id)
	
	$Players.add_child(p)

func destroy_player(id : int) -> void:
	# Delete this peer's node.
	$Players.get_node(str(id)).queue_free()
