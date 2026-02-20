// ============================================================
//  Hatsune Miku Digital Cursor Trail
//  - Miku teal (#39C5BB) glowing trail with digital particle scatter
//  - Pink accent (#E12885) sparkles at the edges
// ============================================================

// -- CONFIGURATION --
const vec3 MIKU_TEAL = vec3(0.224, 0.773, 0.733);
const vec3 MIKU_PINK = vec3(0.882, 0.157, 0.522);
const vec3 MIKU_CYAN = vec3(0.525, 0.808, 0.796);

const float DURATION = 0.12;
const float MAX_TRAIL_LENGTH = 0.2;
const float THRESHOLD_MIN_DISTANCE = 1.5;
const float BLUR = 2.0;
const float PARTICLE_COUNT = 8.0;
const float PARTICLE_SIZE = 0.006;
const float GLOW_INTENSITY = 0.6;

// --- CONSTANTS ---
const float PI = 3.14159265359;

// --- Pseudo-random ---
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// --- Easing ---
float easeOutCirc(float x) {
    return sqrt(1.0 - pow(x - 1.0, 2.0));
}

float easeOutExpo(float x) {
    return x == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
}

// --- SDF ---
float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);
    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    float flip = mix(1.0, -1.0, step(0.5, allCond + noneCond));
    s *= flip;
    return d;
}

float getSdfParallelogram(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);
    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);
    return s * sqrt(d);
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialias(float distance) {
    return 1.0 - smoothstep(0.0, normalize(vec2(BLUR, BLUR), 0.0).x, distance);
}

float determineIfTopRightIsLeading(vec2 a, vec2 b) {
    float condition1 = step(b.x, a.x) * step(a.y, b.y);
    float condition2 = step(a.x, b.x) * step(b.y, a.y);
    return 1.0 - max(condition1, condition2);
}

// --- Digital glitch particle ---
float digitalParticle(vec2 uv, vec2 center, float size, float seed) {
    // Small rectangular "bit" particles
    vec2 d = abs(uv - center);
    float aspect = mix(0.5, 2.0, hash1(seed * 7.3));
    d.x /= aspect;
    float rect = step(d.x, size) * step(d.y, size * 0.5);
    return rect;
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
    vec2 centerCP = previousCursor.xy - (previousCursor.zw * offsetFactor);

    vec2 delta = centerCP - centerCC;
    float lineLength = length(delta);

    float sdfCurrentCursor = getSdfRectangle(vu, centerCC, currentCursor.zw * 0.5);

    vec4 newColor = fragColor;

    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;
    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);

    if (lineLength > minDist) {
        // -- Trail shape (same logic as cursor_tail) --
        float head_eased = 0.0;
        float tail_eased = 0.0;
        float tail_delay_factor = MAX_TRAIL_LENGTH / lineLength;
        float isLongMove = step(MAX_TRAIL_LENGTH, lineLength);

        float head_eased_short = easeOutCirc(progress);
        float tail_eased_short = easeOutCirc(smoothstep(tail_delay_factor, 1.0, progress));
        float head_eased_long = 1.0;
        float tail_eased_long = easeOutCirc(progress);

        head_eased = mix(head_eased_long, head_eased_short, isLongMove);
        tail_eased = mix(tail_eased_long, tail_eased_short, isLongMove);

        vec2 delta_abs = abs(centerCC - centerCP);
        float threshold = 0.001;
        float isHorizontal = step(delta_abs.y, threshold);
        float isVertical = step(delta_abs.x, threshold);
        float isStraightMove = max(isHorizontal, isVertical);

        // Parallelogram (diagonal)
        vec2 head_pos_tl = mix(previousCursor.xy, currentCursor.xy, head_eased);
        vec2 tail_pos_tl = mix(previousCursor.xy, currentCursor.xy, tail_eased);

        float isTopRightLeading = determineIfTopRightIsLeading(currentCursor.xy, previousCursor.xy);
        float isBottomLeftLeading = 1.0 - isTopRightLeading;

        vec2 v0 = vec2(head_pos_tl.x + currentCursor.z * isTopRightLeading, head_pos_tl.y - currentCursor.w);
        vec2 v1 = vec2(head_pos_tl.x + currentCursor.z * isBottomLeftLeading, head_pos_tl.y);
        vec2 v2 = vec2(tail_pos_tl.x + currentCursor.z * isBottomLeftLeading, tail_pos_tl.y);
        vec2 v3 = vec2(tail_pos_tl.x + currentCursor.z * isTopRightLeading, tail_pos_tl.y - previousCursor.w);

        float sdfTrail_diag = getSdfParallelogram(vu, v0, v1, v2, v3);

        // Rectangle (straight)
        vec2 head_center = mix(centerCP, centerCC, head_eased);
        vec2 tail_center = mix(centerCP, centerCC, tail_eased);
        vec2 min_center = min(head_center, tail_center);
        vec2 max_center = max(head_center, tail_center);
        vec2 box_size = (max_center - min_center) + currentCursor.zw;
        vec2 box_center = (min_center + max_center) * 0.5;
        float sdfTrail_rect = getSdfRectangle(vu, box_center, box_size * 0.5);

        float sdfTrail = mix(sdfTrail_diag, sdfTrail_rect, isStraightMove);

        // -- Miku teal trail with glow --
        float trailAlpha = antialias(sdfTrail);

        // Inner glow: brighter cyan at center, teal at edges
        float glowDist = max(sdfTrail, 0.0);
        float glow = exp(-glowDist * 150.0) * GLOW_INTENSITY * (1.0 - progress);
        vec3 trailColor = mix(MIKU_CYAN, MIKU_TEAL, smoothstep(0.0, 0.01, glowDist));

        vec4 trailVec = vec4(trailColor, 0.7);
        newColor = mix(newColor, trailVec, trailAlpha);

        // Glow halo
        vec3 glowColor = mix(MIKU_TEAL, MIKU_PINK, 0.15);
        newColor.rgb += glowColor * glow;

        // -- Digital scatter particles along trail --
        vec2 trailDir = normalize(delta);
        float fadeParticle = 1.0 - progress;

        for (float i = 0.0; i < PARTICLE_COUNT; i += 1.0) {
            float seed = i * 13.37 + iTimeCursorChange * 100.0;
            float t = hash1(seed) * 0.8 + 0.1; // position along trail
            vec2 basePos = mix(centerCP, centerCC, t);

            // Scatter perpendicular to trail direction
            vec2 perp = vec2(-trailDir.y, trailDir.x);
            float scatter = (hash1(seed + 1.0) - 0.5) * 0.03;
            // Drift outward over time
            float drift = progress * 0.015 * (hash1(seed + 2.0) - 0.5);

            vec2 particlePos = basePos + perp * (scatter + drift);
            // Add slight movement along trail
            particlePos += trailDir * (progress * 0.01 * hash1(seed + 3.0));

            float pSize = PARTICLE_SIZE * (1.0 - progress * 0.7) * (0.5 + hash1(seed + 4.0));

            float particle = digitalParticle(vu, particlePos, pSize, seed);

            // Alternate between teal and pink
            float colorMix = step(0.75, hash1(seed + 5.0));
            vec3 pColor = mix(MIKU_TEAL, MIKU_PINK, colorMix);

            // Flicker effect
            float flicker = step(0.3, hash(particlePos * 100.0 + iTime * 5.0));
            particle *= flicker * fadeParticle;

            newColor.rgb = mix(newColor.rgb, pColor, particle * 0.8);
        }

        // Punch hole for cursor
        newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.0));
    }

    fragColor = newColor;
}
