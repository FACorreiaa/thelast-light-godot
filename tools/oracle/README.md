# Parity oracle

Runs the Swift reference simulation (game-proto at tag `swift-final`, checked out as a sibling of
this repo at `../game-proto`) and writes what the GDScript port is checked against:

```
swift build -c release --package-path tools/oracle
tools/oracle/.build/release/oracle export .   # data/levels/*.json, data/tuning.json, data/index.json
tools/oracle/.build/release/oracle trace .    # tests/golden/*.trace (Autopilot runs)
tools/oracle/.build/release/oracle dump <run id> <frame>   # canonical state JSON after <frame> steps
```

The generated files are committed, so CI and anyone without game-proto can run the parity tests.

## Trace format
Line 1 is a JSON header (`id`, `level`, `lead`, `seed`, `fights`, `sturdy`, `frames`, `complete`).
Line 2 is the state hash before the first step. Each later line is one step:
`<state hash after the step> <moveX> <flags> [events JSON]`. Flags are
`jump jumpHeld attack dodge special switchHero` as 0/1.

## State hash
The canonical state tree (`Sources/oracle/Canon.swift`) is every stored property of `World` and its
fighters, except data that never changes after the world is built (`tuning`, `level`, `platforms`,
`gatePlatform`, `waves`, `arena`, each fighter's `spec`). Objects are keyed by the Swift property
names, sorted by key bytes. Enums without a payload are their case name; with one they are
`{"case": name, ...}`. Sets are sorted arrays; Int-keyed dictionaries are objects keyed by the
decimal key. Encoding: tagged little-endian binary (`n`, `b`, `i` int64, `f` float64 bits, `s`,
`a`, `o`), hashed with SHA-256, first 8 bytes as hex. The GDScript side builds the same tree with
`to_canon()`.
