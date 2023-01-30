extends Node2D

var host_player = null 
var host_id

func _ready():
	host_id = multiplayer.get_unique_id()
	host_player = create_player(host_id)
	var peers = multiplayer.get_peers()
	for peer in peers:
		print("peer found: " + peer)
		create_player(peer)
	# Listen to peer connections, and create new player for them
	multiplayer.peer_connected.connect(self.create_player)
	# Listen to peer disconnections, and destroy their players
	multiplayer.peer_disconnected.connect(self.destroy_player)

func create_player(id):
	print("spawning: " + str(id))
	var player = preload("res://Characters/Aliens/Player.tscn").instantiate()
	player.name = str(id)
	#player.set_network_master(id)
	#Player positions are randomized different for each player, but in this setup it doesn't matter
	#If you are going to actually use randomization in a multiplayer game, consider synchronizing rng seeds
	player.position = Vector2(randf_range(0,1080),randf_range(0,1920))
	add_child(player)
	return player

func destroy_player(id : int) -> void:
	# Delete this peer's node.
	$Players.get_node(str(id)).queue_free()
