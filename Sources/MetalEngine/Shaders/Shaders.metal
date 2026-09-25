#include <metal_stdlib>
using namespace metal;

// NOTE: Must byte-match Uniforms / FragmentUniforms in ShaderTypes.swift exactly.

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3x3 normalMatrix;
};

struct FragmentUniforms {
    float3 cameraPosition;
    float3 lightPosition;
    float3 lightColor;
    float3 baseColor;
};

// Attribute indices here correspond to the offsets computed from the Swift
// `Vertex` struct via MemoryLayout.offset(of:) — see Renderer.buildVertexDescriptor().
struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct VertexOut {
    float4 clipPosition [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;

    float4 worldPos4 = uniforms.modelMatrix * float4(in.position, 1.0);
    float4 viewPos4  = uniforms.viewMatrix * worldPos4;

    out.clipPosition = uniforms.projectionMatrix * viewPos4;
    out.worldPosition = worldPos4.xyz;
    out.worldNormal = normalize(uniforms.normalMatrix * in.normal);
    out.uv = in.uv;

    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               constant FragmentUniforms &fu [[buffer(2)]]) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(fu.lightPosition - in.worldPosition);
    float3 V = normalize(fu.cameraPosition - in.worldPosition);
    float3 H = normalize(L + V);

    float ambientStrength = 0.12;
    float3 ambient = ambientStrength * fu.lightColor;

    float diff = max(dot(N, L), 0.0);
    float3 diffuse = diff * fu.lightColor;

    float spec = pow(max(dot(N, H), 0.0), 48.0);
    float3 specular = spec * fu.lightColor * 0.6;

    float3 color = (ambient + diffuse) * fu.baseColor + specular;

    // Simple gamma correction for a nicer-looking result on a linear framebuffer.
    color = pow(color, float3(1.0 / 2.2));

    return float4(color, 1.0);
}
