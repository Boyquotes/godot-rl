extends Particles2D

func _ready():
	yield(get_tree().create_timer(.8), "timeout")
	queue_free()
