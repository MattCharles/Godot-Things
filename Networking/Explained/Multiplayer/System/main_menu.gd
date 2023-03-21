extends Node

var room_code
var max_connect_time = 5 #if this time is exceeded when joining a game, a fail message is displayed
var is_host = false
var nickname
var own_port
var host_address
var host_port
var players_joined = 0
var num_players = 100
var player_name_field

const ROOM_CODE_LENGTH = 5

const PlayerScene = preload("res://Characters/Player.tscn")
@onready var PlaceholderScene = preload("res://Characters/Poochys/Stander.tscn")
@onready var GameScene = preload("res://Levels/Level1.tscn").instantiate()
@onready var player_stuff = preload("res://System/memory.tscn").instantiate()

var player_positions

func _ready():
	player_positions = [$readyup.get_node("P1Position"), $readyup.get_node("P2Position"), $readyup.get_node("P3Position"), $readyup.get_node("P4Position")]
	player_name_field = $menu/Controls/PlayerNameContainer/LineEdit

#Handle player input

func _on_create_lobby_button_pressed(): #TODO: only letters
	is_host=true
	connection_setup()
	var player_name = player_name_field.get_text() if player_name_field.get_text() != "" else "Poochy"
	var id = player_name + str(multiplayer.get_unique_id())
	$HolePunch.start_traversal("", true, id, player_name) #Attempt to connect to server as host
	print(id + " joining")
	$menu/Controls.visible = false
	$menu/Connecting.visible = true
	$readyup/Controls/PlayerNameValueLabel.text = player_name
	$game_start.num_playing = 2

func _on_join_lobby_button_pressed(): #TODO: only letters
	var room_code = $menu/Controls/RoomCodeContainer/LineEdit.text.to_upper()
	room_code = room_code if room_code != "" else $menu/Controls/RoomCodeContainer/LineEdit.placeholder_text.to_upper()
	var player_name = player_name_field.get_text() if player_name_field.get_text() != "" else "Poochy"
	print(room_code)
	$readyup/Controls/PlayerNameValueLabel.text = player_name
	if room_code.length() == ROOM_CODE_LENGTH:
		is_host = false
		connection_setup()
		var id = player_name + str(randi())
		print(id + " joining")
		$HolePunch.start_traversal(room_code, false, id, player_name) #Attempt to connect to server as client
		print("Status: Connecting to session...")
		$menu/Connecting.visible = true
		$menu/Controls.visible = false
	else:
		print("Status: Invalid roomcode!")

func _on_ButtonCancel_pressed():
	if(is_host):
		$HolePunch.close_session()
	else:
		$HolePunch.client_disconnect()

func _on_ButtonStart_pressed():
	$HolePunch.finalize_peers()

#Handle holepunch messages

func _on_HolePunch_hole_punched(my_port, hosts_port, hosts_address, num_plyrs):
	print("ready to join: "+str(hosts_address)+":"+str(hosts_port)+" / "+str(my_port))
	own_port = my_port
	host_address = hosts_address
	host_port = hosts_port
	num_players = num_plyrs
	$menu/FailTimer.stop()
	print("Status: Connection successful")
	players_joined = 0
	GameState.ids.clear()
	await get_tree().process_frame
	
	player_stuff.contents = $HolePunch.peers
	player_stuff.contents[$HolePunch.client_name] = {"id": 1, "name": $HolePunch.client_name}
	player_stuff.name = "Players"
	GameScene.get_node("PlayerData").add_child(player_stuff)
	if $HolePunch.is_host:
		$ConnectTimer.start(1) #Waiting for port to become unused to start game
	else:
		$ConnectTimer.start(3) #Waiting for host to start game

func _on_HolePunch_update_lobby(nicknames, max_players):
	GameState.names.clear()
	var lobby_message = "Lobby "+str(nicknames.size())+"/"+str(max_players)+"\n"
	var i = 0
	GameState.names.append_array(nicknames)
	for nickname in nicknames:
		var placeholder = PlaceholderScene.instantiate()
		placeholder.nickname = nickname
		placeholder.set_position(player_positions[i].position)
		i += 1
		add_child(placeholder)
		lobby_message+=nickname+"\n"
	if nicknames.size()>1: #you're not alone!
		print("Status: Ready to play!")
		print(lobby_message)
	else:
		print("Status: Room open!")
		
func _on_connect_timer_timeout(): 
	$ConnectTimer.stop()
	if $HolePunch.is_host:
		var net = ENetMultiplayerPeer.new() #Create regular godot peer to peer server
		net.create_server(own_port, 2) #You can follow regular godot networking tutorials to extend this
		multiplayer.set_multiplayer_peer(net)
		multiplayer.peer_connected.connect(self._update_counter)
		$game_start.start_game.connect(self._load_level)
	else:
		$game_start.start_game.connect(self._load_level)
		var net = ENetMultiplayerPeer.new() #Connect to host
		net.create_client(host_address, host_port, 0, 0, own_port)
		multiplayer.set_multiplayer_peer(net)

func _load_level():
	rpc("_load_fr")
	
@rpc("call_local", "any_peer")
func _load_fr():
	var root = get_node("/root/")
	var now = get_node("/root/main_menu")
	root.remove_child(now)
	now.call_deferred("free")
	root.add_child(GameScene)

func _update_counter(id):
	if $HolePunch.is_host:
		var this_player = player_stuff.contents.keys()[$game_start.num_connected-1]
		player_stuff.contents[this_player]["id"] = id
		$game_start.num_connected = $game_start.num_connected + 1

func _on_HolePunch_session_registered():
	print("Status: Room open!")
	$menu/FailTimer.stop() #server responded!

func _on_HolePunch_return_unsuccessful(message):
	print(message)
	reinit()
	
func _on_HolePunch_return_room_code(_room_code):
	print("Room code received! " + _room_code)
	$menu.visible = false
	$readyup.visible = true
	
	GameState.room_code = _room_code
	$readyup/Controls/RoomCodeLabel.text = "Room Code: " + GameState.room_code

func _on_fail_timer_timeout():
	print("Status: Connection timed out!")
	reinit()

#Utility/UI

func reinit():
	$menu/FailTimer.stop()
	$menu/Controls.visible = true
	$menu/Connecting.visible = false
	$menu/Title.text = "Failed to Connect"

func connection_setup():
	$menu/FailTimer.start(max_connect_time)
	nickname = player_name_field.text
	if nickname == "":
		nickname = "Player"
		
func _on_button_start_pressed():
	$HolePunch.finalize_peers()
	
