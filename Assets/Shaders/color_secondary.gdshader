shader_type canvas_item;

// Changed 'uniform' to 'global uniform'
global uniform vec4 global_secondary_color;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(global_secondary_color.rgb, tex_color.a * COLOR.a);
}