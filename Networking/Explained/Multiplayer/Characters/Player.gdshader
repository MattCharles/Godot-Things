/*
Shader from Godot Shaders - the free shader library.
godotshaders.com/shader/teleport-effect

This shader is under CC0 license. Feel free to use, improve and 
change this shader according to your needs and consider sharing 
the modified result on godotshaders.com.
*/

shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform float noise_desnity = 60;
uniform float beam_size : hint_range(0.01, 0.15);
uniform vec4 color : source_color = vec4(0.0, 1.02, 1.2, 1.0);

uniform vec4 original_0: source_color;
uniform vec4 original_1: source_color;
uniform vec4 original_2: source_color;
uniform vec4 original_3: source_color;
uniform vec4 original_4: source_color;
uniform vec4 replace_0: source_color;
uniform vec4 replace_1: source_color;
uniform vec4 replace_2: source_color;
uniform vec4 replace_3: source_color;
uniform vec4 replace_4: source_color;

uniform vec4 heal_color: source_color;
uniform bool heal_flash = false;

const float precision = 0.1;

uniform bool evil = false;

uniform bool hit_flash = false;


vec4 swap_color(vec4 in_color){
	vec4 original_colors[5] = vec4[5] (original_0, original_1, original_2, original_3, original_4);
	vec4 replace_colors[5] = vec4[5] (replace_0, replace_1, replace_2, replace_3, replace_4);
	for (int i = 0; i < 5; i ++) {
		if (distance(in_color, original_colors[i]) <= precision){
			return replace_colors[i];
		}
	}
	// Couldn't find the color in the origin palette - not going to swap it
	return in_color;
}

// We are generating our own noise here. You could experiment with the 
// built in SimplexNoise or your own noise texture for other effects.
vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 uv_index = floor(uv);
    vec2 uv_fract = fract(uv);

    vec2 blur = smoothstep(0.0, 1.0, uv_fract);

    return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
                     dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
                mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
                     dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) * 0.5 + 0.5;
}

void fragment()
{
	vec4 tex = hit_flash ? 
		vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a) :
			(heal_flash ? vec4(heal_color.r, heal_color.g, heal_color.b, texture(TEXTURE, UV).a) : 
			(evil ? 
				swap_color(texture(TEXTURE, UV)) : 
				texture(TEXTURE, UV)));
	
	float noise = noise(UV * noise_desnity) * UV.y;
	
	float d1 = step(progress, noise);
	float d2 = step(progress - beam_size, noise);
	
	vec3 beam = vec3(d2 - d1) * color.rgb;
	
	tex.rgb += beam;
	tex.a *= d2;
	
	COLOR = tex;
}