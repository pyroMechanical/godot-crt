@tool
extends SpotLight3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	light_projector = null
	light_projector = get_child(0).get_texture()
	pass
