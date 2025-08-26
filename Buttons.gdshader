shader_type canvas_item;

uniform bool use_texture = true;
uniform vec4 base_color : source_color = vec4(1.0);

// glitter colour & controls
uniform vec4  glitter_color      : source_color = vec4(1.0,1.0,1.0,1.0);
uniform float glitter_density    : hint_range(0.5, 20.0) = 8.0;
uniform float sparkle_intensity  : hint_range(0.0, 4.0)  = 1.5;
uniform float edge_boost         : hint_range(0.0, 2.0)   = 0.3;

// downward scroll
uniform float fall_speed_uv : hint_range(-2.0, 2.0) = 0.15;

// twinkle
uniform float twinkle_speed     : hint_range(0.0, 12.0) = 2.0;
uniform float twinkle_sharpness : hint_range(1.0, 16.0) = 8.0;
uniform float active_fraction   : hint_range(0.02, 1.0) = 0.3;

// pixel-star image (the 11Ã11)
uniform sampler2D shape_tex;
uniform int   shape_channel = 3;   // 0=R,1=G,2=B,3=A
uniform bool  invert_shape  = false;
uniform float shape_min_scale = 1.0;
uniform float shape_max_scale = 1.0;
uniform bool  random_rotate = true;
uniform float shape_padding : hint_range(0.0, 0.4) = 0.08;  // avoids edge smear

// NEW: toggle glitter only on opaque sprite pixels vs also on transparent
uniform bool  apply_on_transparent = false;
uniform float opaque_threshold     : hint_range(0.0, 1.0) = 0.05;
uniform float opaque_softness      : hint_range(0.0, 0.3) = 0.02;
// alpha to use when revealing glitter over fully transparent texels
uniform float transparent_sparkle_alpha : hint_range(0.0, 1.0) = 0.6;

// ââ helpers âââââââââââââââââââââââââââââââââââââââââââââââââââ
float hash21(vec2 p) {
    p = fract(p*vec2(123.34,456.21));
    p += dot(p, p+45.32);
    return fract(p.x*p.y);
}

float pick_channel(vec4 c, int ch){
    if(ch==0) return c.r;
    if(ch==1) return c.g;
    if(ch==2) return c.b;
    return c.a;
}

// Safe sampler: 0 outside [0,1] to avoid stretched edges
float sample_shape_safe(vec2 uv) {
    float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    if (inside < 0.5) return 0.0;
    float v = pick_channel(texture(shape_tex, uv), shape_channel);
    return invert_shape ? (1.0 - v) : v;
}

float glitter_cell(vec2 uv, float density, float seed){
    vec2 grid    = uv*density;
    vec2 cell_id = floor(grid);
    vec2 cell_uv = fract(grid);

    float r_pick  = hash21(cell_id+vec2(5.0,17.0*seed));
    float active  = step(1.0-active_fraction, r_pick);

    float r_rot   = hash21(cell_id+vec2(11.0*seed,7.0));
    float r_scale = hash21(cell_id+vec2(23.0,29.0*seed));
    float scale   = mix(shape_min_scale, shape_max_scale, r_scale);

    float ang = random_rotate ? r_rot*6.28318 : 0.0;
    float s = sin(ang), c = cos(ang);

    vec2 p = (cell_uv - 0.5);
    p = vec2(c*p.x - s*p.y, s*p.x + c*p.y);
    float shrink = 1.0 - shape_padding;
    p /= max(scale, 0.0001);
    p /= max(shrink, 0.0001);
    vec2 uv_shape = p + 0.5;

    float v = sample_shape_safe(uv_shape);

    float r_phase = hash21(cell_id+vec2(101.0*seed,113.0))*6.28318;
    float tw = pow(abs(sin(TIME*twinkle_speed+r_phase)), twinkle_sharpness);

    return v*active*tw;
}

void fragment(){
    vec4 albedo = use_texture ? texture(TEXTURE, UV) : base_color;

    // falling uv
    vec2 uv_fall = fract(UV + vec2(0.0, TIME*fall_speed_uv));

    // layers
    float L0 = glitter_cell(uv_fall,                       glitter_density*0.9, 1.0);
    float L1 = glitter_cell(uv_fall+vec2(0.23,0.11),       glitter_density*1.6, 2.0);
    float L2 = glitter_cell(uv_fall+vec2(-0.37,0.29),      glitter_density*2.4, 3.0);

    float sparkle_mask = L0+L1+L2;

    // sprite opacity mask (soft)
    float sprite_mask = smoothstep(opaque_threshold, opaque_threshold + opaque_softness, albedo.a);

    // limit to opaque sprite only, unless user wants glitter on transparent too
    if (!apply_on_transparent) {
        sparkle_mask *= sprite_mask;
    }

    // edge shimmer
    vec2 dudv = fwidth(UV);
    vec2 edge = smoothstep(vec2(0.0), dudv*edge_boost, UV)*
                smoothstep(vec2(1.0), 1.0-dudv*edge_boost, UV);
    float edge_factor = 1.0-clamp(min(edge.x,edge.y),0.0,1.0);

    float sparkle = sparkle_mask*(0.6+0.4*edge_factor);

    // Color
    COLOR.rgb = albedo.rgb + glitter_color.rgb*sparkle*sparkle_intensity;

    // Alpha: if drawing over transparent areas, give the glitter some alpha so it shows
    if (apply_on_transparent) {
        float glitter_alpha = clamp(sparkle * transparent_sparkle_alpha, 0.0, 1.0);
        COLOR.a = max(albedo.a, glitter_alpha);
    } else {
        COLOR.a = albedo.a;
    }
}
