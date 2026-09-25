# MetalEngine

A minimal but complete Metal rendering engine for macOS on Apple Silicon,
built as a plain Swift Package (no Xcode project file needed). It opens a
window, spins up an `MTKView`, and renders a small lit scene (ground plane +
a rotating cube + a bobbing sphere) with a Blinn-Phong shader, depth testing,
and a free-flying camera.

## Requirements

- macOS 27 on Apple Silicon (or any Metal-capable Mac)
- Xcode 27 / Swift 5.9+ command line tools

## Build & run

```bash
swift run -c release
```

The first build compiles `Shaders/Shaders.metal` into a `.metallib` as an
SPM resource automatically — no separate build step required.

If you'd rather use Xcode: `File > Open` on the `MetalEngine` folder (or
`swift package generate-xcodeproj` on older toolchains) opens it as a normal
Swift Package project you can run from the IDE.

## Controls

| Input                | Action              |
|-----------------------|---------------------|
| `W` / `A` / `S` / `D`  | Move forward/left/back/right |
| `Q` / `E`              | Move down/up |
| Hold `Shift`           | Move faster |
| Right-click + drag     | Look around |
| `Esc`                  | Quit |

## Project layout

```
Sources/MetalEngine/
  main.swift          — NSApplication/window/MTKView bootstrap, input forwarding
  Renderer.swift       — MTKViewDelegate: pipeline/depth state, per-frame draw loop
  Camera.swift          — free-fly camera (position, yaw/pitch, view/projection)
  InputHandler.swift    — held-key set + accumulated mouse-drag delta
  Mesh.swift            — procedural cube/plane/sphere generation, GPU buffers
  Math.swift            — simd matrix helpers (perspective, lookAt, rotation…)
  ShaderTypes.swift     — CPU-side structs that mirror the GPU-side ones
  Shaders/Shaders.metal — vertex + fragment shaders (Blinn-Phong lighting)
```

## How it fits together

- **Vertex layout**: `Vertex` in `ShaderTypes.swift` is the single source of
  truth for mesh data. `Renderer.buildVertexDescriptor()` reads real field
  offsets via `MemoryLayout<Vertex>.offset(of:)`, so the GPU-side
  `[[stage_in]]` struct in the shader stays correct even if Swift's struct
  padding changes — you never hand-compute offsets.
- **Per-draw uniforms**: model/view/projection matrices and per-object
  material color are pushed with `setVertexBytes`/`setFragmentBytes`, which
  copy the struct straight into the command buffer's own storage. That
  avoids a common bug where a single reused `MTLBuffer` gets overwritten by
  a later draw call before the GPU has actually consumed the earlier one.
- **Frame pacing**: a `DispatchSemaphore(value: 3)` caps how many frames of
  GPU work can be in flight, so input latency doesn't grow unbounded if the
  GPU falls behind.
- **Scene**: `Renderer.buildScene()` is just an array of `SceneObject`
  (mesh + transform + color + optional per-frame animation closure) — add
  more objects there, or swap in your own meshes via `Mesh.cube/plane/sphere`
  or by writing your own `Vertex` arrays.

## Extending this into a bigger engine

This is deliberately a solid core, not a kitchen sink. Natural next steps,
roughly in order of how most people build these up:

1. **Texturing** — add a `texture` field to `Vertex`/material, load with
   `MTKTextureLoader`, sample in the fragment shader.
2. **Model loading** — swap procedural meshes for a `.obj`/`glTF` loader
   (e.g. via [Model I/O](https://developer.apple.com/documentation/modelio))
   that fills the same `Vertex` layout.
3. **Multiple lights** — replace the single `lightPosition`/`lightColor` in
   `FragmentUniforms` with an array uploaded as a buffer, loop in the shader.
4. **Shadow mapping** — a second depth-only render pass from the light's
   point of view, sampled in the main fragment shader.
5. **Instancing** — for many copies of the same mesh, use
   `drawIndexedPrimitives(... instanceCount:)` with a per-instance transform
   buffer instead of one draw call per object.
6. **Compute passes** — Metal's compute pipeline (particles, culling, post
   processing) plugs into the same `MTLCommandBuffer`/`MTLCommandQueue` you
   already have here.
