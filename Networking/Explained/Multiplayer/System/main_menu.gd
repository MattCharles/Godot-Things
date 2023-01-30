extends Node

var room_code
var max_connect_time = 20 #if this time is exceeded when joining a game, a fail message is displayed
var is_host = false
var nickname
var own_port
var host_address
var host_port
var players_joined = 0
var num_players = 100
var player_name_field

const ROOM_CODE_LENGTH = 5

const PlayerScene = preload("res://Characters/Aliens/Player.tscn")
@onready var PlaceholderScene = preload("res://Characters/Poochys/Stander.tscn")
var GameScene = preload("res://Levels/Level1.tscn")

var player_positions
var player_names

func _ready():
	#multiplayer.peer_connected.connect(self._player_connected)
	player_positions = [$readyup.get_node("P1Position"), $readyup.get_node("P2Position"), $readyup.get_node("P3Position"), $readyup.get_node("P4Position")]
	player_name_field = $menu/Controls/PlayerNameContainer/LineEdit

#Handle player input

func _on_create_lobby_button_pressed():
	is_host=true
	connection_setup()
	var player_name = player_name_field.get_text() if player_name_field.get_text() != "" else "Poochy"
	$HolePunch.start_traversal("", true, player_name + str(randi()), player_name) #Attempt to connect to server as host
	$menu/Controls.visible = false
	$menu/Connecting.visible = true
	$readyup/Controls/PlayerNameValueLabel.text = player_name

func _on_join_lobby_button_pressed():
	var room_code = $menu/Controls/RoomCodeContainer/LineEdit.text.to_upper()
	room_code = room_code if room_code != "" else $menu/Controls/RoomCodeContainer/LineEdit.placeholder_text.to_upper()
	var player_name = player_name_field.get_text() if player_name_field.get_text() != "" else "Poochy"
	print(room_code)
	$readyup/Controls/PlayerNameValueLabel.text = player_name
	if room_code.length() == ROOM_CODE_LENGTH:
		is_host = false
		connection_setup()
		$HolePunch.start_traversal(room_code, false, player_name + str(randi()), player_name) #Attempt to connect to server as client
		print("Status: Connecting to session...")
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
	await get_tree().process_frame
	if $HolePunch.is_host:
		$ConnectTimer.start(1) #Waiting for port to become unused to start game
	else:
		$ConnectTimer.start(3) #Waiting for host to start game

func _on_HolePunch_update_lobby(nicknames, max_players):
	var lobby_message = "Lobby "+str(nicknames.size())+"/"+str(max_players)+"\n"
	var i = 0
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
	print("connection timer timeout")
	if $HolePunch.is_host:
		var net = ENetMultiplayerPeer.new() #Create regular godot peer to peer server
		net.create_server(own_port, 2) #You can follow regular godot networking tutorials to extend this
		multiplayer.set_multiplayer_peer(net)
		
	else:
		var net = ENetMultiplayerPeer.new() #Connect to host
		net.create_client(host_address, host_port, 0, 0, own_port)
		multiplayer.set_multiplayer_peer(net)
	get_tree().change_scene_to_file("res://Levels/Level1.tscn")

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
	pass

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


func create_player(id : int) -> void:
	# Instantiate a new player for this client.
	var p = PlayerScene.instantiate()

	# Set the name, so players can figure out their local authority
	p.name = str(id)
	
	$menu/Players.add_child(p)

func destroy_player(id : int) -> void:
	# Delete this peer's node.
	$menu/Players.get_node(str(id)).queue_free()
		
func _on_button_start_pressed():
	$HolePunch.finalize_peers()
	
