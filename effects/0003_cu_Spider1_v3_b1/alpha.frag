#version 300 es

precision mediump float;

in vec2 var_uv;

layout( location = 0 ) out vec4 F;

uniform sampler2D s_diffuse;

void main()
{
	vec4 d = texture( s_diffuse, var_uv );
	if( d.w < 1./255. ) discard;
	d.xyz = d.xyz*0.5 + 0.5;
	F = d;
}
