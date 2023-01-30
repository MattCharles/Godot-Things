extends CharacterBody2D
class_name Player

const DEFAULT_SPEED = 400
const DEFAULT_ROLL_SPEED = 700
const DEFAULT_HEALTH = 100
const DISTANCE_FROM_CENTER_TO_HAND = 35

@onready var _animated_sprite = $AnimatedSprite2D
@onready var shoot_point = $Hand/ShootPoint
var player_bullet = preload("res://Items/default_bullet.tscn")

# animation names
var walk = "Walk" 
var default = "default"
var roll = "Roll"

var health := DEFAULT_HEALTH
var maxHealth := DEFAULT_HEALTH
var speed := DEFAULT_SPEED
var maxSpeed := DEFAULT_SPEED
var roll_speed := DEFAULT_ROLL_SPEED
var move_state := Movement.states.MOVE
var roll_vector := Vector2.DOWN

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready():
	# int constructor taking a string is currently broken :(
	# https://github.com/godotengine/godot/issues/44407
	# https://github.com/godotengine/godot/issues/55284
	$Networking/MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())

	$UI.visible = is_local_authority()

func _process(_delta):
	$UI/TextureProgressBar.value = health
	$UI/TextureProgressBar.visible = health < maxHealth
	if is_local_authority():
		$Hand.position = get_hand_position()
		$Hand.look_at(self.get_global_mouse_position())
		$Hand/Sprite2d.flip_v = $Hand.global_position.x < self.global_position.x
		$Networking.sync_hand_flip = $Hand/Sprite2d.flip_v
		$Networking.sync_hand_rotation = $Hand.rotation
		_animated_sprite.flip_h = $Hand/Sprite2d.flip_v
		$Networking.sync_flip_sprite = _animated_sprite.flip_h
		if Input.is_action_pressed("shoot"):
				rpc("instance_bullet", multiplayer.get_unique_id())
	else:
		if not $Networking.processed_hand_position:
			$Hand.position = $Networking.sync_hand_position
			$Networking.processed_hand_position = true
		$Hand.rotation = $Networking.sync_hand_rotation
		$Hand/Sprite2d.flip_v = $Networking.sync_hand_flip
		_animated_sprite.flip_h = $Networking.sync_flip_sprite
				
	$Networking.sync_hand_rotation = $Hand.rotation
	$Networking.sync_hand_position = $Hand.position
		

func _physics_process(delta):
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
	
	if x_direction: #TODO: make character always face mouse
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
		move_state = Movement.states.ROLL
		
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
	

func process_roll(delta) -> void:
	velocity = roll_vector * roll_speed
	_animated_sprite.play(roll)

func roll_animation_finished() -> void:
	move_state = Movement.states.ROLL
	
func get_hand_position() -> Vector2:
	var target = self.get_global_mouse_position()
	var source = self.position
	return DISTANCE_FROM_CENTER_TO_HAND * ( target - source ).normalized()
	
func get_hand_rotation() -> float:
	var target = self.get_global_mouse_position()
	var source = self.position
	return source.angle_to(target)

@rpc
func instance_bullet(id):
	#var player_bullet_instance = Global.instance_node_at_location(player_bullet, self, shoot_point.global_position) #TODO: different bullet types
	var instance = player_bullet.instantiate()
	self.add_child(instance)
	instance.global_position = shoot_point
	
	instance.name = "Bullet" + name + str(randi())
	instance.set_network_master(id)
	instance.player_rotation = $Hand.rotation
	instance.player_owner = id
	
