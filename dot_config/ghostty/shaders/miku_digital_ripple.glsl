// ============================================================
//  Hatsune Miku Digital Ripple
//  - Teal (#39C5BB) digital pulse ring on cursor mode change
//  - Tiny data fragments scatter outward
//  - Pink (#E12885) accent sparks
// ============================================================

// -- CONFIGURATION --
const vec3 MIKU_TEAL = vec3(0.224, 0.773, 0.733);
const vec3 MIKU_PINK = vec3(0.882, 0.157, 0.522);
const vec3 MIKU_CYAN = vec3(0.525, 0.808, 0.796);

const float DURATION = 0.25;
const float MAX_RADIUS = 0.07;
const float RING_THICKNESS = 0.012;
const float CURSOR_WIDTH_CHANGE_THRESHOLD = 0.5;
const float BLUR = 2.5;
const float ANIMATION_START_OFFSET = 0.0;
const float NUM_DATA_BITS = 12.0;
const float NUM_SPARKS = 6.0;

const float PI = 3.14159265359;

// --- Pseudo-random ---
float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// --- Easing ---
float easeOutCirc(float t) {
    return sqrt(1.0 - pow(t - 1.0, 2.0));
}

float easeOutExpo(float t) {
    return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t);
}

float easeOutCubic(float t) {
    return 1.0 - pow(1.0 - t, 3.0);
}

float easeOutPulse(float t) {
    return t * (2.0 - t);
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

// --- Digital data bit (small rectangle) ---
float dataBit(vec2 uv, vec2 center, float size, float seed) {
    float aspect = mix(1.5, 3.0, hash1(seed));
    vec2 d = abs(uv - center);
    return step(d.x, size * aspect * 0.5) * step(d.y, size * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalize(fragCoord, 1.0);
    vec2 offsetFactor = vec2(-0.5, 0.5);

    vec4 currentCursor = vec4(normalize(iCurrentCursor.xy, 1.0), normalize(iCurrentCursor.zw, 0.0));
    vec4 previousCursor = vec4(normalize(iPreviousCursor.xy, 1.0), normalize(iPreviousCursor.zw, 0.0));

    vec2 centerCC = currentCursor.xy - (currentCursor.zw * offsetFactor);

    float cellWidth = max(currentCursor.z, previousCursor.z);

    // Detect mode change (insert <-> normal)
    float widthChange = abs(currentCursor.z - previousCursor.z);
    float widthThresholdNorm = cellWidth * CURSOR_WIDTH_CHANGE_THRESHOLD;
    float isModeChange = step(widthThresholdNorm, widthChange);

    // Animation
    float rippleProgress = (iTime - iTimeCursorChange) / DURATION + ANIMATION_START_OFFSET;
    float isAnimating = 1.0 - step(1.0, rippleProgress);

    if (isModeChange > 0.0 && isAnimating > 0.0) {
        float easedProgress = easeOutCirc(rippleProgress);
        float fade = 1.0 - easeOutPulse(rippleProgress);

        // === Main teal ring ===
        float rippleRadius = easedProgress * MAX_RADIUS;
        float dist = distance(vu, centerCC);
        float sdfRing = abs(dist - rippleRadius) - RING_THICKNESS * 0.5;

        float antiAliasSize = normalize(vec2(BLUR, BLUR), 0.0).x;
        float ringAlpha = (1.0 - smoothstep(-antiAliasSize, antiAliasSize, sdfRing)) * fade;

        // Ring color: teal with slight cyan brightness at the leading edge
        float edgeBrightness = smoothstep(rippleRadius - RING_THICKNESS, rippleRadius, dist);
        vec3 ringColor = mix(MIKU_TEAL, MIKU_CYAN, edgeBrightness * 0.5);

        fragColor.rgb = mix(fragColor.rgb, ringColor, ringAlpha * 0.85);

        // === Inner glow (soft teal fill) ===
        float innerGlow = (1.0 - smoothstep(0.0, rippleRadius * 0.8, dist)) * fade * 0.15;
        fragColor.rgb += MIKU_TEAL * innerGlow;

        // === Data bit fragments flying outward ===
        float seed_base = iTimeCursorChange * 100.0;
        for (float i = 0.0; i < NUM_DATA_BITS; i += 1.0) {
            float seed = seed_base + i * 17.31;
            float angle = hash1(seed) * 2.0 * PI;
            float speed = 0.5 + hash1(seed + 1.0) * 0.8;
            float radius = easeOutExpo(rippleProgress) * MAX_RADIUS * speed * 1.3;

            vec2 bitPos = centerCC + vec2(cos(angle), sin(angle)) * radius;
            float bitSize = 0.004 * (1.0 - rippleProgress * 0.6);

            float bit = dataBit(vu, bitPos, bitSize, seed);

            // Flicker: on/off digital feel
            float flicker = step(0.25, hash1(seed + iTime * 8.0 + i));

            // Color: mostly teal, some pink
            float colorChoice = step(0.8, hash1(seed + 3.0));
            vec3 bitColor = mix(MIKU_TEAL, MIKU_PINK, colorChoice);

            float bitAlpha = bit * flicker * fade * 0.9;
            fragColor.rgb = mix(fragColor.rgb, bitColor, bitAlpha);
        }

        // === Pink accent sparks ===
        for (float i = 0.0; i < NUM_SPARKS; i += 1.0) {
            float seed = seed_base + i * 31.71 + 500.0;
            float angle = hash1(seed) * 2.0 * PI;
            float speed = 0.6 + hash1(seed + 1.0) * 0.6;
            float radius = easeOutCubic(rippleProgress) * MAX_RADIUS * speed * 1.1;

            vec2 sparkPos = centerCC + vec2(cos(angle), sin(angle)) * radius;
            float sparkDist = distance(vu, sparkPos);

            // Small glowing dot
            float sparkSize = 0.003 * (1.0 - rippleProgress);
            float spark = smoothstep(sparkSize, 0.0, sparkDist);

            // Glow around spark
            float sparkGlow = exp(-sparkDist * 600.0) * 0.3 * fade;

            fragColor.rgb += MIKU_PINK * (spark + sparkGlow) * fade;
        }
    }
}
