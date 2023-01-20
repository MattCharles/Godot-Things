extends CharacterBody2D
class_name Player

const DEFAULT_SPEED = 300.0
const DEFAULT_HEALTH = 100.0
const CAMERA_MAX_ZOOM := Vector2(0.5, 0.5)

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
#var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var health := DEFAULT_HEALTH
var maxHealth := DEFAULT_HEALTH
var speed := DEFAULT_SPEED
var maxSpeed := DEFAULT_SPEED

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready():
	# int constructor taking a string is currently broken :(
	# https://github.com/godotengine/godot/issues/44407
	# https://github.com/godotengine/godot/issues/55284
	$Networking/MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	
	$Camera2D.current = is_local_authority()
	$UI.visible = is_local_authority()

func _process(_delta):
	$UI/TextureProgressBar.value = health
	$UI/TextureProgressBar.visible = health < maxHealth

func _physics_process(delta):
	if !is_local_authority():
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
		velocity = $Networking.sync_velocity
		
		move_and_slide()
		return
	else:
		$JetpackParticles.emitting = false
		var zoom = $Camera2D.zoom.length()
		if zoom < 1:
			$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(1, 1), zoom * 0.005)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var x_direction = Input.get_axis("move_left", "move_right")
	var y_direction = Input.get_axis("move_up", "move_down")
	
	if x_direction:
		velocity.x = x_direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	if y_direction:
		velocity.y = y_direction * speed
	else:
		velocity.y = move_toward(velocity.y, 0, speed)
		
	# Move locally
	move_and_slide()
	
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
