extends Node2D

var host_player = null 
var host_id
var alive := {}
var wins := {}
var round_wins := {}
var player_nodes := {}
var already_got_host_win := false

const ROUNDS_PER_GAME := 5
const WINS_PER_ROUND := 2

const OBSTACLE_BUFFER := 100

const OBSTACLE_MAX_X := 1920 - OBSTACLE_BUFFER
const OBSTACLE_MAX_Y := 1080 - OBSTACLE_BUFFER

var choice_button = preload("res://Items/upgrade_choice.tscn")

var buttons = [preload("res://Items/Upgrades/Tank/choice.tscn"),
				preload("res://Items/Upgrades/Shotgun/choice.tscn"),
				preload("res://Items/Upgrades/BouncyBullets/choice.tscn"),
				preload("res://Items/Upgrades/TripleBurst/choice.tscn"),
				preload("res://Items/Upgrades/360NoScope/choice.tscn"),
				preload("res://Items/Upgrades/BulletSpeed/choice.tscn"),
				preload("res://Items/Upgrades/Teleporter/choice.tscn"),
				preload("res://Items/Upgrades/NarrowFocus/choice.tscn"),
				preload("res://Items/Upgrades/BiggoBullets/choice.tscn"),
				preload("res://Items/Upgrades/Shield/choice.tscn"),
				preload("res://Items/Upgrades/Berserker/choice.tscn"),
				preload("res://Items/Upgrades/QuickRoll/choice.tscn"),
				preload("res://Items/Upgrades/QuickReload/choice.tscn"),
				preload("res://Items/Upgrades/DizzyTurtle/choice.tscn"),
				preload("res://Items/Upgrades/AngryTurtle/choice.tscn")]

var powers = [load("res://Items/Upgrades/Tank/power.tscn"), 
				load("res://Items/Upgrades/Shotgun/power.tscn"),
				load("res://Items/Upgrades/BouncyBullets/power.tscn"),
				load("res://Items/Upgrades/TripleBurst/power.tscn"),
				load("res://Items/Upgrades/360NoScope/power.tscn"),
				load("res://Items/Upgrades/BulletSpeed/power.tscn"),
				load("res://Items/Upgrades/Teleporter/power.tscn"),
				load("res://Items/Upgrades/NarrowFocus/power.tscn"),
				load("res://Items/Upgrades/BiggoBullets/power.tscn"),
				load("res://Items/Upgrades/Shield/power.tscn"),
				load("res://Items/Upgrades/Berserker/power.tscn"),
				load("res://Items/Upgrades/QuickRoll/power.tscn"),
				load("res://Items/Upgrades/QuickReload/power.tscn"),
				load("res://Items/Upgrades/DizzyTurtle/power.tscn"),
				load("res://Items/Upgrades/AngryTurtle/power.tscn")] #TODO - load the power node when choice is displayed

var obstacles = [preload("res://Items/Obstacles/haystack.tscn")]

const AVOID_AFTER := {
	0: [],
	1: [1],
	2: [],
	3: [3],
	4: [4],
	5: [],
	6: [6],
	7: [],
	8: [],
	9: [9, 13, 14],
	10: [10],
	11: [],
	12: [],
	13: [9, 13],
	14: [9, 14]
}

func _ready():
	print("Level ready")
	host_id = multiplayer.get_unique_id()
	host_player = create_player(host_id)
	var peers = multiplayer.get_peers()
	if multiplayer.is_server(): generate_level()
	for peer in peers:
		print("peer found: " + str(peer))
		create_player(peer)
	# Listen to peer disconnections, and destroy their players
	multiplayer.peer_disconnected.connect(self.destroy_player)
	$WinnerDisplayTimer.timeout.connect(func hide_winner_display(): if multiplayer.is_server(): rpc("hide_winner"))

@rpc("reliable", "call_local")
func hide_winner():
	$WinnerDisplay.visible = false

func create_player(id):
	var player = preload("res://Characters/Player.tscn").instantiate()
	var memory_node = %PlayerData.get_node("Players")
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
				print("about to set name to " + str(new_name))
				print("new_name contains char(31): " + str(new_name.contains(char(31))))
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
			#get_tree().change_scene_to_file("res://System/readyup.tscn")
		round_wins[winner] += 1
		if round_wins[winner] == WINS_PER_ROUND:
			if wins[winner] >= ROUNDS_PER_GAME:
				print("Big winner!")
				rpc("_back_to_menu")
			wins[winner] = wins[winner] + 1
			var exclusions := get_exclusions_for(id)
			print("found exclusions: " + str(exclusions))
			var random_indices = choose_random_unique_indices(3, buttons.size(), exclusions)
			random_indices[0] = buttons.size() - 1 # debug - make sure the newest power shows up
			rpc("enter_picking_time", id, random_indices)
		else:
			print("respawning_all")
			if multiplayer.is_server: rpc("update_winner", get_node(str(winner)).player_name)
			rpc("respawn_all_rpc")
			generate_level()
			
@rpc("call_local", "reliable")
func update_winner(new_winner):
	$WinnerDisplay.text = new_winner
	$WinnerDisplay.visible = true

@rpc("call_local", "any_peer")
func _back_to_menu():
	get_tree().change_scene_to_file("res://System/main_menu.tscn")
	var level = get_node("/root/Level")
	var menu = get_node("/root/main_menu")
	level.set_visible(false)
	level.set_process(false)
	level.call_deferred("queue_free")
	menu.set_visible(true)

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

func get_all_matching(_map, value) -> Array:
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
		
func choose_random_unique_indices(n:int, max_index:int, exclusions:Array) -> Array:
	var result = {}
	while result.keys().size() < n:
		var entry = randi() % max_index
		if not result.has(entry) and not exclusions.has(entry):
			result[entry] = true
	return result.keys()
	
func choose_random_indices(n:int, max_index:int) -> Array:
	var result = []
	while result.size() < n:
		var entry = randi() % max_index
		result.push_back(entry)
	return result
		
func card_picked(card_id, player_id) -> void:
	print("Nice pick of " + str(card_id) +  " for " + str(player_id))
	rpc("inform_peers", card_id, player_id)
	rpc("exit_picking_time")
	
@rpc("reliable", "call_local", "any_peer")
func inform_peers(card_id, player_id):
	player_nodes[player_id].get_node("Powers").add_child(powers[card_id].instantiate())

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
	if multiplayer.is_server(): generate_level()

func hide_all_players() -> void:
	modify_player_visibility(false)

func unhide_all_players() -> void:
	modify_player_visibility(true)
	
func modify_player_visibility(value) -> void:
	for player in alive.keys():
		player_nodes[player].visible = value
		player_nodes[player].set_process(value)
		
func reset_players() -> void:
	remove_all_bullets()
	for player in alive.keys():
		alive[player] = true
		print("Resetting " + str(player))
		player_nodes[player].reset()

func remove_all_bullets() -> void:
	for node in $SpawnRoot.get_children():
		if not node is MultiplayerSpawner:
			node.call_deferred("free")


func generate_level() -> void:
	print("this is where i would generate a level")
	print("I might put them in these places:")
	var num_obstacles_on_each_side := 3
	var indices := choose_random_indices(num_obstacles_on_each_side, obstacles.size())
	for i in range(num_obstacles_on_each_side):
		for location in generate_symmetrical_object_coords():
			print(str(location))
			var placeholder = obstacles[indices[i]].instantiate()
			placeholder.position = location
			$SpawnRoot.add_child(placeholder, true)

func generate_symmetrical_object_coords() -> Array:
	var x := max(randi() % OBSTACLE_MAX_X, OBSTACLE_BUFFER)
	var y := max(randi() % OBSTACLE_MAX_Y, OBSTACLE_BUFFER)
	return [Vector2(x, y), Vector2(OBSTACLE_MAX_X - x, OBSTACLE_MAX_Y - y)]
	
func get_exclusions_for(id) -> Array:
	print("getting exclusions for " + str(id))
	var result := []
	var current_ids := get_player_power_ids(id)
	for power_id in current_ids:
		print("excluding " + str(power_id))
		var exclusions := AVOID_AFTER.get(power_id)
		result.append_array(exclusions)
	return result

func get_player_power_ids(player_id) -> Array:
	var result := []
	var player = player_nodes[player_id]
	var powers = player.get_node("Powers").get_children()
	for child in powers:
		result.append(child.card_id)

	return result
