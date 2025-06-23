shader_type canvas_item;

uniform float white_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 white_color = vec3(1.0, 1.0, 1.0);
    vec3 final_color = mix(tex_color.rgb, white_color, white_intensity);
    COLOR = vec4(final_color, tex_color.a);
}