#version 300 es

precision highp sampler2DArray;

layout( location = 0 ) in vec3 attrib_pos;
layout( location = 3 ) in vec2 attrib_uv;

layout(std140) uniform glfx_GLOBAL
{
	mat4 glfx_MVP;
	mat4 glfx_PROJ;
	mat4 glfx_MV;
	vec4 unused_spinner;
	vec4 button_pos_scale_angle[48];	// max number of buttons
	vec4 button_opacity[48];
};
layout(std140) uniform glfx_INSTANCES
{
	vec4 glfx_IDATA[48];
};
uniform uint glfx_CURRENT_I;
#define glfx_T_SPAWN (glfx_IDATA[glfx_CURRENT_I].x)
#define glfx_T_ANIM (glfx_IDATA[glfx_CURRENT_I].y)
#define glfx_ANIMKEY (glfx_IDATA[glfx_CURRENT_I].z)

out vec2 var_uv;

out float var_a;

uniform sampler2D tex;

void main()
{
	float aspect = glfx_PROJ[1][1]/glfx_PROJ[0][0];
	vec2 s = vec2(sign(glfx_PROJ[0][0])/aspect,sign(glfx_PROJ[1][1]))*3./4.;

	uint button_index = glfx_CURRENT_I;

	vec2 bpos = button_pos_scale_angle[button_index].xy;
	float bscale = button_pos_scale_angle[button_index].z;
	float bangle = button_pos_scale_angle[button_index].w;
	float sine = sin( bangle );
	float cosine = cos( bangle );
	mat2 rotation = mat2( cosine, sine, -sine, cosine );

	vec2 pos = attrib_pos.xy;
	ivec2 tex_size = textureSize(tex,0);
	pos.x *= float(tex_size.x)/float(tex_size.y);

	gl_Position = vec4((rotation*(pos*(bscale/7.7)))*s,-1.,1.);
	gl_Position.xy += bpos;
	var_uv = attrib_uv;
	var_a = button_opacity[button_index].x;
}
