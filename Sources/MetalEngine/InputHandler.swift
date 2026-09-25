import Foundation

/// macOS virtual key codes used by the engine. (Layout-independent codes,
/// per Carbon's HIToolbox/Events.h — stable across keyboard layouts for the
/// physical W/A/S/D/Q/E keys.)
enum KeyCode {
    static let w: UInt16 = 13
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let q: UInt16 = 12
    static let e: UInt16 = 14
    static let shift: UInt16 = 56
    static let escape: UInt16 = 53
}

/// Tracks currently-held keys and mouse-drag deltas. Simple value store;
/// the AppKit view forwards raw events into it, and Renderer/Camera poll it.
final class InputHandler {
    private(set) var heldKeys = Set<UInt16>()

    var isRightMouseDown = false
    private(set) var pendingMouseDeltaX: Float = 0
    private(set) var pendingMouseDeltaY: Float = 0

    func keyDown(_ code: UInt16) {
        heldKeys.insert(code)
    }

    func keyUp(_ code: UInt16) {
        heldKeys.remove(code)
    }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        guard isRightMouseDown else { return }
        pendingMouseDeltaX += deltaX
        pendingMouseDeltaY += deltaY
    }

    /// Called once per frame by the renderer; returns and clears accumulated
    /// mouse motion so drags are consumed exactly once per frame.
    func consumeMouseDelta() -> (dx: Float, dy: Float) {
        let d = (pendingMouseDeltaX, pendingMouseDeltaY)
        pendingMouseDeltaX = 0
        pendingMouseDeltaY = 0
        return d
    }
}
