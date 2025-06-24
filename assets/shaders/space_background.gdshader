shader_type canvas_item;

uniform float pixel_scale = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D star_texture;
uniform bool use_star_texture = true;
uniform vec4 star_tint = vec4(1.0, 1.0, 1.0, 1.0);
uniform float star_density = 80.0;
uniform float star_size_min = 0.01;
uniform float star_size_max = 0.03;
uniform float twinkle_speed = 0.5;
uniform float parallax_speed = 0.02;

uniform vec4 nebula_color1 = vec4(0.8, 0.4, 1.0, 1.0);
uniform vec4 nebula_color2 = vec4(0.2, 0.4, 1.0, 1.0);
uniform vec4 nebula_color3 = vec4(0.1, 0.8, 0.9, 1.0);
uniform float nebula_size1 = 2.0;
uniform float nebula_size2 = 3.0;
uniform float nebula_size3 = 1.5;
uniform float nebula_density = 0.5;

uniform vec4 space_color = vec4(0.03, 0.01, 0.1, 1.0);
uniform float color_variation = 0.2;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
               dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
               dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float nebula(vec2 uv, float size, float time) {
    float n = 0.0;
    float a = 0.5;
    float f = size;
    
    for (int i = 0; i < 3; i++) {
        n += abs(noise(uv * f + vec2(time * 0.1, 0.0))) * a;
        a *= 0.5;
        f *= 2.0;
    }
    
    return clamp(n * nebula_density, 0.0, 1.0);
}

vec2 pixelize(vec2 uv, float scale) {
    if (scale <= 0.0) return uv;
    vec2 res = vec2(textureSize(screen_texture, 0));
    return floor(uv * res / scale) * scale / res;
}

void fragment() {
    vec2 uv = UV;
    
    if (pixel_scale > 0.0) {
        uv = pixelize(uv, pixel_scale);
    }
    
    float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
    vec2 aspect_correction = vec2(aspect, 1.0);
    
    vec2 parallax_uv = uv + vec2(TIME * parallax_speed, 0.0);
    
    vec4 final_color = space_color;
    
    float neb1 = nebula(parallax_uv * 0.5, nebula_size1, TIME);
    float neb2 = nebula(parallax_uv * 0.8 + 10.0, nebula_size2, TIME * 1.2);
    float neb3 = nebula(parallax_uv * 1.2 - 20.0, nebula_size3, TIME * 0.8);
    
    final_color.rgb = mix(final_color.rgb, nebula_color1.rgb, neb1 * nebula_color1.a);
    final_color.rgb = mix(final_color.rgb, nebula_color2.rgb, neb2 * nebula_color2.a);
    final_color.rgb = mix(final_color.rgb, nebula_color3.rgb, neb3 * nebula_color3.a);
    
    vec2 grid_uv = parallax_uv * star_density * aspect_correction;
    vec2 cell_id = floor(grid_uv);
    vec2 pixel_in_cell = fract(grid_uv);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 neighbor_cell_id = cell_id + offset;
            
            float rand1 = rand(neighbor_cell_id);
            float rand2 = rand(neighbor_cell_id + 0.5);
            float rand3 = rand(neighbor_cell_id + 1.5);
            
            vec2 star_pos = vec2(rand1, rand2);
            
            float size = mix(star_size_min, star_size_max, rand3);
            vec2 sprite_size = vec2(size / aspect, size);
            
            vec2 pixel_to_star = pixel_in_cell - star_pos - offset;
            pixel_to_star.x *= aspect;
            
            if (abs(pixel_to_star.x) < sprite_size.x && abs(pixel_to_star.y) < sprite_size.y) {
                vec2 star_uv = pixel_to_star / sprite_size + 0.5;
                
                vec4 star_color = vec4(1.0);
                if (use_star_texture) {
                    star_color = texture(star_texture, star_uv);
                } else {
                    float dist = length(pixel_to_star / sprite_size);
                    star_color = vec4(1.0 - smoothstep(0.3, 0.9, dist));
                }
                
                if (star_color.a > 0.1) {
                    float twinkle = 0.7 + 0.3 * sin(TIME * twinkle_speed + neighbor_cell_id.x * 10.0);
                    
                    vec3 star_tinted = star_tint.rgb;
                    star_tinted.r += (rand1 - 0.5) * color_variation;
                    star_tinted.g += (rand2 - 0.5) * color_variation;
                    
                    final_color.rgb += star_color.rgb * star_tinted * twinkle * star_color.a;
                }
            }
        }
    }
    
    final_color.rgb = clamp(final_color.rgb, 0.0, 1.0);
    
    COLOR = final_color;
}