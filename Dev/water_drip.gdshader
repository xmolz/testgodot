shader_type canvas_item;
uniform sampler2D DropsNoise : repeat_enable;
uniform float distortion_strength : hint_range(0.0, 5.0) = 0.5;
uniform float specular_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float speed_multiplier : hint_range(0.1, 5.0) = 1.0;

float hash21(vec2 p) {
    uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673U, 3812015801U);
    uint n = (q.x ^ q.y) * 1597334673U;
    return float(n) / float(0xffffffffU);
}

vec3 hash13(float p) {
   vec3 p3 = fract(vec3(p) * vec3(.1031,.11369,.13787));
   p3 += dot(p3, p3.yzx + 19.19);
   return fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float rainDrops(vec2 st, float time, float size, vec2 scale) {
    vec2 uv = st * size;
    uv.x *= scale.x / scale.y;
    vec2 gridUv = fract(uv) - .5;
    vec2 id = floor(uv);
    vec3 h = (hash13(id.x * 467.983 + id.y * 1294.387) - .5) * .8;
    vec2 dropUv = gridUv - h.xy;
    vec4 noise = texture(DropsNoise, id * .05);
    float drop = smoothstep(.25, 0., length(dropUv)) *
        max(0., 1. - fract(time * (noise.b + .1) * .2 + noise.g) * 2.);
    return drop;
}

vec2 wigglyDrops(vec2 st, float time, float size, vec2 scale) {
    vec2 wigglyDropAspect = vec2(2., 1.);
    vec2 uv = st * size * wigglyDropAspect;
    uv.x *= scale.x / scale.y;
    uv.y += time * .23;
    vec2 gridUv = fract(uv) - .5;
    vec2 id = floor(uv);
    float h = hash21(id);
    time += h * 2. * PI;
    float w = st.y * 10.;
    float dx = (h - .5) * .8;
    dx += (.3 - abs(dx)) * pow(sin(w), 2.) * sin(2. * w) *
        pow(cos(w), 3.) * 1.05;
    float dy = -sin(time + sin(time + sin(time) * .5)) * .45;
    dy -= (gridUv.x - dx) * (gridUv.x - dx);
    vec2 dropUv = (gridUv - vec2(dx, dy)) / wigglyDropAspect;
    float drop = smoothstep(.06, .0, length(dropUv));
    vec2 trailUv = (gridUv - vec2(dx, time * .23)) / wigglyDropAspect;
    trailUv.y = (fract((trailUv.y) * 8.) - .5) / 8.;
    float trailDrop = smoothstep(.03, .0, length(trailUv));
    trailDrop *= smoothstep(-.05, .05, dropUv.y) * smoothstep(.4, dy, gridUv.y) *
            (1.-step(.4, gridUv.y));
    float fogTrail = smoothstep(-.05, .05, dropUv.y) * smoothstep(.4, dy, gridUv.y) *
            smoothstep(.05, .01, abs(dropUv.x)) * (1.-step(.4, gridUv.y));
    return vec2(drop + trailDrop, fogTrail);
}

vec2 getDrops(vec2 st, float time, vec2 scale) {
    vec2 largeDrops = wigglyDrops(st, time * 2., 1.6, scale);
    vec2 mediumDrops = wigglyDrops(st + 2.65, (time + 1296.675) * 1.4, 2.5, scale);
    vec2 smallDrops = wigglyDrops(st - 1.67, time - 896.431, 3.6, scale);
    vec2 drops;
    drops.y = max(largeDrops.y, max(mediumDrops.y, smallDrops.y));
    drops.x = smoothstep(.4, 2., largeDrops.x + mediumDrops.x + smallDrops.x);
    return drops;
}

vec2 dropsUV(vec2 uv, float _time, vec2 scale) {
    // Invert Y so drops fall DOWN the screen, matching Godot's Y-down coordinate system
    vec2 st = vec2(uv.x, -uv.y);

    // Let time run forwards natively so the droplet physics play correctly
    float time = mod(_time, 7200.0);

    vec2 drops = getDrops(st, time, scale);
    vec2 dropsX = getDrops(st + vec2(0.001, 0.0), time, scale);

    // Sample Y in the negative direction to match the inverted Y-axis
    vec2 dropsY = getDrops(st + vec2(0.0, -0.001), time, scale);

    vec3 normal = vec3(dropsX.x - drops.x, dropsY.x - drops.x, 0.0);
    normal.z = sqrt(1.0 - normal.x * normal.x - normal.y * normal.y);
    normal = normalize(normal);

    return normal.xy;
}

void fragment() {
    vec2 scale = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
    vec2 drop_normals = dropsUV(UV, TIME * speed_multiplier, scale);

    vec2 offset = drop_normals * (distortion_strength * 0.1);
    vec4 char_color = texture(TEXTURE, UV + offset);
    float base_alpha = texture(TEXTURE, UV).a;
    float shine = length(drop_normals) * specular_intensity;

    vec3 final_color = char_color.rgb;
    final_color += vec3(shine);
    COLOR = vec4(final_color, char_color.a * base_alpha);
}
