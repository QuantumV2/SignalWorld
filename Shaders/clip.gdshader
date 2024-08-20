shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV / (TEXTURE_PIXEL_SIZE * SCREEN_PIXEL_SIZE);
    vec4 parent_color = texture(SCREEN_TEXTURE, uv);
    vec4 current_color = texture(TEXTURE, UV);
    
    if (parent_color.a > 0.0) {
        COLOR = current_color;
    } else {
        COLOR = vec4(0.0);
    }
}