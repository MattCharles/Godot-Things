extends Node2D

var host_player = null 
var host_id
var alive := {}
var wins := {}
var player_nodes := {}

var choice_button = preload("res://Items/upgrade_choice.tscn")

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
	add_child(player)
	if multiplayer.is_server():
		player.rpc("remote_dictate_position", _get_spawn_position($Networking.sync_num_connected, 2)) # TODO: support multiplayer games
		$Networking.sync_num_connected = $Networking.sync_num_connected + 1
		for entry in memory_node.contents:
			if memory_node.contents[entry]["id"] == id:
				var new_name = memory_node.contents[entry]["name"]
				player.change_name(new_name.rstrip("0123456789"))
	alive[id] = true
	wins[id] = 0
	player_nodes[id] = player
	player.i_die.connect(self.kill_player)
	
	return player

func kill_player(id: int) -> void: 
	print("killing " + str(id))
	alive[id] = false
	print("Winner found!")
	var winner = get_all_alive(alive)[0]
	wins[winner] += 1
	print(str(winner) + " has won " + str(wins[winner]) + " time(s)")
	if one_left():
		if multiplayer.is_server():
			rpc("enter_picking_time", winner)
	
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

func respawn_all():
	pass

func _get_spawn_position(i: int, num_playing:int) -> Vector2: 
	var result:=Vector2(100 + (i * 1700), 0)
	print(result.x)
	print("i = " + str(i))
	if num_playing == 2:
		result.y = 480
	if num_playing == 3 or num_playing == 4:
		result.y = 320 + (320 if i >= 3 else 0)
	
	return result

@rpc("reliable", "call_local")
func enter_picking_time(id) -> void:
	print("pick world,,, for " + str(id))
	if multiplayer.is_server():
		$Networking.sync_game_state = PlayState.State.PICKING
	hide_all_players()
	$PickingTime.visible = true
	for n in 3:
		var button = choice_button.instantiate()
		button.name = str(n)
		$PickingTime/HBoxContainer.add_child(button)
		button.set_picker(id)

func hide_all_players() -> void:
	modify_player_visibility(false)

func unhide_all_players() -> void:
	modify_player_visibility(true)
	
func modify_player_visibility(value) -> void:
	for player in alive.keys():
		player_nodes[player].visible = value
