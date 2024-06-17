shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, blend_mix;

group_uniforms albedo;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;

group_uniforms roughness;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D roughness_texture : hint_roughness_r;

group_uniforms normal;
uniform float normal_strength : hint_range(-16.0, 16.0) = 1.0;
uniform sampler2D normal_map : hint_normal;

group_uniforms misc;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms Iridescence;
uniform sampler2D rainbow_tex : source_color, hint_default_white;
uniform sampler2D mask_tex : source_color, hint_default_black;

float SchlickFresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

vec4 screen(vec4 base, vec4 blend){
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

vec4 overlay(vec4 base, vec4 blend){
	vec4 limit = step(0.5, base);
	return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), limit);
}

vec4 lighten(vec4 base, vec4 blend){
	return max(base, blend);
}

void fragment() {
    // Calculate the tangent, bitangent, and normal in world space
    vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 t = normalize((MODEL_MATRIX * vec4(TANGENT.xyz, 0.0)).xyz);
    vec3 b = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
    mat3 tbn = mat3(t, b, n);
    
    // Sample the normal map
    vec3 iridescence_normal_map_s = texture(normal_map, UV).rgb;
    iridescence_normal_map_s = iridescence_normal_map_s * 2.0 - 1.0; // Transform from [0,1] range to [-1,1]
    // Transform the normal map to world space using the TBN matrix
    vec3 world_normal_mapped = normalize(tbn * iridescence_normal_map_s);
     
	// calculate fresnel values
	//float VdotN = dot(VIEW, NORMAL);
	//float fresnel = clamp(SchlickFresnel(VdotN), 0.0, 1.0);
	
	float VdotNMP = dot(VIEW, world_normal_mapped);
	float iridifrenel = clamp(SchlickFresnel(VdotNMP), 0.0, 1.0);
	
	// sample and mix textures
	vec4 _albedo = texture(albedo_texture, UV) * albedo;
	float _roughness = texture(roughness_texture, UV).r * roughness;
	
	// apply glass look
	float a = mix(0.001, 1.0, _albedo.a);
	
	// sample textures
    vec4 Iridescence_fresnel_albedo = mix(texture(rainbow_tex, UV), texture(rainbow_tex, -UV ), iridifrenel);
	
	ALPHA = mix(iridifrenel * edge_color.a, 1.0, a);
	ALBEDO = mix(edge_color.rgb * edge_color.a, _albedo.rgb, a);
	//ALBEDO += Iridescence_fresnel_albedo.rgb;
	
	ROUGHNESS = _roughness;
	NORMAL_MAP = texture(normal_map, UV).xyz;
	NORMAL_MAP_DEPTH = normal_strength;
	
	// function to compensate specular for alpha blend
	// 0.5 * ALPHA^-0.5
	SPECULAR = 0.5 * inversesqrt(ALPHA);
}
void light() {

	vec4 VdotL_C = vec4(-cross(VIEW, LIGHT),0.0);
	float VdotL = dot(VIEW, LIGHT);
	float spec_iridifresnel = clamp(SchlickFresnel(VdotL), 0.0, 1.0);
	vec4 Iridescence_fresnel_specular = mix(texture(rainbow_tex, -UV), texture(rainbow_tex, UV ), spec_iridifresnel);
	vec4 lightdir = overlay(texture(mask_tex, VdotL_C.xy), Iridescence_fresnel_specular);
	
    SPECULAR_LIGHT = lightdir.rgb;
    ALPHA += lightdir.r ;
}