extends CharacterBody2D
class_name Player

const DEFAULT_SPEED = 400
const DEFAULT_ROLL_SPEED = 700
const DEFAULT_HEALTH = 100
const DISTANCE_FROM_CENTER_TO_HAND = 35

@onready var _animated_sprite = $AnimatedSprite2D
@onready var shoot_point = $Hand/ShootPoint
var player_bullet = preload("res://Items/default_bullet.tscn")
var shot_cooldown
var shot_ids = {}
var shots_fired:int = 0
var roll_time = 0.5

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
	$UI/PlayerNameLabel.text = str(multiplayer.get_unique_id())

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
		if Input.is_action_just_pressed("shoot"):
			shots_fired = shots_fired + 1
			rpc("instance_bullet", multiplayer.get_unique_id(), self.get_global_mouse_position(), get_distant_target(), shots_fired)
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
		roll_vector = Vector2(x_direction, y_direction).normalized()
		move_state = Movement.states.ROLL
		await get_tree().create_timer(roll_time).timeout
		roll_finished()
		
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
	

func process_roll(delta) -> void:
	_animated_sprite.play(roll)
	$CollisionShape2D.disabled = true
	if !is_local_authority(): # this is somebody else's player character
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
		velocity = $Networking.sync_velocity
		move_and_slide()
		return
	
	velocity = roll_vector * roll_speed
	print(velocity)
	move_and_slide()
	
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity

func roll_finished() -> void:
	$CollisionShape2D.disabled = false
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

@rpc(any_peer, call_local, reliable)
func instance_bullet(id, look_at, distant_target, shot_id):
	print(str(shot_id))
	print(shot_ids)
	if shot_ids.has(shot_id):
		print("the")
		return
	shot_ids[shot_id] = true
	var instance = player_bullet.instantiate()
	instance.name = str(randi())
	get_node("/root/Level/SpawnRoot").add_child(instance, true)
	instance.target = distant_target
	instance.look_at(look_at)
	instance.global_position = shoot_point.global_position
