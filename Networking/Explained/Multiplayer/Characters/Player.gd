extends CharacterBody2D
class_name Player

const DEFAULT_SPEED = 400
const DEFAULT_ROLL_SPEED = 700
const DEFAULT_HEALTH = 100
const DISTANCE_FROM_CENTER_TO_HAND = 45
const DEFAULT_SCALE = Vector2(1, 1)
const DEFAULT_SPREAD = 30 # Measured in degrees, in either direction
const DEFAULT_BULLETS_PER_SHOT = 1 # I clicked shoot. How many bullets come out at once?
const DEFAULT_BULLET = preload("res://Items/default_bullet.tscn")

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
		roll_finished()
		
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
	

func process_roll(delta) -> void:
	_animated_sprite.play(roll)
	print("rolling")
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

func roll_finished() -> void:
	$Networking.sync_collidable = true
	$CollisionShape2D.set_deferred("disabled", !$Networking.sync_collidable)
	$Networking.sync_move_state = Movement.states.MOVE
	move_state = Movement.states.MOVE
	
func get_hand_position() -> Vector2:
	var target = self.get_global_mouse_position()
	var source = self.position
	return DISTANCE_FROM_CENTER_TO_HAND * ( target - source ).normalized()
	
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
	instance.target = distant_target
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
	
	# Then, add all our modifiers 
	var modifier_nodes = get_node("Powers").get_children()
	for node in modifier_nodes:
		print(node.modifiers)
		modify_with(node.modifiers)
	# Finally, some stuff will want to go over the network explicitly.
	print("setting bpc to " + str(bullets_per_shot))
	rpc("set_bullets_per_shot", bullets_per_shot)
	$Networking.sync_bullets_per_shot = bullets_per_shot
	$Networking.sync_max_health = max_health
	$Networking.sync_health = health
	dead = false
	$Networking.sync_dead = false
	
		
func modify_with(dict:Dictionary): #TODO: Generalize, more mods
	if dict.has("max_health"):
		var health_mod = dict["max_health"]
		if health_mod.has("multiply"):
			max_health = max_health * health_mod["multiply"]
			health = max_health
	if dict.has("scale"):
		var scale_mod = dict["scale"]
		if scale_mod.has("multiply"):
			scale = scale * scale_mod["multiply"]
			print(str(scale))
	if dict.has("speed"):
		var speed_mod = dict["speed"]
		if speed_mod.has("multiply"):
			speed = speed * speed_mod["multiply"]
	if dict.has("bullets_per_shot"):
		var per_shot_mod = dict["bullets_per_shot"]
		if per_shot_mod.has("add"):
			bullets_per_shot = bullets_per_shot + per_shot_mod["add"]
			print("Adding mod of " + str(per_shot_mod["add"]))
			print("Looking rn at bpc " + str(bullets_per_shot))
	if dict.has("bullet_scale"):
		var per_shot_mod = dict["bullet_scale"]
		if per_shot_mod.has("multiply"):
			#bullets_per_shot = bullets_per_shot * per_shot_mod["multiply"]
			pass
	
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
	
@rpc("reliable")
func set_bullets_per_shot(bpc):
	print("new bpc " + str(bpc))
	bullets_per_shot = bpc

# Get a random number from negative max to max.
func random_angle(max) -> float:
	var result = (randi() % max) * -1 if randi() % 2 == 1 else 1
	result = deg_to_rad(result)
	print("bullet angle is " + str(result))
	return result
