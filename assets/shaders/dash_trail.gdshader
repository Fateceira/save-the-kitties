shader_type canvas_item;

uniform float white_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 trail_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 white_color = vec3(1.0, 1.0, 1.0);
    vec3 mixed_with_white = mix(tex_color.rgb, white_color, white_intensity);
    vec3 final_color = mix(mixed_with_white, trail_color.rgb, trail_color.a);
    float final_alpha = tex_color.a * alpha_fade;

    COLOR = vec4(final_color, final_alpha);
}