extends Sprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var anim = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	anim.play("idle")

func frameup():
	var frame = self.frame
	self.frame = frame + 1
	
func framedown():
	var frame = self.frame
	self.frame = frame - 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
