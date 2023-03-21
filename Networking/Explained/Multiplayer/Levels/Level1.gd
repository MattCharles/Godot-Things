extends Node2D

var host_player = null 
var host_id
var alive := {}
var wins := {}
var round_wins := {}
var player_nodes := {}
var already_got_host_win := false

var choice_button = preload("res://Items/upgrade_choice.tscn")

var buttons = [preload("res://Items/Upgrades/Tank/choice.tscn"),
				preload("res://Items/Upgrades/Shotgun/choice.tscn"),
				preload("res://Items/Upgrades/BouncyBullets/choice.tscn"),
				preload("res://Items/Upgrades/TripleBurst/choice.tscn"),
				preload("res://Items/Upgrades/360NoScope/choice.tscn"),
				preload("res://Items/Upgrades/BulletSpeed/choice.tscn"),
				preload("res://Items/Upgrades/Teleporter/choice.tscn")]

var powers = [load("res://Items/Upgrades/Tank/power.tscn"), 
				load("res://Items/Upgrades/Shotgun/power.tscn"),
				load("res://Items/Upgrades/BouncyBullets/power.tscn"),
				load("res://Items/Upgrades/TripleBurst/power.tscn"),
				load("res://Items/Upgrades/360NoScope/power.tscn"),
				load("res://Items/Upgrades/BulletSpeed/power.tscn"),
				load("res://Items/Upgrades/Teleporter/power.tscn")] #TODO - load the power node when choice is displayed

func _ready():
	host_id = multiplayer.get_unique_id()
	host_player = create_player(host_id)
	var peers = multiplayer.get_peers()
	for peer in peers:
		print("peer found: " + str(peer))
		create_player(peer)
	# Listen to peer disconnections, and destroy their players
	multiplayer.peer_disconnected.connect(self.destroy_player)
	$WinnerDisplayTimer.timeout.connect(func hide_winner(): $WinnerDisplay.visible = false)

func create_player(id):
	var player = preload("res://Characters/Player.tscn").instantiate()
	var memory_node = $PlayerData.get_node("Players")
	player.name = str(id)
	add_child(player)
	if multiplayer.is_server():
		var initial_position = _get_spawn_position($Networking.sync_num_connected, 2)
		player.rpc("remote_dictate_position", initial_position) # TODO: support multiplayer games
		player.initial_position = initial_position
		$Networking.sync_num_connected = $Networking.sync_num_connected + 1
		round_wins[id] = 0
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
	print(str(winner) + " has won " + str(wins[winner]) + " time(s)")
	if multiplayer.is_server() and one_left() and not already_got_host_win:
		if winner == 1: already_got_host_win = true
		print("already_got_host_win" + str(already_got_host_win))
		if wins[winner] >= 3:
			print("Big winner!")
			#get_tree().change_scene_to_file("res://System/readyup.tscn")
		round_wins[winner] += 1
		if round_wins[winner] == 2:
			wins[winner] = wins[winner] + 1
			rpc("enter_picking_time", id, choose_random_indices(3, buttons.size()))
		else:
			print("respawning_all")
			$WinnerDisplay.text = get_node(str(winner)).player_name
			$WinnerDisplay.visible = true
			rpc("respawn_all_rpc")
			
	
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

@rpc("call_local", "reliable")
func respawn_all_rpc():
	respawn_all()

func respawn_all():
	already_got_host_win = false
	reset_players()
	unhide_all_players()

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
func enter_picking_time(picker_id:int, cards:Array) -> void:
	remove_all_bullets()
	if multiplayer.is_server():
		$Networking.sync_game_state = PlayState.State.PICKING
	hide_all_players()
	$PickingTime.visible = true
	add_buttons(picker_id, cards)
	already_got_host_win = false
	
func add_buttons(picker_id:int, entries:Array):
	for i in 3:
		var button = buttons[entries[i]].instantiate()
		button.name = str(i)
		$PickingTime/HBoxContainer.add_child(button)
		button.set_picker(picker_id)
		button.picked.connect(card_picked)
		
func choose_random_indices(n:int, max:int) -> Array:
	var result = {}
	while result.keys().size() < n:
		var entry = randi() % max
		if not result.has(entry):
			result[entry] = true
	return result.keys()
		
func card_picked(card_id, player_id) -> void:
	print("Nice pick of " + str(card_id) +  " for " + str(player_id))
	player_nodes[player_id].get_node("Powers").add_child(powers[card_id].instantiate())
	rpc("exit_picking_time")

@rpc("reliable", "call_local", "any_peer") #TODO: security here
func exit_picking_time() -> void:
	for choice in $PickingTime/HBoxContainer.get_children():
		$PickingTime/HBoxContainer.remove_child(choice)
		choice.queue_free()
	$PickingTime.visible = false
	for i in round_wins.keys():
		round_wins[i] = 0
	unhide_all_players()
	reset_players()

func hide_all_players() -> void:
	modify_player_visibility(false)

func unhide_all_players() -> void:
	modify_player_visibility(true)
	
func modify_player_visibility(value) -> void:
	for player in alive.keys():
		player_nodes[player].visible = value
		player_nodes[player].set_process(value)
		
func reset_players() -> void:
	for player in alive.keys():
		alive[player] = true
		print("Resetting " + str(player))
		player_nodes[player].reset()

func remove_all_bullets() -> void:
	for node in $SpawnRoot.get_children():
		if not node is MultiplayerSpawner:
			node.call_deferred("free")
