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

func create_player(id):
	print("spawning: " + id)
	var player = preload("res://Characters/Aliens/Player.tscn").instantiate()
	player.name = str(id)
	#player.set_network_master(id)
	#Player positions are randomized different for each player, but in this setup it doesn't matter
	#If you are going to actually use randomization in a multiplayer game, consider synchronizing rng seeds
	player.position = Vector2(randf_range(0,100),randf_range(0,100))
	add_child(player)
	return player
