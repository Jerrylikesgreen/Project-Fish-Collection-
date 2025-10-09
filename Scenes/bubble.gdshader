shader_type canvas_item;
render_mode blend_mix;

// Required in Godot 4 for screen sampling
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- Shape / animation
uniform float bubble_scale : hint_range(0.2, 4.0) = 1.0;
uniform float thickness    : hint_range(0.0, 0.5) = 0.12;
uniform float inner_fade   : hint_range(0.0, 0.8) = 0.30; // how much center blends back to scene
uniform float wobble_amp   : hint_range(0.0, 0.10) = 0.02;
uniform float wobble_freq  : hint_range(0.0, 10.0) = 2.0;

// --- Refraction
uniform float refract_strength : hint_range(0.0, 0.10) = 0.035;
uniform float chroma_aberration : hint_range(0.0, 0.01) = 0.002;

// --- Rim
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// --- Lifecycle (drive from code/particles)
uniform float life : hint_range(0.0, 1.0) = 1.0; // 1→0 when popping

// Small epsilon for smooth edges
const float EPS = 0.01;

void fragment() {
	// UV centered at 0,0 in a unit circle
	vec2 uv = UV * 2.0 - 1.0;
	uv /= max(bubble_scale, 0.0001);

	// Polar angle for wobble
	float ang = atan(uv.y, uv.x);
	float r   = length(uv);

	// Subtle animated wobble of the "radius"
	float wobble = 1.0 + wobble_amp * sin(ang * 6.0 + TIME * wobble_freq);
	float radius = 1.0 * wobble;

	// Masks
	float rim_band   = smoothstep(radius, radius - thickness, r); // 0→1 on rim
	float body_inner = 1.0 - smoothstep(radius - thickness, radius - thickness - inner_fade, r); // 1 at center → 0 near rim
	float bubble_mask = smoothstep(radius, radius - EPS, r); // coverage area

	// Screen samples
	vec3 screen_base = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;

	// Outward "normal" from a unit sphere projection in 2D
	vec2 n = (r > 0.0) ? normalize(uv) : vec2(0.0);
	// Stronger refraction toward center, weaker at rim
	float center_weight = clamp((radius - r) / radius, 0.0, 1.0);
	vec2 offset = n * refract_strength * center_weight;

	// Chromatic split (very subtle, adjust per taste)
	vec3 refracted;
	refracted.r = textureLod(SCREEN_TEXTURE, SCREEN_UV + offset + vec2(chroma_aberration, 0.0), 0.0).r;
	refracted.g = textureLod(SCREEN_TEXTURE, SCREEN_UV + offset,                                        0.0).g;
	refracted.b = textureLod(SCREEN_TEXTURE, SCREEN_UV + offset - vec2(chroma_aberration, 0.0),         0.0).b;

	// Mix: inside shows refracted background; outside is original screen
	vec3 mixed = mix(screen_base, refracted, clamp(body_inner, 0.0, 1.0));

	// Rim highlight
	float rim = pow(clamp(rim_band, 0.0, 1.0), rim_power);
	mixed += rim_color.rgb * rim * rim_color.a;

	// A small moving glint for life ✨
	vec2 gl1_center = vec2(-0.35, -0.35) * radius;
	float gl1 = smoothstep(0.22, 0.00, length(uv - gl1_center));
	mixed += gl1 * 0.25;

	// Compose to screen: only draw where bubble lives
	COLOR.rgb = mix(screen_base, mixed, bubble_mask);
	COLOR.a   = bubble_mask * clamp(life, 0.0, 1.0);
}
