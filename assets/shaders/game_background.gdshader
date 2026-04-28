// game_background.gdshader
// Solid navy base with grid + scanlines + soft vignette, drawn in one fragment
// pass. Used by the gameplay scene as a single full-screen ColorRect.
shader_type canvas_item;

uniform vec4  base_color   : source_color = vec4(0.039, 0.055, 0.102, 1.0); // #0A0E1A
uniform vec4  grid_color   : source_color = vec4(0.0, 0.898, 0.784, 0.05);
uniform vec2  rect_size      = vec2(360.0, 780.0);
uniform float grid_size      : hint_range(8.0, 64.0) = 28.0;
uniform float grid_thickness : hint_range(0.5, 3.0)  = 1.0;
uniform float scanline_alpha : hint_range(0.0, 0.06) = 0.012;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 pixel = UV * rect_size;
	vec3 col = base_color.rgb;

	vec2 g = mod(pixel, grid_size);
	float grid_mask = max(step(g.x, grid_thickness), step(g.y, grid_thickness));
	col = mix(col, col + grid_color.rgb, grid_mask * grid_color.a);

	float scan = step(3.0, mod(pixel.y, 4.0));
	col += grid_color.rgb * scan * scanline_alpha;

	float v = smoothstep(0.5, 1.0, distance(UV, vec2(0.5, 0.5))) * vignette_strength;
	col *= 1.0 - v;

	COLOR = vec4(col, 1.0);
}
