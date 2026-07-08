shader_type canvas_item;

uniform vec4 steam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.4; // 0 is clear, 1 is a sauna
uniform float speed : hint_range(0.0, 2.0) = 0.3;
uniform float scale : hint_range(1.0, 10.0) = 3.0;

// Pseudo-random generator
float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

// 2D Value Noise
float noise(vec2 p){
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u*u*(3.0-2.0*u);
    float res = mix(
        mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
        mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
    return res*res;
}

// Fractal Brownian Motion for cloud-like textures
float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.50)));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV * scale;
    // Steam drifts up and slightly right
    vec2 motion = vec2(TIME * speed * 0.2, -TIME * speed * 0.8);

    // Layer the FBM to create rolling, ethereal clouds
    float f = fbm(uv + motion);
    float f2 = fbm(uv + vec2(f) + motion * 1.2);
    float final_clouds = fbm(uv + vec2(f2) + motion * 1.5);

    // Smooth out the clouds and apply the overall room fill_amount
    float alpha = smoothstep(0.1, 0.9, final_clouds) * fill_amount;

    COLOR = vec4(steam_color.rgb, alpha * steam_color.a);
}
