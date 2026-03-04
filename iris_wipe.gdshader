shader_type canvas_item;

// Changed the minimum from 0.0 to -0.1
uniform float circle_size : hint_range(-0.1, 1.5) = 1.0; 
uniform float smooth_edge : hint_range(0.0, 0.1) = 0.05;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV;
    uv.x = (uv.x - 0.5) * (1920.0 / 1080.0) + 0.5;

    float dist = distance(uv, center);
    float alpha = smoothstep(circle_size, circle_size + smooth_edge, dist);
    
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}