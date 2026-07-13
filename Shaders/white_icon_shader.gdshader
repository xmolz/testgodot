shader_type canvas_item;

varying vec4 v_modulate;

void vertex() {
    v_modulate = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(v_modulate.rgb, tex.a * v_modulate.a);
}