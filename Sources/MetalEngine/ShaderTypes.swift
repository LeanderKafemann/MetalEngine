import simd

/// Per-draw uniforms uploaded to constant buffer index 1.
/// NOTE: Must byte-match the `Uniforms` struct in Shaders.metal exactly.
struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var normalMatrix: float3x3
}

/// Scene-wide lighting/material parameters uploaded to constant buffer index 2.
/// NOTE: Must byte-match `FragmentUniforms` in Shaders.metal exactly.
struct FragmentUniforms {
    var cameraPosition: SIMD3<Float>
    var lightPosition: SIMD3<Float>
    var lightColor: SIMD3<Float>
    var baseColor: SIMD3<Float>
}

/// CPU-side vertex layout. The actual GPU-visible field offsets come from
/// `MemoryLayout<Vertex>.offset(of:)` when building the MTLVertexDescriptor,
/// so this struct's Swift-side padding does not need to match MSL struct
/// packing rules — Metal's [[stage_in]] mechanism reads via the descriptor.
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
}
