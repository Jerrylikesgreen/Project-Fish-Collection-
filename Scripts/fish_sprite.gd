class_name Fish_Sprite
extends AnimatedSprite2D

@export var rarity_shader_pool: Array[ShaderMaterial]

func add_rarity(rarity: String) -> void:
	
	var shader: ShaderMaterial = null
	match rarity:
		"Gold":  shader = rarity_shader_pool[0]
		"Green": shader = rarity_shader_pool[1]
		"Pink":  shader = rarity_shader_pool[2]
		"Base":  shader = null

	if shader:
		var mat := shader
		self.material = mat        # per-instance material
	else:
		self.material = null       # remove effect
	print("Adding Rarity")

func set_rarity_param(name: String, value) -> void:
	if self.material is ShaderMaterial:
		self.material.set_shader_parameter(name, value)
