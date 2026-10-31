shader_type canvas_item;

// step 2.229 / 2.230: scrolling scenery behind the car ride. three layers (far / mid / near).
// left of split_x the scenery runs left -> right, right of it right -> left: the camera faces
// backward from the dashboard. an empty texture slot falls back to plain placeholder shapes drawn
// here (skyline, two rows of buildings with window grids, hills, trees, poles, hedge, road).
// all placeholder colours are uniforms, set per time of day by car_ride_test.gd.

uniform sampler2D far_tex : repeat_enable, filter_linear;
uniform sampler2D mid_tex : repeat_enable, filter_linear;
uniform sampler2D near_tex : repeat_enable, filter_linear;
uniform bool use_far = false;
uniform bool use_mid = false;
uniform bool use_near = false;
uniform float far_speed = 0.01;
uniform float mid_speed = 0.08;
uniform float near_speed = 0.65;
uniform float scroll_time = 0.0;
uniform float split_x = 0.463;
uniform float screen_aspect = 1.7778;
uniform float bump_shift = 0.0;
// total smear width of the near layer's motion blur, in screen-height units
uniform float near_blur = 0.07;

uniform vec4 sky_top : source_color = vec4(0.62, 0.76, 0.91, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.87, 0.91, 0.95, 1.0);
uniform vec4 skyline_col : source_color = vec4(0.71, 0.78, 0.84, 1.0);
uniform vec4 bldg_back_col : source_color = vec4(0.66, 0.70, 0.77, 1.0);
uniform vec4 bldg_col : source_color = vec4(0.55, 0.59, 0.66, 1.0);
uniform vec4 window_col : source_color = vec4(0.38, 0.45, 0.58, 1.0);
uniform vec4 lit_col : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform vec4 hill_col : source_color = vec4(0.50, 0.62, 0.53, 1.0);
uniform vec4 tree_col : source_color = vec4(0.27, 0.42, 0.32, 1.0);
uniform vec4 trunk_col : source_color = vec4(0.30, 0.24, 0.20, 1.0);
uniform vec4 pole_col : source_color = vec4(0.25, 0.25, 0.28, 1.0);
uniform vec4 road_col : source_color = vec4(0.36, 0.36, 0.38, 1.0);
// share of windows (and street lamps) that are lit: 0 by day, about 0.55 at night
uniform float lit_amount = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// x in screen-height units, scrolled by this layer's speed and the side's direction
float scrolled_x(float uvx, float speed, float dir) {
	return uvx * screen_aspect - dir * scroll_time * speed * screen_aspect;
}

// a grid of window rectangles on a building face. u: 0..1 across the building, y: screen y.
vec3 windows(vec3 facade, float id, float u, float y, float top, float cols, float bottom) {
	float wy = (y - top - 0.025) / 0.045;
	if (wy < 0.0 || y > bottom) return facade;
	float cu = fract(u * cols);
	float cy = fract(wy);
	if (cu > 0.22 && cu < 0.78 && cy > 0.25 && cy < 0.72) {
		float cell = id * 31.0 + floor(u * cols) * 7.0 + floor(wy) * 13.0;
		if (hash(cell) < lit_amount) return lit_col.rgb;
		return window_col.rgb;
	}
	return facade;
}

vec4 ph_far(float x, float y) {
	float h = 0.52 - 0.06 * abs(sin(x * 1.7)) - 0.04 * hash(floor(x * 25.0));
	if (y > h) return vec4(skyline_col.rgb, 1.0);
	return vec4(0.0);
}

vec4 ph_mid(float x, float y) {
	// front row: wider, darker buildings
	float fi = floor(x * 2.4);
	float ff = fract(x * 2.4);
	if (hash(fi * 7.1) < 0.6 && ff > 0.08 && ff < 0.92) {
		float top = 0.28 + 0.22 * hash(fi);
		if (y > top) {
			float cols = 4.0 + floor(hash(fi * 2.3) * 3.0);
			return vec4(windows(bldg_col.rgb, fi, (ff - 0.08) / 0.84, y, top, cols, 0.66), 1.0);
		}
	}
	// ground / low hills in front of the back row
	float hill = 0.62 + 0.03 * sin(x * 2.3) + 0.015 * sin(x * 5.9 + 1.3);
	if (y > hill) return vec4(hill_col.rgb, 1.0);
	// back row: narrower, paler, some taller
	float bi = floor(x * 4.0 + 0.37);
	float bf = fract(x * 4.0 + 0.37);
	if (hash(bi * 3.7) < 0.7 && bf > 0.1 && bf < 0.9) {
		float top = 0.18 + 0.25 * hash(bi * 1.9);
		if (y > top) return vec4(windows(bldg_back_col.rgb, bi + 100.0, (bf - 0.1) / 0.8, y, top, 3.0, 0.62), 1.0);
	}
	return vec4(0.0);
}

vec4 ph_near(float x, float y) {
	if (y > 0.86) return vec4(road_col.rgb, 1.0);
	// streetlight: a pole, a short arm and a lamp head (glowing at night)
	float px = fract(x * 0.7) / 0.7; // distance from the pole's left edge, in screen-height units
	if (px < 0.014 && y > 0.2) return vec4(pole_col.rgb, 1.0);
	if (px < 0.06 && y > 0.2 && y < 0.21) return vec4(pole_col.rgb, 1.0);
	if (px > 0.045 && px < 0.075 && y > 0.205 && y < 0.222) {
		if (lit_amount > 0.3) return vec4(lit_col.rgb, 1.0);
		return vec4(pole_col.rgb * 1.3, 1.0);
	}
	// trees: round crowns on trunks, irregular spacing
	float ti = floor(x * 1.6);
	float dx = (fract(x * 1.6) - 0.5) / 1.6;
	if (hash(ti * 3.3) < 0.75) {
		float r = 0.13 + 0.07 * hash(ti * 5.1);
		float cy = 0.58 - r;
		if (length(vec2(dx, y - cy)) < r) return vec4(tree_col.rgb, 1.0);
		if (abs(dx) < 0.008 && y > cy && y < 0.86) return vec4(trunk_col.rgb, 1.0);
	}
	// low hedge along the road
	if (y > 0.78 + 0.02 * sin(x * 9.0)) return vec4(tree_col.rgb * 0.9, 1.0);
	return vec4(0.0);
}

vec4 far_at(float x, float y) {
	if (!use_far) return ph_far(x, y);
	vec2 ts = vec2(textureSize(far_tex, 0));
	return texture(far_tex, vec2(x / (ts.x / ts.y), y));
}

vec4 mid_at(float x, float y) {
	if (!use_mid) return ph_mid(x, y);
	vec2 ts = vec2(textureSize(mid_tex, 0));
	return texture(mid_tex, vec2(x / (ts.x / ts.y), y));
}

vec4 near_at(float x, float y) {
	if (!use_near) return ph_near(x, y);
	vec2 ts = vec2(textureSize(near_tex, 0));
	return texture(near_tex, vec2(x / (ts.x / ts.y), y));
}

void fragment() {
	float y = UV.y + bump_shift;
	float dir = UV.x < split_x ? 1.0 : -1.0;
	vec3 col = mix(sky_top.rgb, sky_bottom.rgb, smoothstep(0.0, 0.75, y));

	vec4 f = far_at(scrolled_x(UV.x, far_speed, dir), y);
	col = mix(col, f.rgb, f.a);
	vec4 m = mid_at(scrolled_x(UV.x, mid_speed, dir), y);
	col = mix(col, m.rgb, m.a);

	// near layer: horizontal motion blur, alpha-weighted. 16 close taps across near_blur, so thin
	// shapes smear smoothly instead of leaving stepped see-through copies.
	float xn = scrolled_x(UV.x, near_speed, dir);
	vec4 acc = vec4(0.0);
	for (int k = 0; k < 16; k++) {
		vec4 s = near_at(xn + (float(k) / 15.0 - 0.5) * near_blur, y);
		acc += vec4(s.rgb * s.a, s.a);
	}
	acc /= 16.0;
	col = col * (1.0 - acc.a) + acc.rgb;

	COLOR = vec4(col, 1.0);
}
