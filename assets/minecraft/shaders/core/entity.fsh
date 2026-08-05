#version 150
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:light.glsl>
#moj_import <minecraft:globals.glsl>

#define V1 16
#define V2 50

uniform sampler2D Sampler0;

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;

out vec4 fragColor;

flat in vec4 tint;
flat in vec3 vNormal;
flat in vec4 texel;

void main() {
    vec4 color;
    // Most likely not a dyed armor
    if(tint == vec4(0)) {
        color = texture(Sampler0, texCoord0);
        #ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
        #endif
        color *= vertexColor * ColorModulator;
        #ifndef NO_OVERLAY
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        #endif
        #ifndef EMISSIVE
        color *= lightMapColor;
        #endif
        fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
        return;
    }

    ivec2 atlasSize = textureSize(Sampler0, 0);
    // Check if the size of the texture matches the armor atlas texture (hacky)
    if(atlasSize == ivec2(2176, 32))
    {
        float armorAmount = atlasSize.x / (V1 * 4.0);
        float maxFrames = atlasSize.y / (V1 * 2.0);
        vec2 coords = texCoord0;
        coords.x /= armorAmount;
        coords.y /= maxFrames;
        if (texelFetch(Sampler0, ivec2(0, 1), 0) == vec4(1)) {
            vec4 textureProperties = vec4(0);
            vec4 customColor = vec4(0);
            float h_offset = 1.0 / armorAmount;
            vec2 nextFrame = vec2(0);
            float interpolClock = 0;
            vec4 vtc = vertexColor;
            for (int i = 1; i < (armorAmount + 1); i++) {
                customColor = texelFetch(Sampler0, ivec2(V1 * 4 * i + 0.5, 0), 0);
                if (tint == customColor) {
                    coords.x += (h_offset * i);
                    vec4 animInfo = texelFetch(Sampler0, ivec2(V1 * 4 * i + 1.5, 0), 0);
                    animInfo.rgb *= animInfo.a * 255;
                    textureProperties = texelFetch(Sampler0, ivec2(V1 * 4 * i + 2.5, 0), 0);
                    textureProperties.rgb *= textureProperties.a * 255;
                    if (animInfo != vec4(0)) {
                        float timer = floor(mod(GameTime * V2 * animInfo.g, animInfo.r));
                        if (animInfo.b > 0) interpolClock = fract(GameTime * V2 * animInfo.g);
                        float v_offset = (V1 * 2.0) / atlasSize.y * timer;
                        nextFrame = coords;
                        coords.y += v_offset;
                        nextFrame.y += (V1 * 2.0) / atlasSize.y * mod(timer + 1, animInfo.r);
                    }
                    break;
                }
            }
            if (textureProperties.g == 1) {
                if (textureProperties.r > 1) {
                    vtc = tint;
                } else if (textureProperties.r == 1) {
                    if (texture(Sampler0, vec2(coords.x + h_offset, coords.y)).a != 0) {
                        vtc = tint * texture(Sampler0, vec2(coords.x + h_offset, coords.y)).a;
                    }
                }
            } else if (textureProperties.g == 0) {
                if (textureProperties.r > 1) {
                    vtc = vec4(1);
                } else if (textureProperties.r == 1) {
                    if (texture(Sampler0, vec2(coords.x + h_offset, coords.y)).a != 0) {
                        vtc = vec4(1) * texture(Sampler0, vec2(coords.x + h_offset, coords.y)).a;
                    } else {
                        vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1)) * texel;
                    }
                } else {
                    vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1)) * texel;
                }
            } else {
                vtc = minecraft_mix_light(Light0_Direction, Light1_Direction, vNormal, vec4(1)) * texel;
            }
            vec4 armor = mix(texture(Sampler0, coords), texture(Sampler0, nextFrame), interpolClock);
            if (coords.x < (1 / armorAmount))
            color = armor * vertexColor * ColorModulator;
            else
            color = armor * vtc * ColorModulator;

            if (color.a < 0.1) discard;
            fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
        } else {
            color = texture(Sampler0, texCoord0);
            #ifdef ALPHA_CUTOUT
            if (color.a < ALPHA_CUTOUT) {
                discard;
            }
            #endif
            color *= vertexColor * ColorModulator;
            #ifndef NO_OVERLAY
            color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
            #endif
            #ifndef EMISSIVE
            color *= lightMapColor;
            #endif
            fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
        }
    } else {
        color = texture(Sampler0, texCoord0);
        #ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
        #endif
        color *= vertexColor * ColorModulator;
        #ifndef NO_OVERLAY
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        #endif
        #ifndef EMISSIVE
        color *= lightMapColor;
        #endif
        fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
    }
}