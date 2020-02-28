#version 300 es

layout( location = 0 ) in vec3 attrib_pos;

layout(std140) uniform glfx_GLOBAL
{
	mat4 glfx_MVP;
	mat4 glfx_PROJ;
	mat4 glfx_MV;
	vec4 glfx_VIEW_QUAT;
};

out vec2 var_bgmask_uv;
out vec3 var_v;

vec3 quat_rotate( vec4 q, vec3 v )
{
	return v + 2.*cross( q.xyz, cross( q.xyz, v ) + q.w*v );
}

void main()
{
	vec2 v = attrib_pos.xy;
	gl_Position = vec4( v, 1., 1. );
	var_bgmask_uv = vec2(-sign(glfx_PROJ[0][0]),-sign(glfx_PROJ[1][1]))*v.yx*0.5 + 0.5;
	var_v = quat_rotate( glfx_VIEW_QUAT, vec3(v/vec2(glfx_PROJ[0][0],glfx_PROJ[1][1]),-1.) );
}
