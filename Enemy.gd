extends Sprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var anim = $AnimationPlayer
onready var ogframe = self.frame

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

func hurt1():
	self.frame = ogframe + 2
	
func hurt2():
	var frame = ogframe
	self.frame = ogframe + 3

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Hurt":
		self.frame = ogframe
		anim.play("idle")
