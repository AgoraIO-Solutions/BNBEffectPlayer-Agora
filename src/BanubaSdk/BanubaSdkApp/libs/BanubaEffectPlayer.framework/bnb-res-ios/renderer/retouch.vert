precision mediump float;
precision mediump int;

layout( location = 3 ) in vec3 attrib_pos;
layout( location = 1 ) in vec2 attrib_uv;
layout( location = 2 ) in vec4 attrib_red_mask;

layout(std140) uniform bnb_INSTANCE_DATA
{
    mat4 bnb_MV;
    mat4 bnb_MVP;
    float bnb_ANIMKEY;
    uint bnb_FACE_ID;
};

out vec3 maskColor;
out vec4 var_uv_bg_uv;
out vec2 var_uv;
invariant gl_Position;

void main()
{
    gl_Position = bnb_MVP * vec4( attrib_pos, 1. );
    maskColor = attrib_red_mask.xyz;
    vec2 bg_uv  = (gl_Position.xy / gl_Position.w) * 0.5 + 0.5;
    vec2 half_fish_uv = smoothstep(0.,1.,attrib_uv);
    half_fish_uv.x = min(half_fish_uv.x,1.-half_fish_uv.x)*2.;
    var_uv_bg_uv = vec4(half_fish_uv,bg_uv);
    var_uv = attrib_uv;
}