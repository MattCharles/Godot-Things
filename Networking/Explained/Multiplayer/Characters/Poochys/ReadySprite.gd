extends Sprite2D

var player_ready:bool = false
var yes = preload("res://Assets/Images/check.png")
var no = preload("res://Assets/Images/x.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func setReady(state):
	player_ready = state
	self.set_texture(yes if player_ready else no)
