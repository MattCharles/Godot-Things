extends Node2D

var target = Vector2(0, 0)
var speed = 300

var velocity = Vector2()

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _physics_process(delta):
	if not is_local_authority(): #this is somebody else's bullet
		velocity = $Networking.sync_velocity
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
	else:
		velocity = position.direction_to(target) * speed
		position = position + velocity * delta
		$Networking.sync_velocity = velocity
		$Networking.sync_position = position
