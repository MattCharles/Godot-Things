extends CharacterBody2D
class_name Player

const DEFAULT_SPEED = 400
const DEFAULT_ROLL_SPEED = 700
const DEFAULT_HEALTH = 100
const DISTANCE_FROM_CENTER_TO_HAND = 55
const DEFAULT_SCALE = Vector2(1, 1)
const DEFAULT_SPREAD = 10 # Measured in degrees, in either direction
const DEFAULT_BULLETS_PER_SHOT = 1 # I clicked shoot. How many bullets come out at once?
const DEFAULT_BULLET = preload("res://Items/default_bullet.tscn")
const DEFAULT_BULLET_SCALE = 1.0
const DEFAULT_BULLET_DAMAGE = 35
const ORDERED_OPERATIONS = ["add", "multiply"]

signal i_die(id: int)

@onready var _animated_sprite = $AnimatedSprite2D
@onready var shoot_point = $Hand/ShootPoint

# animation names
var walk = "Walk" 
var default = "default"
var roll = "Roll"

var shot_cooldown
var roll_time = 0.5
var player_bullet := DEFAULT_BULLET
var health := DEFAULT_HEALTH
var max_health := DEFAULT_HEALTH
var speed := DEFAULT_SPEED
var roll_speed := DEFAULT_ROLL_SPEED
var move_state := Movement.states.MOVE
var roll_vector := Vector2.DOWN
var player_name := "Poochy"
var dead := false
var spread := DEFAULT_SPREAD
var bullets_per_shot := DEFAULT_BULLETS_PER_SHOT
var bullet_scale := DEFAULT_BULLET_SCALE
var bullet_damage := DEFAULT_BULLET_DAMAGE

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready():
	# int constructor taking a string is currently broken :(
	# https://github.com/godotengine/godot/issues/44407
	# https://github.com/godotengine/godot/issues/55284
	$Networking/MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())

	$Networking.sync_health = health
	$UI/TextureProgressBar.value = health
	$Networking.sync_max_health = max_health
	$UI.visible = true
	if is_local_authority():
		$Networking.sync_player_name = player_name
	else:
		player_name = $Networking.sync_player_name
	$UI/PlayerNameLabel.text = player_name
	

func _process(_delta):
	if is_local_authority():
		$Hand.position = get_hand_position()
		$Hand.look_at(self.get_global_mouse_position())
		$Hand/Sprite2d.flip_v = $Hand.global_position.x < self.global_position.x
		$Networking.sync_hand_flip = $Hand/Sprite2d.flip_v
		$Networking.sync_hand_rotation = $Hand.rotation
		_animated_sprite.flip_h = $Hand/Sprite2d.flip_v
		$Networking.sync_flip_sprite = _animated_sprite.flip_h
		if Input.is_action_just_pressed("shoot"):
			for bullet_count in bullets_per_shot:
				var distant_target = get_distant_target()
				var bullet_angle = random_angle(spread)
				var target = distant_target.rotated(bullet_angle)
				rpc("process_shot", multiplayer.get_unique_id(), self.get_global_mouse_position(), target)
	else:
		health = $Networking.sync_health
		max_health = $Networking.sync_max_health
		if not $Networking.processed_hand_position:
			$Hand.position = $Networking.sync_hand_position
			$Networking.processed_hand_position = true
		$Hand.rotation = $Networking.sync_hand_rotation
		$Hand/Sprite2d.flip_v = $Networking.sync_hand_flip
		_animated_sprite.flip_h = $Networking.sync_flip_sprite
		move_state = $Networking.sync_move_state
				
	$UI/TextureProgressBar.value = health
	$UI/TextureProgressBar.max_value = max_health
	$UI/TextureProgressBar.visible = health < max_health
	$Networking.sync_hand_rotation = $Hand.rotation
	$Networking.sync_hand_position = $Hand.position
		

func _physics_process(delta):
	if health <= 0 and not dead:
		die()
	match move_state:
		Movement.states.MOVE:
			process_move(delta)
		Movement.states.ROLL:
			process_roll(delta)
			
func process_move(delta) -> void:
	if !is_local_authority(): # this is somebody else's player character
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
		velocity = $Networking.sync_velocity
		#move_state = $Networking.sync_move_state
		if velocity.x != 0 or velocity.y != 0:
			_animated_sprite.play(walk)
		else:
			_animated_sprite.play(default)
		move_and_slide()
		return

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var x_direction = Input.get_axis("move_left", "move_right")
	var y_direction = Input.get_axis("move_up", "move_down")
	
	if x_direction:
		velocity.x = x_direction * speed
		_animated_sprite.play(walk)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	if y_direction:
		velocity.y = y_direction * speed
		_animated_sprite.play(walk)
	else:
		velocity.y = move_toward(velocity.y, 0, speed)
		
	if not x_direction and not y_direction:
		_animated_sprite.play(default)
		
	# Move locally
	move_and_slide()
	
	if Input.is_action_just_pressed("roll"):
		roll_vector = Vector2(x_direction, y_direction).normalized()
		move_state = Movement.states.ROLL
		$Networking.sync_move_state = Movement.states.ROLL
		await get_tree().create_timer(roll_time).timeout
		rpc("roll_finished")
		
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
	

func process_roll(delta) -> void:
	_animated_sprite.play(roll)
	if !is_local_authority(): # this is somebody else's player character
		$CollisionShape2D.set_deferred("disabled", !$Networking.sync_collidable)
		print("Starting roll for " + str($Networking/MultiplayerSynchronizer.get_multiplayer_authority()) + ": collidable status = " + str($Networking.sync_collidable))
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
		velocity = $Networking.sync_velocity
		move_and_slide()
		return
	$Networking.sync_collidable = false
	$CollisionShape2D.set_deferred("disabled", !$Networking.sync_collidable)
	
	velocity = roll_vector * roll_speed
	move_and_slide()
	
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity

@rpc("reliable", "any_peer", "call_local")
func roll_finished() -> void:
	$Networking.sync_collidable = true
	$CollisionShape2D.set_deferred("disabled", !$Networking.sync_collidable)
	$Networking.sync_move_state = Movement.states.MOVE
	move_state = Movement.states.MOVE
	
func get_hand_position() -> Vector2:
	var target = self.get_global_mouse_position()
	var source = self.position
	var result = DISTANCE_FROM_CENTER_TO_HAND * ( target - source ).normalized()
	return result
	
func get_hand_rotation() -> float:
	var target = self.get_global_mouse_position()
	var source = self.position
	return source.angle_to(target)

func get_distant_target() -> Vector2:
	var hand_position = get_hand_position()
	return 12345 * hand_position
	
func change_name(_new_name):
	print("Setting name to " + _new_name)
	rpc("remote_change_name", _new_name)
	
func damage(amount):
	if multiplayer.is_server():
		rpc("take_damage", amount)

@rpc("any_peer", "call_local", "reliable")
func process_shot(id, look_at, distant_target):
	var instance = player_bullet.instantiate()
	instance.name = str(randi())
	get_node("/root/Level/SpawnRoot").add_child(instance, true)
	instance.scale = instance.scale * bullet_scale # scale is a vector 2
	instance.target = distant_target
	instance.damage = bullet_damage
	instance.look_at(look_at)
	instance.global_position = shoot_point.global_position

@rpc("call_local", "reliable")
func take_damage(amount):
	print(health)
	health = health - amount
	$Networking.sync_health = health

func die():
	if !multiplayer.is_server():
		dead = $Networking.sync_dead
		return
	print("die from player")
	dead = true
	$Networking.sync_dead = true
	emit_signal("i_die", $Networking/MultiplayerSynchronizer.get_multiplayer_authority())
	
func reset():
	# First, set everything to defaults.
	roll_time = 0.5
	health = DEFAULT_HEALTH
	max_health = DEFAULT_HEALTH
	speed = DEFAULT_SPEED
	roll_speed = DEFAULT_ROLL_SPEED
	scale = DEFAULT_SCALE
	bullets_per_shot = DEFAULT_BULLETS_PER_SHOT
	bullet_scale = DEFAULT_BULLET_SCALE
	
	modify()
	health = max_health
	# Finally, some stuff will want to go over the network explicitly.
	if is_local_authority():
		rpc("set_bullets_per_shot", bullets_per_shot)
		rpc("set_bullet_scale", bullet_scale)
		rpc("set_bullet_damage", bullet_damage)
	$Networking.sync_bullet_scale = bullet_scale
	$Networking.sync_bullets_per_shot = bullets_per_shot
	$Networking.sync_max_health = max_health
	$Networking.sync_health = health
	dead = false
	$Networking.sync_dead = false

# Take modifier_nodes, a list of nodes which have a dictionary, .modifiers
# on each node:
# Put each modifier into a bucket named for the property it's modifying.
# Then, iterate through all buckets.
# Find all additions to be made. Make them first.
# Then, find all multiplications to be made. Make them.
# Finally, set the variable. This does mean that variables in the modifier dictionary need to match
#   the variable names in this script to be useful.

func modify():
	var modifier_nodes = get_node("Powers").get_children()
	var grouped_mods = {}
	for node in modifier_nodes:
		var modifiers = node.modifiers
		for dictionary_name in modifiers.keys():
			if get(dictionary_name) == null:
				print("Warning - modifying unknown property from choice node - " + str(dictionary_name))
				continue
			if !grouped_mods.has(dictionary_name):
				grouped_mods[dictionary_name] = {}
			for operation in modifiers[dictionary_name]:
				if operation not in ORDERED_OPERATIONS:
					print("Warning - unknown operation called from a choice node - " + str(operation))
					continue
				if !grouped_mods[dictionary_name].has(operation):
					grouped_mods[dictionary_name][operation] = []
				var operation_details = {operation: modifiers[dictionary_name][operation]}
				grouped_mods[dictionary_name][operation].push_back(operation_details)
	
	for stat in grouped_mods.keys(): # will modify variables
		var result = get(stat)
		for ordered_operation in ORDERED_OPERATIONS:
			if !grouped_mods[stat].has(ordered_operation):
				continue
			if ordered_operation == "add":
				for add_value in grouped_mods[stat][ordered_operation]:
					result = result + add_value["add"]
			if ordered_operation == "multiply":
				for add_value in grouped_mods[stat][ordered_operation]:
					result = result * add_value["multiply"]
		set(stat, result)
	
@rpc("call_local", "reliable")
func remote_change_name(_new_name):
	print(_new_name)
	player_name = _new_name
	$Networking.sync_player_name = _new_name
	$UI/PlayerNameLabel.text = player_name

@rpc("call_local", "reliable")
func remote_dictate_position(new_position):
	print("remote position set")
	position = new_position
	
@rpc("reliable", "call_local", "any_peer")
func set_bullets_per_shot(bpc):
	bullets_per_shot = bpc
	
@rpc("reliable", "call_local", "any_peer")
func set_bullet_scale(new_scale):
	bullet_scale = new_scale
	
@rpc("reliable", "call_local", "any_peer")
func set_bullet_damage(new_damage):
	bullet_damage = new_damage

# Get a random number from negative max to max.
func random_angle(max) -> float:
	var result = (randi() % max) * -1 if randi() % 2 == 1 else 1
	result = deg_to_rad(result)
	return result
