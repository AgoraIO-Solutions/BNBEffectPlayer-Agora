precision highp float;

in vec3 var_v;
layout(location = 0) out vec4 F;

uniform vec4 bnb_COLOR;

void main()
{
    vec3 N = normalize(cross(dFdx(var_v), dFdy(var_v)));
    float l = dot(N, vec3(0., 0.8, 0.6)) * 0.5 + 0.5;
    F = vec4(l * bnb_COLOR.xyz, 1.);
}
