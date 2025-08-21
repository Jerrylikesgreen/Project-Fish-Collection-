class_name Fish_Sprite
extends AnimatedSprite2D

const GOLD_RARE  : Shader = preload("res://Resources/gold_rare.gdshader")
const GREEN_RARE : Shader = preload("res://Resources/green_rare.gdshader")
const PINK_RARE  : Shader = preload("res://Resources/pink_rare.gdshader")

@export var weight_none:  int = 50
@export var weight_green: int = 20
@export var weight_pink:  int = 15
@export var weight_gold:  int = 15

func add_rarity(force: String = "") -> void:
	var which := force if force != "" else _weighted_pick()

	var shader: Shader = null
	match which:
		"gold":
			shader = GOLD_RARE
		"green":
			shader = GREEN_RARE
		"pink":
			shader = PINK_RARE
		_:
			shader = null  # "none" or unknown

	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		material = mat           # apply per-instance
	else:
		material = null          # remove rarity effect

func _weighted_pick() -> String:
	var total := weight_none + weight_green + weight_pink + weight_gold
	if total <= 0:
		return "none"
	var pick := randi() % total
	var run := weight_none
	if pick < run:
		return "none"
	run += weight_green
	if pick < run:
		return "green"
	run += weight_pink
	if pick < run:
		return "pink"
	return "gold"

func set_rarity_param(name: String, value) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter(name, value)
