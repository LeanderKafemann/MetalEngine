import simd

/// A free-flying camera controlled by WASD + mouse-look, similar to a
/// first-person editor camera.
final class Camera {
    var position: SIMD3<Float> = [0, 1.5, 6]
    var yaw: Float = -.pi / 2   // facing -Z initially
    var pitch: Float = 0

    var fovYRadians: Float = 60 * .pi / 180
    var nearPlane: Float = 0.05
    var farPlane: Float = 500

    var moveSpeed: Float = 4.0      // meters/second
    var lookSensitivity: Float = 0.0025

    private(set) var forward: SIMD3<Float> = [0, 0, -1]
    private(set) var right: SIMD3<Float> = [1, 0, 0]
    let worldUp: SIMD3<Float> = [0, 1, 0]

    init() {
        updateVectors()
    }

    private func updateVectors() {
        let clampedPitch = max(-.pi/2 + 0.01, min(.pi/2 - 0.01, pitch))
        pitch = clampedPitch

        forward = normalize(SIMD3<Float>(
            cos(pitch) * cos(yaw),
            sin(pitch),
            cos(pitch) * sin(yaw)
        ))
        right = normalize(cross(forward, worldUp))
    }

    func look(deltaX: Float, deltaY: Float) {
        yaw += deltaX * lookSensitivity
        pitch -= deltaY * lookSensitivity
        updateVectors()
    }

    /// Applies WASD + Q/E movement for the given frame time, using the
    /// currently-held-key set from the InputHandler.
    func update(deltaTime: Float, heldKeys: Set<UInt16>) {
        var delta = SIMD3<Float>(repeating: 0)

        if heldKeys.contains(KeyCode.w) { delta += forward }
        if heldKeys.contains(KeyCode.s) { delta -= forward }
        if heldKeys.contains(KeyCode.d) { delta += right }
        if heldKeys.contains(KeyCode.a) { delta -= right }
        if heldKeys.contains(KeyCode.e) { delta += worldUp }
        if heldKeys.contains(KeyCode.q) { delta -= worldUp }

        if length(delta) > 0 {
            delta = normalize(delta)
            var speed = moveSpeed
            if heldKeys.contains(KeyCode.shift) { speed *= 3.0 }
            position += delta * speed * deltaTime
        }
    }

    func viewMatrix() -> float4x4 {
        Mat4.lookAt(eye: position, center: position + forward, up: worldUp)
    }

    func projectionMatrix(aspect: Float) -> float4x4 {
        Mat4.perspective(fovyRadians: fovYRadians, aspect: aspect, near: nearPlane, far: farPlane)
    }
}
