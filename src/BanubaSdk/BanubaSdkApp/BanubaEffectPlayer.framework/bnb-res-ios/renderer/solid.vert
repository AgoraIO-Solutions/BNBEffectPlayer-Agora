precision highp float;

layout(location = 3) in vec3 V;

out vec3 var_v;
layout(std140) uniform bnb_INSTANCE_DATA
{
    mat4 bnb_MV;
    mat4 bnb_MVP;
    float bnb_ANIMKEY;
    uint bnb_FACE_ID;
};

void main()
{
    gl_Position = bnb_MVP * vec4(V, 1.);
    var_v = V;
}
