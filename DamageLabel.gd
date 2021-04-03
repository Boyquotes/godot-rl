extends Label

var damage_text = "ouch!"

onready var player = $AnimationPlayer

func _ready():
	# play anim floating up
	player.play("Float Up");
	
func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
