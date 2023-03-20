extends CharacterBody2D
class_name Player

const DEFAULT_SPEED := 400
const DEFAULT_ROLL_SPEED := 700
const DEFAULT_HEALTH := 100
const DISTANCE_FROM_CENTER_TO_HAND := 55
const SQUARE_DISTANCE_FROM_CENTER_TO_HAND := DISTANCE_FROM_CENTER_TO_HAND * DISTANCE_FROM_CENTER_TO_HAND
const DEFAULT_SCALE := Vector2(1, 1)
const DEFAULT_SPREAD := 10 # Measured in degrees, in either direction
const DEFAULT_BULLETS_PER_SHOT := 1 # I clicked shoot. How many bullets come out at once?
const DEFAULT_BULLET := preload("res://Items/default_bullet.tscn")
const DEFAULT_BULLET_SCALE := 1.0
const DEFAULT_BULLET_DAMAGE := 35
const ORDERED_OPERATIONS := ["add", "multiply", "set"]
const DEFAULT_BULLET_BOUNCES := 0
const DEFAULT_SHOTS_PER_BURST := 1
const DEFAULT_BURST_GAP := .1
const DEFAULT_BULLET_SPEED := 1000
const DEFAULT_ROLL_TIME := 0.5
const NOSCOPE_SPIN_TIME := 1 #Time to complete a noscope spin for it to be considered valid
const DEFAULT_NO_SCOPE_CRIT_ENABLED = false
const DEFAULT_NUM_CRITS_STORED := 0
const DEFAULT_MAX_CRITS_STORED := 1
const DEFAULT_CLIP_SIZE := 5
const DEFAULT_RELOAD_TIME := 1
const DEFAULT_RELOAD_TIMER := 2
const DEFAULT_CRIT_MULTIPLIER := 2

# TODO: implement these
const DEFAULT_BULLET_SLOW := 0
const DEFAULT_CHARGE_TIME := 0
const DEFAULT_POISON_DAMAGE := 0

func instant_reload(): pass

signal i_die(id: int)

@onready var reload_timer := $ReloadTimer
@onready var no_scope_spin_timer := $NoScopeTimer
@onready var _animated_sprite = $AnimatedSprite2D
@onready var shoot_point = $Hand/ShootPoint
@onready var reload_spinner = $UI/ReloadSpinner

# animation names
var walk = "Walk" 
var default = "default"
var roll = "Roll"

var shot_cooldown
var roll_time = DEFAULT_ROLL_TIME
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
var bullet_bounces := DEFAULT_BULLET_BOUNCES
var shots_per_burst := DEFAULT_SHOTS_PER_BURST
var shots_left_to_burst := shots_per_burst
var bullet_speed := DEFAULT_BULLET_SPEED
var previous_zones := [-1, -1, -1, -1, -1]
var current_zone := 0
var crits_stored := DEFAULT_NUM_CRITS_STORED
var no_scope_crit_enabled := DEFAULT_NO_SCOPE_CRIT_ENABLED
var clip_size := DEFAULT_CLIP_SIZE
var bullets_left_in_clip := clip_size
var initial_position := position
var crit_multiplier := DEFAULT_CRIT_MULTIPLIER
var max_crits := DEFAULT_MAX_CRITS_STORED

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready():
	initial_position = position
	$Networking/MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	no_scope_spin_timer.timeout.connect(zone_push_pop)
	no_scope_spin_timer.one_shot = true
	reload_timer.timeout.connect(reset_ammo)
	reload_timer.one_shot = true
	reload_spinner.max_value = clip_size

	$Networking.sync_health = health
	$UI/PlayerHealth.value = health
	$Networking.sync_max_health = max_health
	$UI.visible = true
	if is_local_authority():
		$Networking.sync_player_name = player_name
	else:
		player_name = $Networking.sync_player_name
	$UI/PlayerNameLabel.text = player_name
	

func _process(_delta):
	if is_local_authority():
		# If the player cursor is between the hand and the player,
		# stop processing hand movement. Use square distance to go
		# more fast
		if (self.get_global_mouse_position() - self.global_position).length_squared() >= SQUARE_DISTANCE_FROM_CENTER_TO_HAND:
			$Hand.position = get_hand_position()
			$Hand.look_at(self.get_global_mouse_position())
			$Hand/Sprite2d.flip_v = $Hand.global_position.x < self.global_position.x
			$Networking.sync_hand_flip = $Hand/Sprite2d.flip_v
			$Networking.sync_hand_rotation = $Hand.rotation
			_animated_sprite.flip_h = $Hand/Sprite2d.flip_v
			$Networking.sync_flip_sprite = _animated_sprite.flip_h
		
		if no_scope_crit_enabled and not crits_stored >= max_crits:
			if previous_zones[0] == -1:
				zone_push_pop()
			var degrees_of_rotation = int(rad_to_deg($Hand.rotation))
			var abs_rotation = abs(degrees_of_rotation)
			var slice_size = 360 / previous_zones.size()
			var reduced_rotation = abs_rotation % 360
			current_zone = reduced_rotation / slice_size
			if current_zone == previous_zones[0] and no_scope_spin_timer.is_stopped():
				no_scope_spin_timer.start()
			elif current_zone != previous_zones[0]:
				no_scope_spin_timer.start()
				zone_push_pop()
			if detect_spin(Array(previous_zones)):
				print("Crit stored")
				crits_stored = min(crits_stored + 1, max_crits)
				rpc("set_crits_stored", crits_stored)
				_animated_sprite.modulate = Color(2, 0, 0, .8)
		
		if bullets_left_in_clip > 0 and Input.is_action_just_pressed("shoot"):
			shoot()
		elif reload_timer.is_stopped() and (Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("reload")):
			print("started reload timer")
			reload_timer.start()
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
				
	$UI/PlayerHealth.value = health
	$UI/PlayerHealth.max_value = max_health
	$UI/PlayerHealth.visible = health < max_health
	$Networking.sync_hand_rotation = $Hand.rotation
	$Networking.sync_hand_position = $Hand.position

func reset_ammo():
	bullets_left_in_clip = clip_size
	reload_spinner.value = bullets_left_in_clip

func zone_push_pop():
	previous_zones.push_front(current_zone)
	previous_zones.pop_back()
	
func detect_spin(snapshot) -> bool:
	var sorted_ascending = true
	var sorted_descending = true

	for i in range(snapshot.size() - 1):
		var diff = snapshot[i+1] - snapshot[i]
		if diff != 1 and diff != -4:
			sorted_ascending = false
		if diff != -1 and diff != 4:
			sorted_descending = false

	return sorted_ascending or sorted_descending

func shoot():
	var shot_id = randi()
	var bullets_to_fire = min(bullets_per_shot, bullets_left_in_clip)
	for bullet_count in bullets_to_fire:
		var distant_target = get_distant_target()
		var bullet_angle = random_angle(spread)
		var target = distant_target.rotated(bullet_angle)
		var processed_damage = bullet_damage
		rpc("process_shot", str(shot_id + bullet_count), multiplayer.get_unique_id(), self.get_global_mouse_position(), target)
		bullets_left_in_clip = bullets_left_in_clip - 1
		reload_spinner.value = bullets_left_in_clip
		
	shots_left_to_burst = shots_left_to_burst - 1
	if shots_left_to_burst > 0:
		var timer := Timer.new()
		add_child(timer)
		timer.wait_time = DEFAULT_BURST_GAP
		timer.one_shot = true
		timer.timeout.connect(shoot)
		timer.start()
	else:
		shots_left_to_burst = shots_per_burst

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

@rpc("reliable", "call_local", "any_peer")
func process_shot(bname, id, look_at, distant_target):
	print("shooting, crit count:" + str(crits_stored))
	var instance = player_bullet.instantiate()
	instance.name = bname
	get_node("/root/Level/SpawnRoot").add_child(instance, true)
	instance.scale = instance.scale * bullet_scale # scale is a vector 2
	instance.target = distant_target
	if crits_stored > 0:
		print("firing crit")
		rpc("set_crits_stored", crits_stored - 1)
		_animated_sprite.modulate = Color(1, 1, 1, 1)
		instance.modulate = Color(2, 0, 0, .8)
		var crit_damage = bullet_damage * crit_multiplier
		instance.set_damage(crit_damage)
	instance.look_at(look_at)
	instance.global_position = shoot_point.global_position
	instance.num_bounces = bullet_bounces
	instance.speed = bullet_speed
	instance.fire()

@rpc("call_local", "reliable")
func take_damage(amount):
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
	roll_time = DEFAULT_ROLL_TIME
	health = DEFAULT_HEALTH
	max_health = DEFAULT_HEALTH
	speed = DEFAULT_SPEED
	roll_speed = DEFAULT_ROLL_SPEED
	scale = DEFAULT_SCALE
	bullets_per_shot = DEFAULT_BULLETS_PER_SHOT
	bullet_scale = DEFAULT_BULLET_SCALE
	bullet_bounces = DEFAULT_BULLET_BOUNCES
	shots_per_burst = DEFAULT_SHOTS_PER_BURST
	bullet_speed = DEFAULT_BULLET_SPEED
	bullet_damage = DEFAULT_BULLET_DAMAGE
	no_scope_crit_enabled = DEFAULT_NO_SCOPE_CRIT_ENABLED
	crits_stored = DEFAULT_NUM_CRITS_STORED
	clip_size = DEFAULT_CLIP_SIZE
	#position = initial_position
	
	modify()
	
	bullets_left_in_clip = clip_size
	bullet_damage = 1 if bullet_damage < 1 else bullet_damage
	health = max_health
	shots_left_to_burst = shots_per_burst
	# Finally, some stuff will want to go over the network explicitly.
	if is_local_authority():
		rpc("set_bullets_per_shot", bullets_per_shot)
		rpc("set_bullet_scale", bullet_scale)
		rpc("set_bullet_damage", bullet_damage)
		rpc("set_bullet_bounces", bullet_bounces)
		rpc("set_shots_per_burst", shots_per_burst)
		rpc("set_bullet_speed", bullet_speed)
		rpc("set_no_scope_crit_enabled", no_scope_crit_enabled)
		rpc("set_crits_stored", crits_stored)
		rpc("set_bullets_left_in_clip", bullets_left_in_clip)
	if multiplayer.is_server():
		rpc("remote_dictate_position", initial_position)
	$Networking.sync_bullet_scale = bullet_scale
	$Networking.sync_bullets_per_shot = bullets_per_shot
	$Networking.sync_max_health = max_health
	$Networking.sync_health = health
	$Networking.sync_shots_per_burst = shots_per_burst
	$Networking.sync_bullet_speed = bullet_speed
	$Networking.sync_bullets_left_in_clip = bullets_left_in_clip
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
			if ordered_operation == "set":
				for set_value in grouped_mods[stat][ordered_operation]:
					result = set_value["set"]
		set(stat, result)
	
@rpc("call_local", "reliable", "any_peer")
func set_bullets_left_in_clip(value):
	bullets_left_in_clip = value
	reset_ammo()
	
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

@rpc("reliable", "call_local", "any_peer")
func set_bullet_bounces(new_bounces):
	bullet_bounces = new_bounces
	
@rpc("reliable", "call_local", "any_peer")
func set_shots_per_burst(new_shots_per_burst):
	shots_per_burst = new_shots_per_burst

@rpc("reliable", "call_local", "any_peer")
func set_bullet_speed(new_bullet_speed):
	bullet_speed = new_bullet_speed

@rpc("reliable", "call_local", "any_peer")
func set_no_scope_crit_enabled(value):
	no_scope_crit_enabled = value

@rpc("reliable", "call_local", "any_peer")
func set_crits_stored(value):
	crits_stored = value

# Get a random number from negative max to max.
func random_angle(max) -> float:
	var result = (randi() % max) * -1 if randi() % 2 == 1 else 1
	result = deg_to_rad(result)
	return result
