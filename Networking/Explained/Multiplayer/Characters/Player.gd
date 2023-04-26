extends CharacterBody2D
class_name Player

const OBSTACLE_COLLISION_LABEL := 2
const BULLET_COLLISION_LABEL := 4

const DEFAULT_SPEED := 400
const DEFAULT_ROLL_SPEED := 700
const DEFAULT_HEALTH := 100
const DISTANCE_FROM_CENTER_TO_HAND := 55
const SQUARE_DISTANCE_FROM_CENTER_TO_HAND := DISTANCE_FROM_CENTER_TO_HAND * DISTANCE_FROM_CENTER_TO_HAND
const DEFAULT_SCALE := Vector2(1, 1)
const DEFAULT_SPREAD := 10 # Measured in degrees, in either direction
const DEFAULT_BULLETS_PER_SHOT := 1 # I clicked shoot. How many bullets come out at once?
const DEFAULT_BULLET := preload("res://Items/default_bullet.tscn")
const SWORD_BULLET := preload("res://Items/sword_bullet.tscn")
const DEFAULT_BULLET_SCALE := 1.0
const DEFAULT_BULLET_DAMAGE := 35
const ORDERED_OPERATIONS := ["add", "multiply", "set", "at_least", "at_most"]
const DEFAULT_BULLET_BOUNCES := 0
const DEFAULT_SHOTS_PER_BURST := 1
const DEFAULT_BURST_GAP := .03
const DEFAULT_BULLET_SPEED := 1000
const DEFAULT_ROLL_TIME := 0.5
const NOSCOPE_SPIN_TIME := 1 # Maximum time to complete a noscope spin for it to be considered valid
const DEFAULT_NO_SCOPE_CRIT_ENABLED := false
const DEFAULT_IS_BERSERKER := false
const DEFAULT_IS_PANICKER := false
const DEFAULT_NUM_CRITS_STORED := 0
const DEFAULT_MAX_CRITS_STORED := 1
const DEFAULT_CLIP_SIZE := 5
const DEFAULT_RELOAD_TIME := 1.0
const DEFAULT_CRIT_MULTIPLIER := 2
const TELEPORT_STUN_TIME := .3 # 1.000 = 1 second
const DEFAULT_MAX_POWER_COOLDOWN := 0.0
const DAMAGE_FLASH_TIMER := .1
const DEFAULT_DIZZY_TURTLE := false
const DEFAULT_HAS_SHIELD := false
const DEFAULT_ANGRY_TURTLE := false
const ANGRY_TURTLE_THRESHOLD := 50
const DEFAULT_CAN_SPRINT := false
const SPRINT_POWER_COOLDOWN := 3.0
const SPRINT_SPEED_MULTIPLIER := 1.5
const DEFAULT_SPRINT_ROLL_SPEED := DEFAULT_ROLL_SPEED * SPRINT_SPEED_MULTIPLIER
const DEFAULT_SPRINT_SPEED := DEFAULT_SPEED * SPRINT_SPEED_MULTIPLIER
const DEFAULT_NINJA_ROLL := false
const DEFAULT_ROLL_COOLDOWN := 1.0
const DEFAULT_IS_POOCHZILLA := false
const DEFAULT_IS_HAYROLLER := false
const DEFAULT_IS_SHIELDDROPPER := false
const PANIC_MAX_BONUS_SPEED := 200.0
const DEFAULT_HAS_BOOMERANG := false
const BOOMERANG_STRENGTH := 3000.0
const DEFAULT_HAS_MACHINE_GUN := false
const MACHINE_GUN_GAP := .1
const DEFAULT_PASSIVE_REGEN := false
const PASSIVE_REGEN_GAP := 1.0
const PASSIVE_REGEN_AMOUNT := 2
const TASTY_CLIP_HEAL_AMOUNT := 15
const DEFAULT_IS_BUBBLE_SHIELDER := false

const DEFAULT_COLOR_INDEX := 0
const CRIT_COLOR_INDEX := 1
const DAMAGE_FLASH_INDEX := 2
const END_DAMAGE_FLASH_INDEX := 3
const HEAL_FLASH_INDEX := 4
const END_HEAL_FLASH_INDEX := 5
const DEFAULT_POISON_DAMAGE := 0
const DEFAULT_POISON_DURATION := 0.0

# TODO: implement these?
const DEFAULT_BULLET_SLOW := 0
const DEFAULT_CHARGE_TIME := 0

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

const teleporter_scene := preload("res://Items/teleporter.tscn")
const hay_scene := preload("res://Items/Obstacles/haystack.tscn")
const shield_scene := preload("res://Items/shield.tscn")
const pizza_scene := preload("res://Items/pizza.tscn")
var current_teleporter = null

var dizzy_turtle := DEFAULT_DIZZY_TURTLE
var angry_turtle := DEFAULT_ANGRY_TURTLE
var shot_cooldown
var roll_cooldown := DEFAULT_ROLL_COOLDOWN
var time_until_can_roll := 0.0
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
var is_berserker := DEFAULT_IS_BERSERKER
var clip_size := DEFAULT_CLIP_SIZE
var bullets_left_in_clip := clip_size
var initial_position := position
var crit_multiplier := DEFAULT_CRIT_MULTIPLIER
var max_crits := DEFAULT_MAX_CRITS_STORED
var has_teleporter := false
var is_shooting := false
# Stunned means I can look around but not move, dash, shoot, or use powers
var is_stunned := false
var remaining_stun_time := 0.0
var is_teleporting := false
var has_shield := DEFAULT_HAS_SHIELD
var has_sword := false
var max_power_cooldown := DEFAULT_MAX_POWER_COOLDOWN
var power_cooldown := max_power_cooldown
var can_power := true
var reload_time := DEFAULT_RELOAD_TIME
var can_sprint := DEFAULT_CAN_SPRINT
var sprint_speed := DEFAULT_SPRINT_SPEED
var sprint_roll_speed := DEFAULT_SPRINT_ROLL_SPEED
var has_ninja_roll := false
var is_pizza_chef := false
var roll_off_cooldown := true
var is_poochzilla := DEFAULT_IS_POOCHZILLA
var is_hayroller := DEFAULT_IS_HAYROLLER
var hayed_this_roll := false
var is_shielddropper := DEFAULT_IS_SHIELDDROPPER
var is_panicker := DEFAULT_IS_PANICKER
var has_boomerang := DEFAULT_HAS_BOOMERANG
var has_machine_gun := DEFAULT_HAS_MACHINE_GUN
# We want to start this at max so there's no delay when user first pulls trigger
var time_since_last_machine_gun_round := MACHINE_GUN_GAP + .1
var poison_damage := DEFAULT_POISON_DAMAGE
var poison_duration := DEFAULT_POISON_DURATION
var incoming_poison_damage := 0.0
var incoming_poison_duration := 0.0
var has_passive_regen := DEFAULT_PASSIVE_REGEN
var time_since_regen := 0.0
var has_tasty_clips := false
var is_bubble_shielder := DEFAULT_IS_BUBBLE_SHIELDER
var has_bubble_shield := is_bubble_shielder

# swap var so we can restore a user's original speed when they are done sprinting
var speed_temp := sprint_speed

@onready var teleport_shader = $AnimatedSprite2D.material
@onready var hand = $Hand
@onready var hand_sprite = $Hand/Sprite2d

func is_local_authority():
	return $Networking/MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

func _ready():
	if has_sword:
		hand = preload("res://Items/sword.tscn").instantiate()
		hand_sprite = hand.get_node("Sprite2D")
		shoot_point = hand.get_node("ShootPoint")
	
	initial_position = position
	$Networking/MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	no_scope_spin_timer.timeout.connect(zone_push_pop)
	no_scope_spin_timer.one_shot = true
	reload_timer.wait_time = reload_time
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
	
func panic_speed_bonus() -> float:
	return (health / max_health) * PANIC_MAX_BONUS_SPEED

func _process(delta):
	if is_local_authority():
		if time_until_can_roll > .01:
			time_until_can_roll -= delta
		roll_off_cooldown = time_until_can_roll < .01
			
		if not can_power:
			power_cooldown -= delta
			if power_cooldown < .01: # .01 buffer for float comparison
				can_power = true
				power_cooldown = max_power_cooldown
				if can_sprint:
					speed = sprint_speed
		# floating point math doesn't like exactly 0
		is_stunned = remaining_stun_time > 0.01
		if(is_stunned): move_state = Movement.states.STUNNED
		# If the player cursor is between the hand and the player,
		# stop processing hand movement. Use square distance to go
		# more fast
		var mouse_outside_player_hitbox = is_mouse_outside_player_hitbox()
		if mouse_outside_player_hitbox:
			hand.position = get_hand_position()
			hand.look_at(self.get_global_mouse_position())
			hand_sprite.flip_v = hand.global_position.x < self.global_position.x
			$Networking.sync_hand_flip = hand_sprite.flip_v
			$Networking.sync_hand_rotation = hand.rotation
			_animated_sprite.flip_h = hand_sprite.flip_v
			$Networking.sync_flip_sprite = _animated_sprite.flip_h
			if has_shield:
				$Shield.visible = true
				if is_mouse_outside_player_hitbox():
					$Shield.position = - $Hand.position
					$Shield.look_at(-self.get_global_mouse_position())
					$Shield/Sprite2D.flip_v = $Hand.global_position.x < self.global_position.x
					$Shield.rotation = $Hand.rotation
		
		var should_track_360_no_scopes := no_scope_crit_enabled and not crits_stored >= max_crits
		if dizzy_turtle or should_track_360_no_scopes:
			if previous_zones[0] == -1:
				zone_push_pop()
			var degrees_of_rotation = int(rad_to_deg(hand.rotation))
			var abs_rotation = abs(degrees_of_rotation)
			@warning_ignore("integer_division")
			var slice_size = 360 / previous_zones.size()
			var reduced_rotation = abs_rotation % 360
			current_zone = reduced_rotation / slice_size
			if current_zone == previous_zones[0] and no_scope_spin_timer.is_stopped():
				no_scope_spin_timer.start()
			elif current_zone != previous_zones[0]:
				no_scope_spin_timer.start()
				zone_push_pop()
			if detect_spin(Array(previous_zones)):
				if should_track_360_no_scopes:
					print("Crit stored")
					crits_stored = min(crits_stored + 1, max_crits)
					rpc("set_crits_stored", crits_stored)
					rpc("set_sprite_modulate", CRIT_COLOR_INDEX)
				if dizzy_turtle and not $Shield.visible:
					print("Turtle dizzied")
					rpc("set_has_shield", true)
					$Shield.reset()
					
		
		if not is_stunned and can_power and Input.is_action_just_pressed("power"):
			if has_teleporter: 
				if current_teleporter == null:
					rpc("create_teleporter")
					can_power = false
				else:
					remaining_stun_time = TELEPORT_STUN_TIME
					is_teleporting = true
			if can_sprint:
				rpc("sprint")
				power_cooldown = SPRINT_POWER_COOLDOWN
				can_power = false
			if is_pizza_chef:
				rpc("create_pizza")
				can_power = false
			if is_shielddropper:
				rpc("create_shield")
				can_power = false
				
		if not is_stunned and bullets_left_in_clip > 0:
			if has_machine_gun:
				if Input.is_action_pressed("shoot"):
					if time_since_last_machine_gun_round >= MACHINE_GUN_GAP:
						shoot()
						time_since_last_machine_gun_round = 0.0
				time_since_last_machine_gun_round += delta
			elif Input.is_action_just_pressed("shoot"):
				if not is_shooting: shoot()
		elif not is_stunned and reload_timer.is_stopped() and (Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("reload")):
			print("started reload timer")
			reload_timer.start()
		if is_teleporting:
			# The stun time describes the total time spent teleporting.
			#  Halfway through, the player should be at their original position
			#  and the shader progress should be at or near 1.0.
			var percent_done := 1.0 - (remaining_stun_time / TELEPORT_STUN_TIME)
			if percent_done < .5:
				rpc("set_teleport_shader_progress", percent_done * 2.0)
			elif percent_done > .5:
				# After we have waited over 50% of the time, we should set the player
				#  position. Then, we take the shader progress from 1.0 slowly down
				#  back to 0.0, the default state.
				position = current_teleporter.position
				$Networking.sync_position = position
				var teleport_in_progress = max(2.0 - (percent_done * 2.0), 0.0)
				#teleport_shader.set_shader_parameter("progress", teleport_in_progress)
				rpc("set_teleport_shader_progress", teleport_in_progress)
			if percent_done > .99:
				is_teleporting = false
				rpc("free_teleporter")
	else:
		health = $Networking.sync_health
		max_health = $Networking.sync_max_health
		if not $Networking.processed_hand_position:
			hand.position = $Networking.sync_hand_position
			$Networking.processed_hand_position = true
			if has_shield:
				$Shield.position = -$Networking.sync_hand_position
		hand.rotation = $Networking.sync_hand_rotation
		hand_sprite.flip_v = $Networking.sync_hand_flip
		$Shield.rotation = $Networking.sync_hand_rotation
		$Shield/Sprite2D.flip_v = $Networking.sync_hand_flip
		_animated_sprite.flip_h = $Networking.sync_flip_sprite
		move_state = $Networking.sync_move_state
				
	$UI/PlayerHealth.value = health
	$UI/PlayerHealth.max_value = max_health
	$UI/PlayerHealth.visible = health < max_health
	$Networking.sync_hand_rotation = hand.rotation
	$Networking.sync_hand_position = hand.position

@rpc("call_local", "any_peer")
func set_teleport_shader_progress(progress:float) -> void:
	teleport_shader.set_shader_parameter("progress", progress)
	
func is_mouse_outside_player_hitbox() -> bool:
	return (self.get_global_mouse_position() - self.global_position).length_squared() >= SQUARE_DISTANCE_FROM_CENTER_TO_HAND

func reset_ammo():
	bullets_left_in_clip = clip_size
	reload_spinner.value = bullets_left_in_clip
	if has_tasty_clips:
		heal(TASTY_CLIP_HEAL_AMOUNT)

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
	is_shooting = true
	var shot_id = randi()
	var bullets_to_fire = min(bullets_per_shot, bullets_left_in_clip)
	for bullet_count in bullets_to_fire:
		var distant_target = get_distant_target()
		var bullet_angle = random_angle(spread)
		var target = distant_target.rotated(bullet_angle)
		rpc("process_shot", str(shot_id + bullet_count), self.get_global_mouse_position(), target)
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
		is_shooting = false

func _physics_process(delta):
	if health <= 0 and not dead:
		die()
	match move_state:
		Movement.states.MOVE:
			process_move(delta)
		Movement.states.ROLL:
			process_roll(delta)
		Movement.states.STUNNED:
			process_stunned(delta)
	if poison_duration > .01:
		# poison will be applied every second.
		# first, truncate duration.
		var boundary:int = int(poison_duration)
		# then, apply countdown
		poison_duration -= delta
		# if we have crossed a barrier: i.e., 10.0, 9.0, etc.,
		var new_trunc:int = int(poison_duration)
		if new_trunc == boundary - 1:
			# apply poison damage.
			# TODO: maybe hit flash? green hit flash?
			damage(incoming_poison_damage)
	else:
		rpc("set_poison", 0, 0.0)
	if has_passive_regen and health < max_health:
		if time_since_regen < PASSIVE_REGEN_GAP:
			time_since_regen += PASSIVE_REGEN_GAP
			return
		else:
			heal(PASSIVE_REGEN_AMOUNT)
			
func process_stunned(delta) -> void:
	remaining_stun_time -= delta
	if remaining_stun_time <= 0.0:
		remaining_stun_time = 0.0
		move_state = Movement.states.MOVE
			
func process_move(_delta) -> void:
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
	
	# time_until_can_roll can't equal = because float math
	if Input.is_action_just_pressed("roll") and time_until_can_roll < .01 and roll_off_cooldown and not is_poochzilla:
		time_until_can_roll = roll_cooldown
		roll_vector = Vector2(x_direction, y_direction).normalized()
		move_state = Movement.states.ROLL
		$Networking.sync_move_state = Movement.states.ROLL
		await get_tree().create_timer(roll_time).timeout
		rpc("roll_finished")
		
	# Update sync variables, which will be replicated to everyone else
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity
	

func process_roll(_delta) -> void:
	if multiplayer.is_server():
		if is_hayroller: #and not hayed_this_roll:
			#hayed_this_roll = true
			rpc("create_hay")
	time_until_can_roll = roll_cooldown
	_animated_sprite.play(roll)
	if !is_local_authority(): # this is somebody else's player character
		set_collision_mask_value(OBSTACLE_COLLISION_LABEL, $Networking.sync_collidable)
		if has_ninja_roll:
			set_collision_layer_value(BULLET_COLLISION_LABEL, $Networking.sync_collidable)
		if not $Networking.processed_position:
			position = $Networking.sync_position
			$Networking.processed_position = true
		velocity = $Networking.sync_velocity
		move_and_slide()
		return
	$Networking.sync_collidable = false
	set_collision_mask_value(OBSTACLE_COLLISION_LABEL, $Networking.sync_collidable)
	set_collision_layer_value(BULLET_COLLISION_LABEL, $Networking.sync_collidable)
	
	velocity = roll_vector * roll_speed
	move_and_slide()
	
	$Networking.sync_position = position
	$Networking.sync_velocity = velocity

@rpc("reliable", "any_peer", "call_local")
func roll_finished() -> void:
	$Networking.sync_collidable = true
	set_collision_mask_value(OBSTACLE_COLLISION_LABEL, $Networking.sync_collidable)
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
	print("damaging player by " + str(amount))
	if multiplayer.is_server():
		if has_bubble_shield:
			has_bubble_shield = false
			# TODO: visual portion
			return
		var crossed_turtle_threshold = health >= ANGRY_TURTLE_THRESHOLD and health - amount <= ANGRY_TURTLE_THRESHOLD
		rpc("take_damage", amount)
		rpc("set_sprite_modulate", DAMAGE_FLASH_INDEX)
		get_tree().create_timer(DAMAGE_FLASH_TIMER).timeout.connect(func ():
			rpc("set_sprite_modulate", END_DAMAGE_FLASH_INDEX))
		if is_berserker:
			rpc("go_berserk")
			rpc("set_sprite_modulate", CRIT_COLOR_INDEX)
		if angry_turtle and crossed_turtle_threshold:
			rpc("set_has_shield", true)
			$Shield.reset()
		if is_panicker:
			rpc("set_speed", speed + panic_speed_bonus())
		
func heal(amount):
	if multiplayer.is_server():
		if health + amount > max_health:
			amount = max_health - health
		rpc("take_damage", - amount)
		rpc("set_sprite_modulate", HEAL_FLASH_INDEX)
		# reusing damage flash timer here - should be fine for this case
		get_tree().create_timer(DAMAGE_FLASH_TIMER).timeout.connect(func ():
			rpc("set_sprite_modulate", END_HEAL_FLASH_INDEX))
		if is_panicker:
			rpc("set_speed", speed + panic_speed_bonus())
		
func stun(milliseconds:float) -> void:
	if multiplayer.is_server():
		rpc("stun_player", milliseconds)

@rpc("reliable", "call_local")
func go_berserk():
	rpc("set_crits_stored", crits_stored + 1)

@rpc("reliable", "call_local", "any_peer")
func create_teleporter():
	var instance = teleporter_scene.instantiate()
	instance.position = position
	get_node("/root/Level/SpawnRoot").add_child(instance, true)
	current_teleporter = instance

@rpc("reliable", "call_local", "any_peer")
func create_pizza():
	var instance = pizza_scene.instantiate()
	instance.position = position
	get_node("/root/Level/SpawnRoot").add_child(instance, true)

@rpc("reliable", "call_local", "any_peer")
func create_hay():
	var instance = hay_scene.instantiate()
	instance.position = position
	get_node("/root/Level/SpawnRoot").add_child(instance, true)
	
@rpc("reliable", "call_local", "any_peer")
func create_shield():
	var instance = shield_scene.instantiate()
	instance.position = position
	get_node("/root/Level/SpawnRoot").add_child(instance, true)

@rpc("reliable", "call_local", "any_peer")
func process_shot(bname, look_target, distant_target):
	if multiplayer.is_server():
		print("shooting, crit count:" + str(crits_stored))
		var instance =  SWORD_BULLET.instantiate() if has_sword else player_bullet.instantiate()
		instance.name = bname
		get_node("/root/Level/SpawnRoot").add_child(instance, true)
		instance.set_scale_for_all_clients(instance.scale * bullet_scale) # scale is a vector 2
		instance.target = distant_target
		var crit_damage = bullet_damage
		if crits_stored > 0:
			print("firing crit")
			rpc("set_crits_stored", crits_stored - 1)
			if crits_stored < 1:
				rpc("set_sprite_modulate", DEFAULT_COLOR_INDEX)
			crit_damage = bullet_damage * crit_multiplier
			instance.modulate = Color(.8, 0, 0, 1)
		instance.set_damage(crit_damage)
		instance.set_poison(poison_damage, poison_duration)
		instance.look_at(look_target)
		instance.global_position = shoot_point.global_position
		instance.num_bounces = bullet_bounces
		instance.speed = bullet_speed
		if has_boomerang:
			instance.add_constant_central_force((instance.global_position - distant_target).normalized() * BOOMERANG_STRENGTH)
		instance.fire()

@rpc("call_local", "reliable")
func take_damage(amount):
	health = health - amount
	$Networking.sync_health = health

@rpc("call_local", "reliable")
func stun_player(milliseconds):
	remaining_stun_time = max(remaining_stun_time, milliseconds)

func poison(damage:float, duration:float):
	if multiplayer.is_server():
		rpc("set_poison", damage, duration)
		
@rpc("call_local", "reliable", "any_peer")
func set_poison(taken_poison_damage:int, taken_poison_duration:float) -> void:
	incoming_poison_damage = taken_poison_damage
	incoming_poison_duration = taken_poison_duration

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
	is_hayroller = DEFAULT_IS_HAYROLLER
	can_power = true
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
	reload_time = DEFAULT_RELOAD_TIME
	has_shield = DEFAULT_HAS_SHIELD
	roll_cooldown = DEFAULT_ROLL_COOLDOWN
	time_until_can_roll = 0.0
	is_poochzilla = DEFAULT_IS_POOCHZILLA
	poison_damage = DEFAULT_POISON_DAMAGE
	poison_duration = DEFAULT_POISON_DURATION
	if current_teleporter != null:
		rpc("free_teleporter")
	
	modify()
	
	bullets_left_in_clip = clip_size
	bullet_damage = max(1, bullet_damage)
	health = max_health
	shots_left_to_burst = shots_per_burst
	# Finally, some stuff will want to go over the network explicitly.
	if is_local_authority():
		# TODO: for each of these, only send message if needed?
		rpc("set_is_poochzilla", is_poochzilla)
		rpc("set_sprite_modulate", 0)
		rpc("set_bullets_per_shot", bullets_per_shot)
		rpc("set_bullet_scale", bullet_scale)
		rpc("set_bullet_damage", bullet_damage)
		rpc("set_bullet_bounces", bullet_bounces)
		rpc("set_shots_per_burst", shots_per_burst)
		rpc("set_bullet_speed", bullet_speed)
		rpc("set_no_scope_crit_enabled", no_scope_crit_enabled)
		rpc("set_crits_stored", crits_stored)
		rpc("set_bullets_left_in_clip", bullets_left_in_clip)
		rpc("set_has_shield", has_shield)
		rpc("set_is_berserker", is_berserker)
		rpc("set_roll_speed", roll_speed)
		rpc("set_roll_time", roll_time)
		rpc("set_reload_time", reload_time)
		rpc("set_dizzy_turtle", dizzy_turtle)
		rpc("set_angry_turtle", angry_turtle)
		rpc("set_is_hayroller", is_hayroller)
		rpc("set_is_panicker", is_panicker)
		rpc("remote_set", "poison_damage", poison_damage)
		rpc("remote_set", "poison_duration", poison_duration)
		rpc("remote_set", "incoming_poison_damage", 0)
		rpc("remote_set", "incoming_poison_duration", 0.0)
		rpc("remote_set", "has_passive_regen", has_passive_regen)
		rpc("remote_set", "time_since_regen", 0.0)
		rpc("remote_set", "has_tasty_clips", has_tasty_clips)
		rpc("remote_set", "is_bubble_shielder", is_bubble_shielder)
		rpc("remote_set", "has_bubble_shield", is_bubble_shielder)
	if multiplayer.is_server():
		rpc("remote_dictate_position", initial_position)
	$Networking.sync_bullet_scale = bullet_scale
	$Networking.sync_bullets_per_shot = bullets_per_shot
	$Networking.sync_max_health = max_health
	$Networking.sync_health = health
	$Networking.sync_shots_per_burst = shots_per_burst
	$Networking.sync_bullet_speed = bullet_speed
	$Networking.sync_bullets_left_in_clip = bullets_left_in_clip
	$Networking.sync_bullet_damage = bullet_damage
	reload_spinner.max_value = clip_size
	reload_spinner.value = clip_size
	dead = false
	$Networking.sync_dead = false
	if has_shield: $Shield.reset()

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
			if ordered_operation == "at_least":
				for set_value in grouped_mods[stat][ordered_operation]:
					result = max(set_value["at_least"], result)
			if ordered_operation == "at_most":
				for set_value in grouped_mods[stat][ordered_operation]:
					result = min(set_value["at_most"], result)
			if ordered_operation == "set":
				for set_value in grouped_mods[stat][ordered_operation]:
					result = set_value["set"]
		set(stat, result)

@rpc("call_local", "reliable", "any_peer")
func remote_set(variable:String, value) -> void:
	set(variable, value)

@rpc("call_local", "reliable", "any_peer")
func set_is_poochzilla(value:bool) -> void:
	is_poochzilla = value
	
@rpc("call_local", "reliable", "any_peer")
func set_is_panicker(value:bool) -> void:
	is_panicker = value
	
@rpc("call_local", "reliable", "any_peer")
func set_is_hayroller(value:bool) -> void:
	is_hayroller = value

@rpc("call_local", "reliable", "any_peer")
func set_is_berserker(value:bool) -> void:
	is_berserker = value

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
	position = new_position
	
@rpc("reliable", "call_local", "any_peer")
func set_dizzy_turtle(dizzy):
	dizzy_turtle = dizzy
	if dizzy:
		has_shield = false
		
@rpc("reliable", "call_local", "any_peer")
func set_angry_turtle(angry):
	angry_turtle = angry
	if angry:
		has_shield = false
	
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

@rpc("reliable", "call_local", "any_peer")
func free_teleporter():
	if current_teleporter != null:
		current_teleporter.queue_free()

@rpc("reliable", "call_local", "any_peer")
func set_has_shield(value:bool) -> void:
	has_shield = value
	$Shield.visible = value
	
@rpc("reliable", "call_local", "any_peer")
func set_sprite_modulate(value:int) -> void:
	if value == CRIT_COLOR_INDEX:
		teleport_shader.set_shader_parameter("evil", true)
	if value == DAMAGE_FLASH_INDEX:
		teleport_shader.set_shader_parameter("hit_flash", true)
	if value == END_DAMAGE_FLASH_INDEX:
		teleport_shader.set_shader_parameter("hit_flash", false)
	if value == DEFAULT_COLOR_INDEX:
		teleport_shader.set_shader_parameter("evil", false)
		teleport_shader.set_shader_parameter("hit_flash", false)
		teleport_shader.set_shader_parameter("heal_flash", false)
	if value == HEAL_FLASH_INDEX:
		teleport_shader.set_shader_parameter("heal_flash", true)
	if value == END_HEAL_FLASH_INDEX:
		teleport_shader.set_shader_parameter("heal_flash", false)

@rpc("reliable", "call_local", "any_peer")
func set_roll_time(value):
	roll_time = value

@rpc("reliable", "call_local", "any_peer")
func set_reload_time(value):
	reload_time = value
	$ReloadTimer.wait_time = reload_time

@rpc("reliable", "call_local", "any_peer")
func sprint():
	speed_temp = speed
	speed = sprint_speed
	roll_speed = sprint_roll_speed

@rpc("reliable", "call_local", "any_peer")
func set_roll_speed(value):
	roll_speed = value
	
# Get a random number from negative max to max.
func random_angle(max_angle) -> float:
	var result = (randi() % max(max_angle, 1)) * -1 if randi() % 2 == 1 else 1
	result = deg_to_rad(result)
	return result
