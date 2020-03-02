precision highp float;
precision highp sampler2D;
precision highp sampler3D;

layout(location = 0) out vec4 F;

layout(std140) uniform bnb_OCCLUSION_DATA
{
    vec4 OCCLUSION_RECT;
    vec4 SCREEN;
};

in vec3 maskColor;
in vec4 var_uv_bg_uv;
in vec2 var_uv;

uniform sampler2D bnb_BACKGROUND;
uniform sampler3D bnb_WLUT1;
uniform sampler3D bnb_WLUT2;

uniform float teethSharpenIntensity; // TODO: combine into material uniform block
uniform float skinSoftIntensity;

#define PSI 0.05
//#define YVG_USE_TEXTURE_OFFSET

vec3 textureLookup(vec3 originalColor, sampler3D lookupTexture)
{
    #ifdef YVG_NO_LUT_SCALE
    return texture(lookupTexture, originalColor.xyz).xyz;
    #else
    return texture(lookupTexture, originalColor.xyz*(63./64.)+0.5/64.).xyz;
    #endif
}

vec3 whitening(vec3 originalColor, float factor, sampler3D lookup) {
    vec3 color = textureLookup(originalColor, lookup);
    return mix(originalColor, color, factor);
}

vec3 sharpen(vec3 originalColor, float factor) {
    #ifdef YVG_USE_TEXTURE_OFFSET
    vec3 total = 5.0 * originalColor
    - textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(-1,-1)).xyz
    - textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(-1,+1)).xyz
    - textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(+1,-1)).xyz
    - textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(+1,+1)).xyz;
    #else
    float dx = SCREEN.z;
    float dy = SCREEN.w;

    vec3 total = 5.0 * originalColor
    - texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z-dx, var_uv_bg_uv.w-dy)).xyz
    - texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z+dx, var_uv_bg_uv.w-dy)).xyz
    - texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z-dx, var_uv_bg_uv.w+dy)).xyz
    - texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z+dx, var_uv_bg_uv.w+dy)).xyz;
    #endif
    vec3 result = mix(originalColor, total, factor);
    return clamp(result, 0.0, 1.0);
}

vec3 softSkin(vec3 originalColor, float factor) {
    vec3 screenColor = originalColor;

    #ifdef YVG_USE_TEXTURE_OFFSET
    vec3 nextColor0 = textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(-5, -5)).xyz;
    vec3 nextColor1 = textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(5, -5)).xyz;
    vec3 nextColor2 = textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(-5, 5)).xyz;
    vec3 nextColor3 = textureOffset(bnb_BACKGROUND, var_uv_bg_uv.zw, ivec2(5, 5)).xyz;
    #else
    // Lookup by non-integer (4.5 vs 5.0) offset leads to better averaging - effectively, 16 pixels vs 4, as we have linear texture filter
    float dx = 4.0 / SCREEN.x;
    float dy = 4.0 / SCREEN.y;

    vec3 nextColor0 = texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z-dx, var_uv_bg_uv.w-dy)).xyz;
    vec3 nextColor1 = texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z+dx, var_uv_bg_uv.w-dy)).xyz;
    vec3 nextColor2 = texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z-dx, var_uv_bg_uv.w+dy)).xyz;
    vec3 nextColor3 = texture(bnb_BACKGROUND, vec2(var_uv_bg_uv.z+dx, var_uv_bg_uv.w+dy)).xyz;
    #endif

    float intensity = screenColor.g;
    vec4 nextIntensity = vec4(nextColor0.g, nextColor1.g, nextColor2.g, nextColor3.g);

    vec4 lg = nextIntensity - intensity;

    vec4 curr = max(0.367 - abs(lg * (0.367 * 0.6 / (1.41 * PSI))), 0.);

    float sum = 1.0 + curr.x + curr.y + curr.z + curr.w;
    screenColor += (nextColor0 * curr.x + nextColor1 * curr.y + nextColor2 * curr.z + nextColor3 * curr.w);
    screenColor = screenColor * (factor / sum);

    screenColor = originalColor*(1.-factor) + screenColor;
    return screenColor;
}

void main()
{
    vec3 res = texture(bnb_BACKGROUND, var_uv_bg_uv.zw).xyz;

    /*
     * Soft skin
     */
    float soft_skin_factor = maskColor.r * skinSoftIntensity;
    res = softSkin(res, soft_skin_factor);

    /*
     * Eyes whitening
     */
    if( maskColor.b > 1./255. )
    {
        float e_factor = maskColor.b;
        res = whitening(res, e_factor, bnb_WLUT1);
    }

    /*
     * Teeth whitening
     */
    if (maskColor.g > 1./255.)
    {
        float sharp_factor = maskColor.g * teethSharpenIntensity;
        res = sharpen(res, sharp_factor);

        float teeth_factor = maskColor.g;
        res = whitening(res, teeth_factor, bnb_WLUT2);
    }

    F = vec4(res, 1.);
}

