// title_background.gdshader
// Layered background for the Title screen: radial gradient → grid lines →
// scanlines → vignette. All drawn in one fragment pass to avoid extra
// ColorRects.
shader_type canvas_item;

uniform vec4 color_inner : source_color = vec4(0.102, 0.133, 0.278, 1.0); // #1a2247
uniform vec4 color_mid   : source_color = vec4(0.039, 0.055, 0.102, 1.0); // #0A0E1A
uniform vec4 color_outer : source_color = vec4(0.024, 0.035, 0.071, 1.0); // #060912
uniform vec4 grid_color  : source_color = vec4(0.0, 0.898, 0.784, 0.06);
uniform vec2  rect_size      = vec2(360.0, 780.0);
uniform float grid_size      : hint_range(8.0, 64.0) = 24.0;
uniform float grid_thickness : hint_range(0.5, 3.0)  = 1.0;
uniform float scanline_alpha : hint_range(0.0, 0.05) = 0.012;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec2  gradient_center = vec2(0.5, 0.4);

void fragment() {
	vec2 pixel = UV * rect_size;

	float d = distance(UV, gradient_center);
	vec3 col = mix(color_inner.rgb, color_mid.rgb,   smoothstep(0.0, 0.55, d));
	col      = mix(col,             color_outer.rgb, smoothstep(0.55, 1.0, d));

	vec2 g = mod(pixel, grid_size);
	float grid_mask = max(step(g.x, grid_thickness), step(g.y, grid_thickness));
	col = mix(col, col + grid_color.rgb, grid_mask * grid_color.a);

	float scan = step(3.0, mod(pixel.y, 4.0));
	col += grid_color.rgb * scan * scanline_alpha;

	float v = smoothstep(0.5, 1.0, distance(UV, vec2(0.5, 0.5))) * vignette_strength;
	col *= 1.0 - v;

	COLOR = vec4(col, 1.0);
}
