# The Last Light (Godot)

Godot 4.7 port of *The Last Light*, a chapter-based 2D action RPG and platformer, targeting iOS,
macOS, Windows and Steam. It is written in statically typed GDScript.

The original Swift/SpriteKit game (tag `swift-final`) is the reference implementation. The
gameplay simulation is ported as a deterministic 60 Hz model in plain GDScript and checked against
the Swift simulation frame by frame (64-bit floats, SHA-256 state hash). Godot draws the scene and
reads input; it does not run the gameplay physics.

- `spikes/`: the language spike that chose GDScript, plus the parity-hash reference (`spikes/gdspike/sim.gd`).
