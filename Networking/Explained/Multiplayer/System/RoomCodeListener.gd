extends Label

func _ready():
	self.text = "Room Code: " + GameState.room_code
