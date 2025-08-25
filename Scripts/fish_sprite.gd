class_name Fish_Sprite
extends AnimatedSprite2D

@export var rarity_shader_pool: Array[ShaderMaterial]
@onready var tilt: Node2D = %Tilt

func add_rarity(rarity: int) -> void:
	
	var shader: ShaderMaterial = null
	match rarity:
		1:  shader = rarity_shader_pool[0]
		2: shader = rarity_shader_pool[1]
		3:  shader = rarity_shader_pool[2]
		0:  shader = null

	if shader:
		var mat := shader
		tilt.set_material(mat)        # per-instance material
		print("Adding Rarity", self.material)
	else:
		tilt.material = null
		print("no")       # remove effect
