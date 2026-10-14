#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>
#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>

uniform sampler2D Sampler0;

#ifdef DISSOLVE
uniform sampler2D DissolveMaskSampler;
#endif

#ifdef GLINT
uniform sampler2D GlintSampler;
#endif

layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
#ifdef PER_FACE_LIGHTING
layout(location = 2) in vec4 vertexPerFaceColorBack;
layout(location = 3) in vec4 vertexPerFaceColorFront;
#else
layout(location = 2) in vec4 vertexColor;
#endif

#ifndef EMISSIVE
layout(location = 4) in vec4 lightMapColor;
#endif

#ifndef NO_OVERLAY
layout(location = 5) in vec4 overlayColor;
#endif

layout(location = 6) in vec2 texCoord0;
#ifdef GLINT
layout(location = 7) in vec2 texCoordGlint;
#endif

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif


layout(location = 8) flat in vec4 tint;
layout(location = 9) flat in vec4 armorLight;
layout(location = 10) flat in vec4 texel;

#define V1 16
#define V2 50

vec4 calculateFinalColor(vec4 color, bool isCustomArmor) {
    if (!isCustomArmor) {
    #ifndef NO_OVERLAY
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
    #endif

    #ifndef EMISSIVE
    color *= lightMapColor;
    #endif
    }

    #ifdef GLINT
    vec4 glintColor = GlintAlpha * texture(GlintSampler, texCoordGlint);
    // Matches BlendFuntion.GLINT
    color.rgb += glintColor.rgb * glintColor.rgb;
    #endif

    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    vec4 fogColor = vec4(FogColor.rgb * color.a, FogColor.a);
    #else
    vec4 fogColor = FogColor;
    #endif

    return apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
}

vec4 calculateCustomArmor(ivec2 atlasSize, vec4 faceVertexColor) {
    vec4 color;
    int armorCount = atlasSize.x / (V1 * 4);
    float armorAmount = float(armorCount);
    float maxFrames = atlasSize.y / float(V1 * 2);
    vec2 coords = texCoord0;
    coords.x /= armorAmount;
    coords.y /= maxFrames;

    vec4 textureProperties = vec4(0.0);
    vec4 customColor = vec4(0.0);
    float hOffset = 1.0 / armorAmount;
    vec2 nextFrame = vec2(0.0);
    float interpolClock = 0.0;
    vec4 vtc = faceVertexColor;

    for (int i = 1; i < armorCount; i++) {
        customColor = texelFetch(Sampler0, ivec2(V1 * 4 * i, 0), 0);
        if (all(equal(tint, customColor))) {
            coords.x += hOffset * i;

            vec4 animInfo = texelFetch(Sampler0, ivec2(V1 * 4 * i + 1, 0), 0);
            animInfo.rgb *= animInfo.a * 255.0;

            textureProperties = texelFetch(Sampler0, ivec2(V1 * 4 * i + 2, 0), 0);
            textureProperties.rgb *= textureProperties.a * 255.0;

            if (!all(equal(animInfo, vec4(0.0)))) {
                float timer = floor(mod(GameTime * V2 * animInfo.g, animInfo.r));
                if (animInfo.b > 0.0) {
                    interpolClock = fract(GameTime * V2 * animInfo.g);
                }
                float vOffset = (V1 * 2.0) / atlasSize.y * timer;
                nextFrame = coords;
                coords.y += vOffset;
                nextFrame.y += (V1 * 2.0) / atlasSize.y * mod(timer + 1.0, animInfo.r);
            }
            break;
        }
    }

    if (textureProperties.g == 1.0) {
        if (textureProperties.r > 1.0) {
            vtc = tint;
        } else if (textureProperties.r == 1.0) {
            float alpha = texture(Sampler0, vec2(coords.x + hOffset, coords.y)).a;
            if (alpha != 0.0) {
                vtc = tint * alpha;
            }
        }
    } else if (textureProperties.g == 0.0) {
        if (textureProperties.r > 1.0) {
            vtc = vec4(1.0);
        } else if (textureProperties.r == 1.0) {
            float alpha = texture(Sampler0, vec2(coords.x + hOffset, coords.y)).a;
            if (alpha != 0.0) {
                vtc = vec4(1.0) * alpha;
            } else {
                vtc = armorLight * texel;
            }
        } else {
            vtc = armorLight * texel;
        }
    } else {
        vtc = armorLight * texel;
    }

    vec4 armor = mix(texture(Sampler0, coords), texture(Sampler0, nextFrame), interpolClock);
    if (coords.x < 1.0 / armorAmount) {
        color = armor * faceVertexColor * ColorModulator;
    } else {
        color = armor * vtc * ColorModulator;
    }

    if (color.a < 0.1) {
        discard;
    }

    return color;
}

void main() {
    vec4 color = texture(Sampler0, texCoord0);
    ivec2 atlasSize = textureSize(Sampler0, 0);
    bool isCustomArmor = !all(equal(tint, vec4(0.0)))
        && atlasSize == ivec2(2176, 32)
        && all(equal(texelFetch(Sampler0, ivec2(0, 1), 0), vec4(1.0)));

#ifdef PER_FACE_LIGHTING
    vec4 faceVertexColor = gl_FrontFacing ? vertexPerFaceColorFront : vertexPerFaceColorBack;
#else
    vec4 faceVertexColor = vertexColor;
#endif

#ifdef DISSOLVE
    if (faceVertexColor.a < texture(DissolveMaskSampler, texCoord0).a) {
        discard;
    }
    // Keep special inventory previews visible after the dissolve test.
    faceVertexColor.a = 1.0;
#endif

    if (isCustomArmor) {
        color = calculateCustomArmor(atlasSize, faceVertexColor);
#ifdef OIT_ADDITIVE
        color.a = min(0.99, color.a);
#endif
    } else {
#ifdef OIT_ADDITIVE
        color.a = min(0.99, color.a);
#endif
#ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
#endif
        color *= faceVertexColor * ColorModulator;
    }

#ifdef GLINT
    color.a = max(color.a, GlintAlpha);
#endif

    // All three OIT passes must see the same animated custom armor alpha.
#ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
#else
    fragColor = calculateFinalColor(color, isCustomArmor);
#endif
}
