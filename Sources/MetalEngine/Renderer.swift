import MetalKit
import simd

/// One instance in the scene: a mesh plus its transform and material color.
struct SceneObject {
    let mesh: Mesh
    var transform: float4x4
    var baseColor: SIMD3<Float>
    /// Optional per-frame animation hook, given elapsed time in seconds.
    var animate: ((Float) -> float4x4)?
}

final class Renderer: NSObject, MTKViewDelegate {

    // MARK: Core Metal objects
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState

    // Caps how many frames' worth of GPU work can be queued ahead of the CPU,
    // so input latency doesn't grow unbounded under load.
    private static let maxFramesInFlight = 3
    private let frameSemaphore = DispatchSemaphore(value: Renderer.maxFramesInFlight)

    // MARK: Scene state
    let camera = Camera()
    let input = InputHandler()
    private var objects: [SceneObject] = []
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var elapsedTime: Float = 0

    init(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            fatalError("Metal device cannot create a command queue")
        }
        commandQueue = queue

        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            fatalError("Could not load Shaders.metallib from the module bundle")
        }
        guard let vertexFn = library.makeFunction(name: "vertex_main"),
              let fragmentFn = library.makeFunction(name: "fragment_main") else {
            fatalError("Shader functions vertex_main/fragment_main not found")
        }

        let vertexDescriptor = Renderer.buildVertexDescriptor()

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFn
        pipelineDescriptor.fragmentFunction = fragmentFn
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to build render pipeline state: \(error)")
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            fatalError("Failed to build depth stencil state")
        }
        depthStencilState = depthState

        super.init()

        buildScene()
    }

    /// Describes how the GPU should read `Vertex` fields out of the raw vertex
    /// buffer. Offsets come straight from Swift's own memory layout, so this
    /// stays correct even if struct padding changes.
    private static func buildVertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()

        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position)!
        descriptor.attributes[0].bufferIndex = 0

        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.normal)!
        descriptor.attributes[1].bufferIndex = 0

        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.uv)!
        descriptor.attributes[2].bufferIndex = 0

        descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        descriptor.layouts[0].stepFunction = .perVertex

        return descriptor
    }

    private func buildScene() {
        let cube = Mesh.cube(device: device, size: 1.0)
        let sphere = Mesh.sphere(device: device, radius: 0.75)
        let ground = Mesh.plane(device: device, size: 20)

        objects.append(SceneObject(
            mesh: ground,
            transform: Mat4.translation([0, -1, 0]),
            baseColor: [0.35, 0.38, 0.42],
            animate: nil
        ))

        objects.append(SceneObject(
            mesh: cube,
            transform: Mat4.identity(),
            baseColor: [0.85, 0.25, 0.2],
            animate: { t in
                Mat4.translation([0, 0.2, 0]) * Mat4.rotation(radians: t, axis: [0, 1, 0])
            }
        ))

        objects.append(SceneObject(
            mesh: sphere,
            transform: Mat4.translation([2.2, 0, 0]),
            baseColor: [0.2, 0.55, 0.85],
            animate: { t in
                Mat4.translation([2.2, 0.2 + sin(t * 1.5) * 0.4, 0])
            }
        ))
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Aspect ratio is recomputed every frame from view.drawableSize, so
        // nothing needs to be cached here.
    }

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now
        elapsedTime += deltaTime

        // Apply accumulated mouse look and held-key movement before rendering.
        let (dx, dy) = input.consumeMouseDelta()
        if dx != 0 || dy != 0 {
            camera.look(deltaX: dx, deltaY: dy)
        }
        camera.update(deltaTime: deltaTime, heldKeys: input.heldKeys)

        frameSemaphore.wait()

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal()
            return
        }

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            frameSemaphore.signal()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)

        let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
        let viewMatrix = camera.viewMatrix()
        let projMatrix = camera.projectionMatrix(aspect: aspect)

        for object in objects {
            let model = object.animate?(elapsedTime) ?? object.transform

            var uniforms = Uniforms(
                modelMatrix: model,
                viewMatrix: viewMatrix,
                projectionMatrix: projMatrix,
                normalMatrix: Mat4.normalMatrix(from: model)
            )

            var fu = FragmentUniforms(
                cameraPosition: camera.position,
                lightPosition: [4, 6, 4],
                lightColor: [1.0, 0.98, 0.92],
                baseColor: object.baseColor
            )

            // setVertexBytes/setFragmentBytes copy this small struct straight
            // into the command buffer's own storage immediately, so each draw
            // call safely gets its own snapshot of the data — no manually
            // managed uniform buffer or frame-index bookkeeping required.
            encoder.setVertexBuffer(object.mesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&fu, length: MemoryLayout<FragmentUniforms>.stride, index: 2)

            encoder.drawIndexedPrimitives(type: .triangle,
                                           indexCount: object.mesh.indexCount,
                                           indexType: .uint16,
                                           indexBuffer: object.mesh.indexBuffer,
                                           indexBufferOffset: 0)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        commandBuffer.commit()
    }
}
