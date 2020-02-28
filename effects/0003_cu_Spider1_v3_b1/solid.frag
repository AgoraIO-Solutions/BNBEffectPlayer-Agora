#version 300 es

precision mediump float;

in vec2 var_uv;
in vec3 var_t;
in vec3 var_b;
in vec3 var_n;

layout( location = 0 ) out vec4 F;

uniform sampler2D s_diffuse;
uniform sampler2D s_normal;

void main()
{
	vec3 d = texture( s_diffuse, var_uv ).xyz;
	vec3 n = normalize(mat3(var_t,var_b,var_n)*(texture( s_normal, var_uv ).xyz*2. - 1.));
	vec3 l = vec3(0.,0.8,0.6);
	float diff = dot(n,l)*0.5+0.5;
	vec3 h_dir = normalize( l + vec3(0.,0.,1.) );
	float spec = 0.8*pow( max( dot(h_dir,n), 0. ), 32. );
	F = vec4((diff+spec)*d,1.);
}
