#version 300 es

precision highp float;

in vec3 var_v;
in vec2 var_bgmask_uv;

layout( location = 0 ) out vec4 F;

uniform sampler2D glfx_BG_MASK;
uniform samplerCube tex_env;

float filtered_bg_simple( sampler2D mask_tex, vec2 uv )
{
	float bg1 = texture( mask_tex, uv ).x;
	if( bg1 > 0.98 || bg1 < 0.02 )
		return bg1;

	vec2 o = 1./vec2(textureSize(mask_tex,0));
	float bg2 = texture( mask_tex, uv + vec2(o.x,0.) ).x;
	float bg3 = texture( mask_tex, uv - vec2(o.x,0.) ).x;
	float bg4 = texture( mask_tex, uv + vec2(0.,o.y) ).x;
	float bg5 = texture( mask_tex, uv - vec2(0.,o.y) ).x;

	return min(1.,0.5*(bg1+bg2+bg3+bg4+bg5));
}

void main()
{
	float mask = filtered_bg_simple( glfx_BG_MASK, var_bgmask_uv );
	const float cut_off = 0.9;
	if(mask < cut_off) discard;
	vec3 env = texture( tex_env, var_v ).xyz;
	F = vec4( env, 1./*(mask-cut_off)/(1.-cut_off)*/ );
}
