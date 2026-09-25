import Cocoa
import MetalKit

/// MTKView subclass that owns keyboard/mouse capture and forwards raw events
/// to the shared InputHandler so the Camera can consume them.
final class EngineView: MTKView {

    var input: InputHandler?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape {
            NSApp.terminate(nil)
            return
        }
        input?.keyDown(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        input?.keyUp(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        // Track Shift specifically, since it arrives as a flagsChanged event
        // rather than keyDown/keyUp.
        if event.modifierFlags.contains(.shift) {
            input?.keyDown(KeyCode.shift)
        } else {
            input?.keyUp(KeyCode.shift)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        input?.isRightMouseDown = true
        NSCursor.hide()
    }

    override func rightMouseUp(with event: NSEvent) {
        input?.isRightMouseDown = false
        NSCursor.unhide()
    }

    override func mouseDragged(with event: NSEvent) {
        forwardDrag(event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        forwardDrag(event)
    }

    private func forwardDrag(_ event: NSEvent) {
        input?.mouseDragged(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow!
    private var renderer: Renderer!
    private var mtkView: EngineView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This Mac does not support Metal.")
        }

        let contentRect = NSRect(x: 0, y: 0, width: 1280, height: 800)
        window = NSWindow(contentRect: contentRect,
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered,
                           defer: false)
        window.title = "Metal Engine — WASD to move, right-click + drag to look, Esc to quit"
        window.center()

        mtkView = EngineView(frame: contentRect, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearDepth = 1.0
        mtkView.preferredFramesPerSecond = 60

        renderer = Renderer(device: device)
        mtkView.input = renderer.input
        mtkView.delegate = renderer

        window.contentView = mtkView
        window.makeFirstResponder(mtkView)
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
