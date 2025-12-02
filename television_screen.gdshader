shader_type canvas_item;

// A function to generate a pseudo-random number
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Get the original color of the sprite's texture at this pixel
    vec4 original_color = texture(TEXTURE, UV);

    // Only run the effect on the white parts of the TV screen
    if (original_color.r > 0.9) {
        // --- TV EFFECT CODE START ---

        // 1. Create a smoothly cycling color
        float color_speed = 0.5; // Controls how fast the colors change
        vec3 dynamic_color;
        dynamic_color.r = (sin(TIME * color_speed + 0.0) * 0.5) + 0.5; // Red channel
        dynamic_color.g = (sin(TIME * color_speed + 2.0) * 0.5) + 0.5; // Green channel (offset)
        dynamic_color.b = (sin(TIME * color_speed + 4.0) * 0.5) + 0.5; // Blue channel (offset more)
        
        vec3 white_color = vec3(1.0, 1.0, 1.0);

        // 2. Create the "wavey" movement
        // First, create a horizontal wave that will distort our main wave
        // The '0.1' at the end controls the intensity of the "wobble".
        float horizontal_wobble = sin(UV.x * 15.0 + TIME * 1.5) * 0.1;

        // Now, create the main vertical wave, but add the wobble to it
        // '20.0' is the number of vertical waves. '3.0' is the scroll speed.
        float wave_pattern = sin((UV.y * 20.0) + horizontal_wobble + (TIME * 3.0));
        
        // Map the wave from the [-1, 1] range to the [0, 1] range
        wave_pattern = (wave_pattern * 0.5) + 0.5;

        // 3. Mix the cycling color and white based on our complex wave
        vec3 color = mix(dynamic_color, white_color, wave_pattern);

        // 4. Add a very subtle layer of static so it still feels like a screen
        float noise = random(UV - TIME * 10.0) * 0.1;
        color += vec3(noise);

        COLOR = vec4(color, 1.0);
        // --- TV EFFECT CODE END ---

    } else {
        // Otherwise, it's the TV frame, so just draw the original color
        COLOR = original_color;
    }
}