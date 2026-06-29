shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float drop_speed : hint_range(0.1, 5.0) = 0.15;
uniform float drop_density : hint_range(1.0, 100.0) = 8.0;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.03;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    vec2 screen_size = vec2(textureSize(screen_texture, 0));
    float aspect = screen_size.x / screen_size.y;
    vec2 drop_uv = vec2(uv.x * aspect, uv.y);

    float col = floor(drop_uv.x * drop_density);
    float random_col = random(vec2(col, 0.0));
    float t = TIME * drop_speed + random_col * 100.0;

    float slide_step = floor(t) + smoothstep(0.05, 0.3, fract(t));
    float speed_mult = mix(0.8, 1.2, random_col);
    drop_uv.y -= slide_step * speed_mult / drop_density;

    vec2 grid = fract(drop_uv * drop_density);
    vec2 cell = floor(drop_uv * drop_density);

    float cell_rand = random(cell);
    float drop_chance = step(0.4, cell_rand);
    vec2 gv = grid - vec2(0.5);

    float drop_size = mix(0.15, 0.3, cell_rand);
    float x_offset = mix(-0.2, 0.2, random(cell + vec2(1.0, 2.0)));
    vec2 drop_pos = vec2(x_offset, 0.25);

    vec2 delta = gv - drop_pos;
    vec2 head_delta = delta;
    head_delta.y *= 0.9;
    float head = smoothstep(drop_size, drop_size * 0.5, length(head_delta));

    float tail_taper = smoothstep(-0.5, drop_pos.y, gv.y);
    float tail_width = drop_size * 0.5 * tail_taper;
    float tail = smoothstep(tail_width, 0.0, abs(delta.x));

    tail *= smoothstep(-0.5, -0.2, gv.y);
    tail *= smoothstep(0.1, -0.1, delta.y);

    float water = max(head, tail) * drop_chance;

    vec2 static_uv = vec2(uv.x * aspect, uv.y);
    vec2 static_grid = fract(static_uv * drop_density * 2.5) - 0.5;
    vec2 static_cell = floor(static_uv * drop_density * 2.5);
    float static_rand = random(static_cell);
    float static_drop = smoothstep(0.2, 0.05, length(static_grid)) * step(0.7, static_rand);

    water = clamp(water + static_drop * 0.5, 0.0, 1.0);

    vec2 offset = vec2(0.0);
    if (water > 0.0) {
        vec2 normal = (gv - drop_pos) * 2.0;
        offset = normal * water * distortion_strength;
    }

    vec4 screen_color = texture(screen_texture, SCREEN_UV + offset);

    float highlight = smoothstep(drop_size * 0.8, drop_size * 0.4, length(head_delta - vec2(-0.02, -0.05))) * head;
    highlight = clamp(highlight, 0.0, 1.0) * drop_chance;

    vec3 final_color = screen_color.rgb;
    final_color = mix(final_color, highlight_color.rgb, water * highlight_color.a * 0.5);
    final_color = mix(final_color, vec3(1.0), highlight * 0.6);

    COLOR = vec4(final_color, screen_color.a);
}
