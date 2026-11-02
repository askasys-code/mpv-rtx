// =========================================================================
// Universal Semi-Monochromatic Film Grain Shader for MPV (vo=gpu-next)
// High-Luminance Organic Texture with Controlled Subtle Chroma Noise
// OLED-Safe: Zero gray lift in deep shadows & highlight rolloff
// =========================================================================

//!PARAM GrainStrength
//!DESC Film grain intensity
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 0.3
0.035

//!PARAM GrainColorRatio
//!DESC Chroma vs Luma ratio (0.0 = 100% monochrome, 1.0 = full RGB noise)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.12

//!HOOK MAIN
//!BIND HOOKED
//!DESC Semi-Monochromatic Film Grain

float grain_hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec4 hook() {
    vec4 color = HOOKED_tex(HOOKED_pos);

    // Standard Rec.709 luminance calculation
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Monochromatic noise base (identical value applied to R, G, B)
    vec2 seed_mono = HOOKED_pos * HOOKED_size + vec2(random * 137.13, random * 269.51);
    float mono_noise = grain_hash(seed_mono) * 2.0 - 1.0;

    // Subtle chromatic noise variation (prevents unnatural flat monochrome)
    vec3 color_noise = vec3(
        grain_hash(seed_mono + vec2(17.31, 31.17)) * 2.0 - 1.0,
        grain_hash(seed_mono + vec2(43.71, 79.23)) * 2.0 - 1.0,
        grain_hash(seed_mono + vec2(61.19, 11.47)) * 2.0 - 1.0
    );

    // Blend: predominantly monochromatic on luma (88%), subtle chroma (12%)
    vec3 grain = mix(vec3(mono_noise), color_noise, clamp(GrainColorRatio, 0.0, 1.0));

    // Luminance-adaptive response: zero grain on pure black (OLED safe), rolloff highlights
    float luma_mask = smoothstep(0.005, 0.06, luma) * (1.0 - 0.35 * smoothstep(0.75, 1.0, luma));

    color.rgb += grain * GrainStrength * luma_mask;
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    return color;
}