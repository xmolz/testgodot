shader_type canvas_item;

uniform float dampness : hint_range(0.0, 1.0) = 0.2; // 0 is dry, 1 is soaked
uniform vec4 damp_tint : source_color = vec4(0.85, 0.9, 1.0, 1.0); // Slightly cool/blue tint

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // Darken the colors and apply a very subtle cool tint to simulate wet fabric/skin
    vec3 wet_color = mix(tex_color.rgb, tex_color.rgb * damp_tint.rgb, dampness);
    wet_color = mix(wet_color, wet_color * 0.7, dampness); // 0.7 is the max darkening factor

    COLOR = vec4(wet_color, tex_color.a);
}
