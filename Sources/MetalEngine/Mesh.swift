import Metal
import simd

/// A GPU-resident mesh: a vertex buffer, an index buffer, and the index count
/// needed to issue a draw call.
final class Mesh {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    init(device: MTLDevice, vertices: [Vertex], indices: [UInt16]) {
        guard let vb = device.makeBuffer(bytes: vertices,
                                          length: vertices.count * MemoryLayout<Vertex>.stride,
                                          options: .storageModeShared) else {
            fatalError("Failed to create vertex buffer")
        }
        guard let ib = device.makeBuffer(bytes: indices,
                                          length: indices.count * MemoryLayout<UInt16>.stride,
                                          options: .storageModeShared) else {
            fatalError("Failed to create index buffer")
        }
        vertexBuffer = vb
        indexBuffer = ib
        indexCount = indices.count
    }

    // MARK: - Procedural generators

    static func cube(device: MTLDevice, size: Float = 1.0) -> Mesh {
        let h = size * 0.5

        // Each face has its own 4 vertices so normals stay flat-shaded per face.
        struct Face { let normal: SIMD3<Float>; let corners: [SIMD3<Float>] }
        let faces: [Face] = [
            Face(normal: [ 0,  0,  1], corners: [[-h,-h, h],[ h,-h, h],[ h, h, h],[-h, h, h]]), // +Z
            Face(normal: [ 0,  0, -1], corners: [[ h,-h,-h],[-h,-h,-h],[-h, h,-h],[ h, h,-h]]), // -Z
            Face(normal: [ 1,  0,  0], corners: [[ h,-h, h],[ h,-h,-h],[ h, h,-h],[ h, h, h]]), // +X
            Face(normal: [-1,  0,  0], corners: [[-h,-h,-h],[-h,-h, h],[-h, h, h],[-h, h,-h]]), // -X
            Face(normal: [ 0,  1,  0], corners: [[-h, h, h],[ h, h, h],[ h, h,-h],[-h, h,-h]]), // +Y
            Face(normal: [ 0, -1,  0], corners: [[-h,-h,-h],[ h,-h,-h],[ h,-h, h],[-h,-h, h]])  // -Y
        ]

        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        let uvs: [SIMD2<Float>] = [[0,0],[1,0],[1,1],[0,1]]

        for face in faces {
            let base = UInt16(vertices.count)
            for i in 0..<4 {
                vertices.append(Vertex(position: face.corners[i], normal: face.normal, uv: uvs[i]))
            }
            indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
        }

        return Mesh(device: device, vertices: vertices, indices: indices)
    }

    static func plane(device: MTLDevice, size: Float = 10.0) -> Mesh {
        let h = size * 0.5
        let vertices: [Vertex] = [
            Vertex(position: [-h, 0, -h], normal: [0, 1, 0], uv: [0, 0]),
            Vertex(position: [ h, 0, -h], normal: [0, 1, 0], uv: [1, 0]),
            Vertex(position: [ h, 0,  h], normal: [0, 1, 0], uv: [1, 1]),
            Vertex(position: [-h, 0,  h], normal: [0, 1, 0], uv: [0, 1]),
        ]
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
        return Mesh(device: device, vertices: vertices, indices: indices)
    }

    static func sphere(device: MTLDevice, radius: Float = 1.0, latBands: Int = 24, lonBands: Int = 24) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        for lat in 0...latBands {
            let theta = Float(lat) * .pi / Float(latBands)
            let sinTheta = sin(theta), cosTheta = cos(theta)

            for lon in 0...lonBands {
                let phi = Float(lon) * 2 * .pi / Float(lonBands)
                let sinPhi = sin(phi), cosPhi = cos(phi)

                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta

                let normal = SIMD3<Float>(x, y, z)
                let position = normal * radius
                let uv = SIMD2<Float>(Float(lon) / Float(lonBands), Float(lat) / Float(latBands))
                vertices.append(Vertex(position: position, normal: normal, uv: uv))
            }
        }

        let stride = lonBands + 1
        for lat in 0..<latBands {
            for lon in 0..<lonBands {
                let first = UInt16(lat * stride + lon)
                let second = UInt16(first + UInt16(stride))
                indices.append(contentsOf: [first, second, first + 1,
                                             second, second + 1, first + 1])
            }
        }

        return Mesh(device: device, vertices: vertices, indices: indices)
    }
}
