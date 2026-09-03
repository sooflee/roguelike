shader_type canvas_item;
// One-frame white-out on damage. The cheapest game-feel win available:
// it costs four lines and it is the difference between a hit landing and
// a number quietly changing.

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
}
