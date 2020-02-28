#version 300 es

#define GLFX_1_BONE

layout( location = 0 ) in vec3 attrib_pos;
layout( location = 1 ) in vec3 attrib_n;
layout( location = 2 ) in vec4 attrib_t;
layout( location = 3 ) in vec2 attrib_uv;
layout( location = 4 ) in uvec4 attrib_bones;
#ifndef GLFX_1_BONE
layout( location = 5 ) in vec4 attrib_weights;
#endif

layout(std140) uniform glfx_GLOBAL
{
	mat4 glfx_MVP;
	mat4 glfx_PROJ;
	mat4 glfx_MV;
};
layout(std140) uniform glfx_INSTANCES
{
	vec4 glfx_IDATA[8];
};
uniform uint glfx_CURRENT_I;
#define glfx_T_SPAWN (glfx_IDATA[glfx_CURRENT_I].x)
#define glfx_T_ANIM (glfx_IDATA[glfx_CURRENT_I].y)
#define glfx_ANIMKEY (glfx_IDATA[glfx_CURRENT_I].z)

uniform sampler2D glfx_BONES;

mat3x4 get_bone( uint bone_idx, float sx, float y )
{
    float x = float( int(bone_idx)*3 )*sx;
    return mat3x4( 
        texture( glfx_BONES, vec2(x+0.5*sx,y) ),
        texture( glfx_BONES, vec2(x+1.5*sx,y) ),
        texture( glfx_BONES, vec2(x+2.5*sx,y) ) );
}

mat3x4 get_transform()
{
    vec2 rts = 1./vec2(textureSize(glfx_BONES,0));
    float y = (glfx_ANIMKEY+0.5)*rts.y;

    mat3x4 m = get_bone( attrib_bones[0], rts.x, y );
#ifndef GLFX_1_BONE
    if( attrib_weights[1] > 0. )
    {
        m = m*attrib_weights[0] + get_bone( attrib_bones[1], rts.x, y )*attrib_weights[1];
        if( attrib_weights[2] > 0. )
        {
            m += get_bone( attrib_bones[2], rts.x, y )*attrib_weights[2];
            if( attrib_weights[3] > 0. )
                m += get_bone( attrib_bones[3], rts.x, y )*attrib_weights[3];
        }
    }
#endif

    return m;
}

void main()
{
	mat3x4 m = get_transform();
	vec3 vpos = vec4(attrib_pos,1.)*m;
	gl_Position = glfx_MVP * vec4(vpos,1.);
}