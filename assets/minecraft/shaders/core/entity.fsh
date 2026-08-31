#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:light.glsl>
#moj_import <minecraft:globals.glsl>

#define V1 16
#define V2 50

uniform sampler2D Sampler0;

#ifdef DISSOLVE
uniform sampler2D DissolveMaskSampler;
#endif

in float sphericalVertexDistance;
in float cylindricalVertexDistance;

#ifdef PER_FACE_LIGHTING
in vec4 vertexPerFaceColorBack;
in vec4 vertexPerFaceColorFront;
#else
in vec4 vertexColor;
#endif

#ifndef EMISSIVE
in vec4 lightMapColor;
#endif

#ifndef NO_OVERLAY
in vec4 overlayColor;
#endif

in vec2 texCoord0;

flat in vec4 tint;
flat in vec3 vNormal;
flat in vec4 texel;

out vec4 fragColor;

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

    // Required by the entity_cutout_dissolve pipeline used for special item
    // previews in Minecraft 26.1+. Without this, their zero dissolve alpha is
    // multiplied into the texture and the entire inventory icon disappears.
#ifdef DISSOLVE
    if (faceVertexColor.a < texture(DissolveMaskSampler, texCoord0).a) {
        discard;
    }
    faceVertexColor.a = 1.0;
#endif

    if (!isCustomArmor) {
#ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
#endif
        color *= faceVertexColor * ColorModulator;
#ifndef NO_OVERLAY
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
#endif
#ifndef EMISSIVE
        color *= lightMapColor;
#endif
        fragColor = apply_fog(
            color,
            sphericalVertexDistance,
            cylindricalVertexDistance,
            FogEnvironmentalStart,
            FogEnvironmentalEnd,
            FogRenderDistanceStart,
            FogRenderDistanceEnd,
            FogColor
        );
        return;
    }

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

    for (int i = 1; i <= armorCount; i++) {
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
                vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1.0)) * texel;
            }
        } else {
            vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1.0)) * texel;
        }
    } else {
        vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1.0)) * texel;
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

    fragColor = apply_fog(
        color,
        sphericalVertexDistance,
        cylindricalVertexDistance,
        FogEnvironmentalStart,
        FogEnvironmentalEnd,
        FogRenderDistanceStart,
        FogRenderDistanceEnd,
        FogColor
    );
}
