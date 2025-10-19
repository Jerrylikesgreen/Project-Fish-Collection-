shader_type canvas_item;

/* Recolor shader (no red bleed)
 * mode:
 *   0 = multiply (legacy tint)
 *   1 = HSV replace (set Hue+Sat to target, keep Value)
 *   2 = Colorize grayscale (keep shading, fully replace hue)
 */
uniform int   mode = 2;

uniform vec4  tint_color : source_color = vec4(0.08, 0.42, 1.00, 1.0); // your new color
uniform float strength = 1.0;      // blend to recolor (1 = full replace)
uniform bool  preserve_whites = true;
uniform float highlight_keep = 0.90;  // how bright counts as "white"
uniform float softness = 0.12;        // soft edge around the threshold

// HSV mode controls
uniform float sat_scale = 1.0;     // scale target saturation (1 = as tint_color)
uniform float value_gain = 1.0;    // brightness gain after recolor (use if it looks dim)

// ---- helpers ----
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 rgb2hsv(vec3 c){
    float cmax = max(c.r, max(c.g, c.b));
    float cmin = min(c.r, min(c.g, c.b));
    float delta = cmax - cmin;
    float h = 0.0;
    if (delta > 1e-5){
        if (cmax == c.r)      h = mod((c.g - c.b) / delta, 6.0);
        else if (cmax == c.g) h = (c.b - c.r) / delta + 2.0;
        else                  h = (c.r - c.g) / delta + 4.0;
        h /= 6.0;
    }
    float s = (cmax <= 1e-5) ? 0.0 : (delta / cmax);
    return vec3(h, s, cmax);
}

vec3 hsv2rgb(vec3 c){
    float h = c.x * 6.0;
    float s = c.y;
    float v = c.z;
    int   i = int(floor(h));
    float f = h - float(i);
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    if(i == 0) return vec3(v, t, p);
    if(i == 1) return vec3(q, v, p);
    if(i == 2) return vec3(p, v, t);
    if(i == 3) return vec3(p, q, v);
    if(i == 4) return vec3(t, p, v);
    return vec3(v, p, q);
}

void fragment() {
    vec4 src = texture(TEXTURE, UV) * COLOR;

    // (optional) keep whites white
    float mask_white = 1.0;
    if (preserve_whites){
        float l = dot(src.rgb, LUMA);
        mask_white = 1.0 - smoothstep(highlight_keep - softness,
                                      highlight_keep + softness, l);
    }

    vec3 recolor;

    if (mode == 1){
        // ---- HSV REPLACE: set hue/sat to target, keep original value (brightness) ----
        vec3 src_hsv  = rgb2hsv(src.rgb);
        vec3 tint_hsv = rgb2hsv(tint_color.rgb);
        src_hsv.x = tint_hsv.x;                // replace hue
        src_hsv.y = clamp(tint_hsv.y * sat_scale, 0.0, 1.0); // replace/scale saturation
        recolor   = hsv2rgb(src_hsv) * value_gain;
    } else if (mode == 2){
        // ---- COLORIZE GRAYSCALE: remove original hue completely ----
        float gray = dot(src.rgb, LUMA);       // keep shading
        // normalize tint so max channel = 1 (avoids dimming)
        vec3 tc = tint_color.rgb / max(max(tint_color.r, max(tint_color.g, tint_color.b)), 1e-4);
        recolor = gray * tc * value_gain;
    } else {
        // ---- LEGACY MULTIPLY (not recommended if you want full replacement) ----
        recolor = src.rgb * tint_color.rgb * value_gain;
    }

    // Blend to recolor; mask_white limits effect on highlights
    float w = strength * mask_white;
    vec3 out_rgb = mix(src.rgb, recolor, w);

    COLOR = vec4(out_rgb, src.a);
}
