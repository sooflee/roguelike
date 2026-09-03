shader_type canvas_item;
// Pixel-safe dissolve for enemy death. Uses a hard cutoff against a noise
// texture rather than alpha fade, so the sprite stays crisp on the pixel grid
// instead of turning to mush as it disappears.

uniform sampler2D noise_tex;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float edge_width : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = texture(noise_tex, UV).r;
	if (n < progress) {
		discard;
	}
	// Glowing rim just ahead of the dissolve front.
	if (n < progress + edge_width) {
		COLOR = vec4(edge_color.rgb, tex.a);
	} else {
		COLOR = tex;
	}
}
