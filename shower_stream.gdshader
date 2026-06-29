shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float stream_speed : hint_range(0.1, 10.0) = 3.0;
uniform float length_scale : hint_range(1.0, 50.0) = 15.0; // Stretches the noise along the line length
uniform float stream_scale : hint_range(1.0, 50.0) = 15.0; // Scales the droplet noise
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.03;
uniform vec4 water_color : source_color = vec4(0.85, 0.95, 1.0, 0.3);
uniform float droplet_density : hint_range(0.1, 1.0) = 0.65;

// Basic noise generator
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    // In a Line2D with STRETCH mode, UV.x is the length (0 to 1), UV.y is the width (0 to 1)
    vec2 uv = UV;

    // Scale UV.x so the noise doesn't stretch out weirdly on long lines
    vec2 scaled_uv = vec2(uv.x * length_scale, uv.y);

    // Create the scrolling motion along the X axis (down the line)
    float time = TIME * stream_speed;

    // Base UV for streaks (stretched heavily along the stream direction)
    vec2 streak_uv = vec2(scaled_uv.x - time, scaled_uv.y * 2.0) * stream_scale;
    streak_uv.x *= 0.15; // Stretch noise along the stream path

    // Multi-layered noise for complex, broken-up water spray
    float n1 = noise(streak_uv);
    float n2 = noise(streak_uv * 2.0 - vec2(time * 1.5, 0.0));
    float combined_noise = (n1 * 0.6 + n2 * 0.4);

    // Cut off noise to create separate droplets/streaks based on density
    float streaks = smoothstep(1.0 - droplet_density, 1.0, combined_noise);

    // Fade out the edges of the line so it isn't a harsh rectangle
    float edge_fade = smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y);

    // Fade out the very beginning and end of the line
    float end_fade = smoothstep(0.0, 0.05, uv.x) * smoothstep(1.0, 0.9, uv.x);

    float water = streaks * edge_fade * end_fade;

    // Distort what is behind the water stream
    vec2 offset = vec2(0.0);
    if (water > 0.0) {
        // Calculate a fake normal for refraction
        offset = vec2(water * distortion_strength) * (uv.y - 0.5);
    }

    vec4 bg = texture(screen_texture, SCREEN_UV + offset);

    // Mix in the water color and add specular highlights
    vec3 final_color = mix(bg.rgb, water_color.rgb, water * water_color.a);
    final_color += vec3(water * 0.6); // Bright highlight for the drops

    // Soft anti-aliased alpha
    float alpha = smoothstep(0.01, 0.1, water);

    COLOR = vec4(final_color, alpha);
}
