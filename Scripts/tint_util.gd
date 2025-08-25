extends Node

static func create_highlight_tint(
	tint: Color,
	strength: float = 1.0,
	keep: float = 0.85,
	soft: float = 0.10,
	sat_gate: float = 0.0
) -> ShaderMaterial:
	var sh: Shader = load("res://shaders/highlight_tint.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint_color", tint)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("highlight_keep", keep)
	mat.set_shader_parameter("softness", soft)
	mat.set_shader_parameter("sat_gate", sat_gate)
	return mat

static func apply_to(
	node: CanvasItem,
	tint: Color,
	strength: float = 1.0,
	keep: float = 0.85,
	soft: float = 0.10,
	sat_gate: float = 0.0
) -> ShaderMaterial:
	var mat := create_highlight_tint(tint, strength, keep, soft, sat_gate)
	node.material = mat
	return mat
