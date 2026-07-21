shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float mask_low : hint_range(0.0, 1.0) = 0.55;
uniform float mask_high : hint_range(0.0, 1.0) = 0.92;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    float mask = smoothstep(mask_low, mask_high, original_color.r);

    // --- TV EFFECT CODE (unchanged) ---
    float color_speed = 0.5;
    vec3 dynamic_color;
    dynamic_color.r = (sin(TIME * color_speed + 0.0) * 0.5) + 0.5;
    dynamic_color.g = (sin(TIME * color_speed + 2.0) * 0.5) + 0.5;
    dynamic_color.b = (sin(TIME * color_speed + 4.0) * 0.5) + 0.5;
    vec3 white_color = vec3(1.0, 1.0, 1.0);
    float horizontal_wobble = sin(UV.x * 15.0 + TIME * 1.5) * 0.1;
    float wave_pattern = sin((UV.y * 20.0) + horizontal_wobble + (TIME * 3.0));
    wave_pattern = (wave_pattern * 0.5) + 0.5;
    vec3 color = mix(dynamic_color, white_color, wave_pattern);
    float noise = random(UV - TIME * 10.0) * 0.1;
    color += vec3(noise);
    color = mix(color, vec3(0.0), progress);
    // --- END EFFECT CODE ---

    COLOR = vec4(mix(original_color.rgb, color, mask), original_color.a);
}
