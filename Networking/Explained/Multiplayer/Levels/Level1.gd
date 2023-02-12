extends Node2D

var host_player = null 
var host_id
var num_connected = 0
var alive := {}

func _ready():
	host_id = multiplayer.get_unique_id()
	host_player = create_player(host_id)
	var peers = multiplayer.get_peers()
	for peer in peers:
		print("peer found: " + str(peer))
		create_player(peer)
	# Listen to peer disconnections, and destroy their players
	multiplayer.peer_disconnected.connect(self.destroy_player)

func create_player(id):
	var player = preload("res://Characters/Aliens/Player.tscn").instantiate()
	var memory_node = $PlayerData.get_node("Players")
	player.name = str(id)
	player.position = Vector2(randf_range(0,1920),randf_range(0,1080))
	add_child(player)
	if multiplayer.is_server():
		for entry in memory_node.contents:
			if memory_node.contents[entry]["id"] == id:
				var new_name = memory_node.contents[entry]["name"]
				player.change_name(new_name.rstrip("0123456789"))
	num_connected = num_connected + 1
	alive[id] = true
	player.i_die.connect(self.kill_player)
	
	return player

func kill_player(id: int) -> void:
	print("killing " + str(id))
	alive[id] = false
	if one_left():
		print("Winner found!")

func destroy_player(id : int) -> void:
	# Delete this peer's node.
	print("destroying " + str(id))
	get_node(str(id)).queue_free()

func one_left() -> bool:
	return get_all_alive(alive).size() == 1
	
func get_all_alive(map) -> Array:
	return get_all_matching(map, true)
	
func get_all_dead(map) -> Array:
	return get_all_matching(map, false)

func get_all_matching(map, value) -> Array:
	var result:=[]
	for gamer in alive.keys():
		if alive[gamer] == value:
			result.append(gamer)
	return result
