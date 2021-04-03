extends Sprite

onready var label = $Label
onready var player = $AnimationPlayer

var colors = [
	Color("eeeeee"), # 0 - white
	Color("666666"), # 1 - grey
	Color("00d800"), # 2 - green
	Color("e50606"), # 3 - red
	Color("d8b24a")  # 4 - gold
]

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	player.play("Float Up", -1, 1 + randf(), false)
	
func set_label_text(text, i):
	label.text = text
	label.add_color_override("font_color", colors[i])

func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
