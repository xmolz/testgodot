shader_type canvas_item;

// A slider from 0.0 (Normal) to 1.0 (Grayscale)
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    // Calculate the gray version
    float gray = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray_rgb = vec3(gray, gray, gray);
    
    // Mix the original color with the gray color based on 'strength'
    COLOR.rgb = mix(original_color.rgb, gray_rgb, strength);
    COLOR.a = original_color.a;
}