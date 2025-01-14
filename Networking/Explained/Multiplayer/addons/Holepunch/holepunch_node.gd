extends Node

# General structure overview:

# Game calls start_traversal, initializing variables (starting session if hosting).
# if host client is registered after receiving ok from server in _process, otherwise it's done immediately
# _process later receives peer info, when peer max reached, or when ended early through finalize_peers
# start_peer_contact is called, server connection is closed
# _ping_peer loop is started, in which peers share port and readiness information
# eventually, peers agree to connect, sending connection info back to game through 'hole_punched' signal
# if connection cannot be made for any reason, 'return unsuccessful' signal is sent so game can reset UI

#Signal is emitted when holepunch is complete. Connect this signal to your network manager
#Once your network manager received the signal they can host or join a game on the host port
signal hole_punched(my_port, hosts_port, hosts_address)

#This signal is emitted when the server has acknowledged your client registration, but before the
#address and port of the other client have arrived.
signal session_registered

#Sends names of players as they join/leave
signal update_lobby(nicknames,max_players)

#Relay that connection was unsuccessful.
#The reason for failure will be stored in message.
#Setup your game to return to initial connection UI, and report fail reason for user feedback. 
signal return_unsuccessful(message) 

#Get the room code from the server
signal return_room_code(room_code)

var server_udp = PacketPeerUDP.new()
var peer_udp = PacketPeerUDP.new()

#Set the rendevouz address to the IP address of your third party server
@export var rendevouz_address:String = "" 
#Set the rendevouz port to the port of your third party server
@export var rendevouz_port:int = 4000
#This is the range of ports you will search if you hear no response from the first port tried
@export var port_cascade_range:int = 10
#The amount of messages of the same type you will send before cascading or giving up
@export var response_window:int = 150
#max session size
@export var MAX_PLAYER_COUNT:int = 2
#dev testing mode! this will override your peers ip with 'localhost' to test on your own machine.
@export var local_testing:bool = false

var found_server = false
var recieved_peer_info = false
var recieved_peer_greets = false
var recieved_peer_confirms = false

var is_host = false

var own_port
var peers = {}
var peer_stages = {}
# [peer.address] = 0,1,2
	# 0 = no contact
	# 1 = received greet
	# 2 = received confirm
var host_address = ""
var host_port = 0
var client_name
var nickname #appearance only
var p_timer #ping timer, for communicating with peers
var room_code

var ping_cycles = 0 #how many times peers have pinged eachother

const REGISTER_SESSION = "rs"
const REGISTER_CLIENT = "rc"
const CLOSE_SESSION = "cs" #message from host client to preemptively end session
const EXCHANGE_PEERS = "ep" #client message to exchange peer info early
const CHECKOUT_CLIENT = "cc"
const PEER_GREET = "greet"
const PEER_CONFIRM = "confirm"
const HOST_GO = "go"
const SERVER_OK = "ok"
const SERVER_LOBBY = "lobby" #lobby info, sends list of playernames
const SERVER_INFO = "peers"
const SERVER_CLOSE = "close" #message from server that you failed to connect, or got disconnected. like host closed lobby or lobby full

const DELIMITER = char(31) # Unit Separator control character

#handle incoming messages
func _process(delta):
	#handle peer messages
	if peer_udp.get_available_packet_count() > 0:
		var array_bytes = peer_udp.get_packet()
		var packet_string = array_bytes.get_string_from_utf8()
		if packet_string.begins_with(PEER_GREET):
			print("< peer greet!")
			print("packet_string: " + packet_string)
			var m = packet_string.split(DELIMITER)
			_handle_greet_message(m[1], m[2].to_int())
		elif packet_string.begins_with(PEER_CONFIRM):
			print("< peer confirm!")
			var m = packet_string.split(DELIMITER)
			_handle_confirm_message(m[1], m[2].to_int())
		elif packet_string.begins_with(HOST_GO):
			print("< host go!")
			var m = packet_string.split(DELIMITER)
			_handle_go_message(m[1], m[2].to_int())
		else:
			print("string: " + packet_string)
			print("< unrecognized peer message!")

	#handle server messages
	if server_udp.get_available_packet_count() > 0:
		var array_bytes = server_udp.get_packet()
		var packet_string = array_bytes.get_string_from_utf8()
		if packet_string.begins_with(SERVER_LOBBY):
			var m = packet_string.split(DELIMITER)
			emit_signal('update_lobby',m[1].split(","),m[2])
		if packet_string.begins_with(SERVER_CLOSE):
			var m = packet_string.split(DELIMITER)
			handle_failure("Disconnected: "+m[1])
			return
		if packet_string.begins_with(SERVER_OK):
			print(packet_string)
			var m = packet_string.split(DELIMITER)
			own_port = m[1].to_int()
			room_code = m[2]
			print("This client is listening on port: ",own_port)
			print("Room Code: ", room_code)
			emit_signal('session_registered')
			emit_signal('return_room_code', room_code)
			if is_host:
				if !found_server:
					_send_client_to_server() #register host to session (other peers are done in start_traversal)
			found_server=true
			

		if not recieved_peer_info:
			if packet_string.begins_with(SERVER_INFO):
				server_udp.close()
				print("packet_string" + packet_string)
				packet_string = packet_string.right(-6) #after 'peers:'
				if packet_string.length() > 2:
					print("player info: " + packet_string)
					var clientdata = packet_string.split(",") #this is formatted client:ip:port,client2:ip:port
					for c in clientdata:
						var m = c.split(DELIMITER)
						if m[3] == "True":
							host_address = m[1]
						peers[m[0]] = {"port":m[2], "address":("localhost" if local_testing else m[1]),"hosting":(m[3]=="True"),"name":m[0]}
					recieved_peer_info = true
					start_peer_contact()
				else:
					#apparently no peers were sent, host probably began without others.
					handle_failure("No peers found.") #report to game to handle accordingly

#receive peer info, reset their port if you had it wrong
func _handle_greet_message(peer_name, peer_port):
	print("handling greet message from " + str(peer_name) + str(peer_port))
	if not peer_name in peer_stages:
		peer_stages[peer_name] = 0
	if peer_stages[peer_name] == 0: peer_stages[peer_name] = 1
	peers[peer_name].port = peer_port if typeof(peer_port) == TYPE_INT else peer_port.to_int()
	if peers[peer_name].hosting:
		host_port=peer_port
		host_address=peers[peer_name].address

#message that a peer has received all other peer's info
func _handle_confirm_message(peer_name, peer_port):
	if not peer_name in peer_stages:
		peer_stages[peer_name] = 0
	peer_stages[peer_name] = 2

#message from host to start connection
func _handle_go_message(peer_name,peer_port):
	peer_stages[peer_name] = 2
	if peers[peer_name].hosting:
		emit_signal("hole_punched", int(own_port), host_port, host_address, peers.size())
		peer_udp.close()
		p_timer.stop()
		set_process(false)

#search for working ports, send greetings accordingly
func _cascade_peer(peer_address, peer_port):
	for i in range(int(peer_port) - port_cascade_range, int(peer_port) + port_cascade_range):
		peer_udp.set_dest_address(peer_address, i)
		var buffer = PackedByteArray()
		buffer.append_array((PEER_GREET + DELIMITER + client_name + DELIMITER + str(own_port)).to_utf8_buffer()) #tell peer about your new port
		peer_udp.put_packet(buffer)

#contact other peers, repeatedly called by p_timer, started in start_peer_contact

#structure:
#greet: telling peers what port you are listening on, making them reconfigure if they had it wrong
#confirm: telling peers that you've received *all other peer's* info, and are waiting for other peers to do the same
#go: initiated by host when all peers have confirmed, tells peers to start peer to peer connection
func _ping_peer():
	var all_info = true
	var all_confirm = true
	for p in peers.keys():
		var peer = peers[p]
		if not peer.name in peer_stages:
			peer_stages[peer.name] = 0
		var stage = peer_stages[peer.name]
		if stage < 1: all_info = false
		if stage < 2: all_confirm = false
		if stage == 0: #received no contact, send greet
			print(str(peer.address) + " " + str(peer.port) + " ")
			# When running tests on localhost, sometimes the host pings itself forever looking for the client.
			# Use randomness to give it an out
			if ping_cycles >= response_window or (randi() % 5 == 0 and str(peer.port) == str(own_port)):
				_cascade_peer(peer.address, peer.port)
			else:
				print("> send greet!")
				peer_udp.set_dest_address(peer.address, peer.port if typeof(peer.port) == TYPE_INT else peer.port.to_int())
				var buffer = PackedByteArray()
				buffer.append_array((PEER_GREET + DELIMITER + client_name + DELIMITER + str(own_port)).to_utf8_buffer())
				print("sending message: " + buffer.get_string_from_utf8())
				peer_udp.put_packet(buffer)
		if stage == 1 and recieved_peer_greets:
			print("> send confirm!")
			peer_udp.set_dest_address(peer.address, peer.port)
			var buffer = PackedByteArray()
			buffer.append_array((PEER_CONFIRM + DELIMITER + client_name + DELIMITER + str(own_port)).to_utf8_buffer())
			peer_udp.put_packet(buffer)
		#initiate fail if peer can't connect to you (stage 0), or hasn't connected to all other peers (stage 1)
		#in this case, all peers should have atleast one unsuccessful connection, and we will throw an error to the game
		if stage < 2 and ping_cycles >= (response_window*2):
			handle_failure("Not all peers were able to connect through peer-to-peer! If this continues, consider port-forwarding as a fallback option.")
	if all_info:
		recieved_peer_greets = true
	if all_confirm:
		recieved_peer_confirms = true
		if is_host:
			for p in peers.keys():
				var peer = peers[p]
				print("> send go!")
				peer_udp.set_dest_address(peer.address, peer.port if typeof(peer.port) == TYPE_INT else peer.port.to_int())
				var buffer = PackedByteArray()
				buffer.append_array((HOST_GO + DELIMITER +client_name+DELIMITER+str(own_port)).to_utf8_buffer())
				peer_udp.put_packet(buffer)
			emit_signal("hole_punched", own_port if typeof(own_port) == TYPE_INT else own_port.to_int(), host_port, host_address, peers.size())
			peer_udp.close()
			p_timer.stop()
			set_process(false)
	ping_cycles+=1

#initiate _ping_peer loop, disconnect from server
func start_peer_contact():	
	print("starting peer contact")
	server_udp.put_packet("goodbye".to_utf8_buffer()) #this might not always get called because the server_udp is already closed before this. seems to be true from testing.
	server_udp.close()
	if peer_udp.is_socket_connected():
		peer_udp.close()
	var err = peer_udp.bind(own_port, "*")
	if err != OK:
		handle_failure("Error listening on port: " + str(own_port) +", " + str(err))
		return
	p_timer.start() #repeatedly calls _ping_peer

#this function can be called to the server if you want to end the holepunch before the server closes the session
func finalize_peers():
	var buffer = PackedByteArray()
	buffer.append_array((EXCHANGE_PEERS + DELIMITER + str(room_code)).to_utf8_buffer())
	server_udp.set_dest_address(rendevouz_address, rendevouz_port)
	server_udp.put_packet(buffer)

#removes a client from the server
func checkout():
	var buffer = PackedByteArray()
	buffer.append_array((CHECKOUT_CLIENT + DELIMITER +client_name).to_utf8_buffer())
	server_udp.set_dest_address(rendevouz_address, rendevouz_port)
	server_udp.put_packet(buffer)

#call this function when you want to start the holepunch process
func start_traversal(room_id, is_player_host, player_name, player_nickname):
	if server_udp.is_socket_connected():
		server_udp.close()

	var err = server_udp.bind(rendevouz_port, "*")
	if err != OK:
		handle_failure("Error listening on port: " + str(rendevouz_port) + " to server: " + rendevouz_address)
		return

	set_process(true)

	is_host = is_player_host
	client_name = player_name
	nickname = player_nickname
	found_server = false
	recieved_peer_info = false
	recieved_peer_greets = false
	recieved_peer_confirms = false
	peers = {}
	peer_stages = {}

	ping_cycles = 0
	room_code = room_id
	
	if (is_host):
		var buffer = PackedByteArray()
		buffer.append_array((REGISTER_SESSION+DELIMITER+str(MAX_PLAYER_COUNT)).to_utf8_buffer())
		server_udp.set_dest_address(rendevouz_address, rendevouz_port)
		server_udp.put_packet(buffer)
		#host gets added to session after an ok, in _process
	else:
		print("sessionID: " + room_code)
		_send_client_to_server()

#register a client with the server
func _send_client_to_server():
	await get_tree().create_timer(0.5).timeout #resume upon timeout of 2 second timer; aka wait 2s
	var buffer = PackedByteArray()
	print("registering client " + str(client_name))
	print("nickname " + str(nickname))
	buffer.append_array((REGISTER_CLIENT + DELIMITER + client_name + DELIMITER + room_code + DELIMITER + nickname).to_utf8_buffer())
	server_udp.close()
	server_udp.set_dest_address(rendevouz_address, rendevouz_port)
	server_udp.put_packet(buffer)

#close server connection on deletion
func _exit_tree():
	server_udp.close()

#reports connection failure, and stops all connections
func handle_failure(message):
	print("Holepunch unsuccessful, stopping processes!")
	if is_host and server_udp.is_socket_connected() and found_server: #shutdown session if possible
		var buffer = PackedByteArray()
		buffer.append_array((CLOSE_SESSION + DELIMITER +str(room_code)+DELIMITER+message).to_utf8_buffer())
		server_udp.put_packet(buffer)
	else:
		checkout() #remove client from session if not
	p_timer.stop()
	server_udp.close()
	peer_udp.close()
	emit_signal("return_unsuccessful",message)

#call this from non-host client to disconnect from a session
func client_disconnect():
	handle_failure("Client disconnected.")

#call this from host client to forcefully close a session
func close_session():
	handle_failure("Host preemptively closed session!")

#initialize timer
func _ready():
	p_timer = Timer.new()
	get_node("/root/").call_deferred("add_child", p_timer)
	p_timer.timeout.connect(self._ping_peer)
	p_timer.wait_time = 0.1
