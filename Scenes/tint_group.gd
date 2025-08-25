@tool
class_name TintGroup
extends CanvasModulate

@export var tint_color: Color = Color(0.08, 0.42, 1.0, 1.0):
	set(v):
		tint_color = v
		_apply()

@export_range(0.0, 1.0) var strength := 1.0:
	set(v):
		strength = clampf(v, 0.0, 1.0)
		_apply()

@export var preserve_highlights := true
@export_range(0.0, 1.0) var highlight_keep := 0.85
@export_range(0.0, 0.5) var softness := 0.10

func _ready() -> void:
	_apply()

func _apply() -> void:
	if preserve_highlights:
		if material == null or not (material is ShaderMaterial):
			material = _make_shader_material()
		var m := material as ShaderMaterial
		m.set_shader_parameter("tint_color", tint_color)
		m.set_shader_parameter("strength", strength)
		m.set_shader_parameter("highlight_keep", highlight_keep)
		m.set_shader_parameter("softness", softness)
		# Ensure children use this material
		_set_use_parent_material(self, true)
		self_modulate = Color(1,1,1,1)
		modulate = Color(1,1,1,1)
	else:
		# Fall back to simple modulate on the whole subtree
		material = null
		_set_use_parent_material(self, false)
		self_modulate = Color(1,1,1,1)
		modulate = Color(1,1,1,1).lerp(tint_color, strength)

func _set_use_parent_material(root: CanvasItem, value: bool) -> void:
	for c in root.get_children():
		if c is CanvasItem:
			(c as CanvasItem).use_parent_material = value
			_set_use_parent_material(c, value)

func _make_shader_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.08, 0.42, 1.0, 1.0);
uniform float strength = 1.0;
uniform float highlight_keep = 0.85;
uniform float softness = 0.10;

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	// Perceptual luminance
	float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));

	// Mask is strong in dark/mid tones, weak on highlights
	float mask = 1.0 - smoothstep(highlight_keep - softness, highlight_keep + softness, luma);

	vec3 tinted = src.rgb * tint_color.rgb;
	vec3 out_rgb = mix(src.rgb, tinted, strength * mask);
	COLOR = vec4(out_rgb, src.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat
