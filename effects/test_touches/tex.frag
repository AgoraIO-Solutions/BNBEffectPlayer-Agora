#version 300 es

precision highp float;

in vec2 var_uv;
in float var_a;

layout( location = 0 ) out vec4 frag_color;

uniform sampler2D tex;

void main()
{
	vec4 c = texture(tex,var_uv);
	c.w *= var_a;
	frag_color = c;
}
