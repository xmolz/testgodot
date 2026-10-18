// step 2.247: turns a dark-ink-on-paper scan into colored ink on transparency
// (the paper drops out). used for the certificate ornaments in Greene's office.
// the scans are shown much smaller than they are, so they need mipmaps on import;
// thin lines then average toward the paper color, which is why paper_cut sits just
// under the paper's brightness and boost lifts faint (averaged) lines back up.
shader_type canvas_item;

uniform vec4 ink_color : source_color = vec4(0.70, 0.54, 0.22, 1.0);
// brighter than paper_cut = paper (transparent); darker than ink_full = full ink.
uniform float paper_cut : hint_range(0.0, 1.0) = 0.86;
uniform float ink_full : hint_range(0.0, 1.0) = 0.25;
uniform float boost : hint_range(0.5, 4.0) = 1.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float a = clamp((paper_cut - lum) / max(paper_cut - ink_full, 0.001), 0.0, 1.0);
	a = clamp(a * boost, 0.0, 1.0);
	COLOR = vec4(ink_color.rgb, ink_color.a * a * c.a);
}
