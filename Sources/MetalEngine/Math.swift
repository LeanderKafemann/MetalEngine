import simd

// MARK: - Matrix construction helpers
// All matrices are column-major, matching Metal's expectations.

enum Mat4 {

    static func identity() -> float4x4 {
        matrix_identity_float4x4
    }

    static func translation(_ t: SIMD3<Float>) -> float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
        return m
    }

    static func scale(_ s: SIMD3<Float>) -> float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0.x = s.x
        m.columns.1.y = s.y
        m.columns.2.z = s.z
        return m
    }

    static func rotation(radians: Float, axis: SIMD3<Float>) -> float4x4 {
        let a = normalize(axis)
        let c = cos(radians)
        let s = sin(radians)
        let t = 1 - c

        let x = a.x, y = a.y, z = a.z

        return float4x4(
            SIMD4<Float>(t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
            SIMD4<Float>(t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
            SIMD4<Float>(t * x * z + y * s, t * y * z - x * s, t * z * z + c,     0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }

    /// Right-handed perspective projection matching Metal's clip space (z in [0,1]).
    static func perspective(fovyRadians fovy: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = far / zRange
        let wzScale = -near * far / zRange

        return float4x4(
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, 1),
            SIMD4<Float>(0, 0, wzScale, 0)
        )
    }

    /// Right-handed look-at view matrix.
    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        let translateX = -dot(x, eye)
        let translateY = -dot(y, eye)
        let translateZ = -dot(z, eye)

        return float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(translateX, translateY, translateZ, 1)
        )
    }

    /// Upper-left 3x3 of a matrix, inverse-transposed — correct for transforming normals
    /// under non-uniform scale.
    static func normalMatrix(from m: float4x4) -> float3x3 {
        let upper = float3x3(
            SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
            SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
            SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        )
        return upper.inverse.transpose
    }
}
