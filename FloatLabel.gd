extends Sprite

onready var label = $Label
onready var player = $AnimationPlayer

var colors = {
	"green" : Color(0.3,0.3,0.3,1),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	label.add_color_override("font_color", colors.green)
	player.play("Float Up")
	
func set_text(text, color):
	label.text = text
	label.font_color = "blueviolet"

func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
