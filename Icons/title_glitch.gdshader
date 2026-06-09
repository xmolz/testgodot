shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.592, 0.863, 0.922, 1.0); // Exact cyan from the logo
uniform float extra_thickness : hint_range(0.0, 50.0) = 2.0;

// Glitch Settings
uniform float glitch_intensity : hint_range(0.0, 0.2) = 0.05;
uniform float slice_count : hint_range(1.0, 50.0) = 15.0;
uniform float static_seed : hint_range(0.0, 100.0) = 42.0;

float random(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Helper to prevent edge-pixel smearing when sampling outside the original image
float get_alpha(sampler2D tex, vec2 sample_uv) {
    if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
        return 0.0;
    }
    return texture(tex, sample_uv).a;
}

void fragment() {
    // Shrink the UV space to create an internal transparent margin for the outline
    // 1.3 means we leave roughly 15% margin on all sides.
    float margin_scale = 1.3;
    vec2 uv = (UV - 0.5) * margin_scale + 0.5;

    // --- 1. SLICE & GLITCH ---
    float slice_index = floor(uv.y * slice_count);
    float rand_val = random(slice_index + static_seed);

    float offset = 0.0;
    if (rand_val > 0.6) {
        offset = (random(slice_index + static_seed + 1.0) - 0.5) * glitch_intensity;
    }
    uv.x += offset;

    // --- 2. SAMPLE & THICKEN ---
    float alpha = get_alpha(TEXTURE, uv);

    if (extra_thickness > 0.0) {
        // Adjust the pixel size step by the margin scale so thickness scales correctly
        vec2 ps = TEXTURE_PIXEL_SIZE * margin_scale;

        for (float d = 1.0; d <= 50.0; d += 1.0) {
            if (d > extra_thickness) {
                break;
            }

            vec2 step_ps = ps * d;

            // Orthogonal
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(step_ps.x, 0.0)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(-step_ps.x, 0.0)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(0.0, step_ps.y)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(0.0, -step_ps.y)));

            // Diagonals
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(step_ps.x, step_ps.y)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(-step_ps.x, -step_ps.y)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(step_ps.x, -step_ps.y)));
            alpha = max(alpha, get_alpha(TEXTURE, uv + vec2(-step_ps.x, step_ps.y)));
        }
    }

    // --- 3. COLORIZE ---
    COLOR = vec4(base_color.rgb, alpha * base_color.a);
}
