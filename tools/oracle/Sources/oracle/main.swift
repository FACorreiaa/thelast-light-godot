import ActionCore
import LastLightCore
import Foundation

// oracle export <repo>           writes data/levels/*.json, data/tuning.json, data/chapters.json
// oracle trace  <repo>           writes tests/golden/*.trace from Autopilot runs
// oracle dump   <run> <frame>    prints the canonical state after <frame> steps of a run

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else {
    FileHandle.standardError.write("usage: oracle export|trace <repo> | dump <run> <frame>\n".data(using: .utf8)!)
    exit(2)
}

/// "The Warden's Gate" → "wardens_gate".
func slug(_ name: String) -> String {
    var words = name.lowercased().filter { $0 != "'" && $0 != "’" }
        .map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        .split(separator: "_")
    if words.count > 1, words.first == "the" { words.removeFirst() }
    return words.joined(separator: "_")
}

func write(_ text: String, to path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! (text + "\n").write(to: url, atomically: true, encoding: .utf8)
}

// MARK: Runs

/// One scripted run of a level. The same list drives the Swift traces and the GDScript replay.
struct Run {
    /// Nil for the training room.
    var level: Level?
    var lead: FighterKind
    var seed: UInt64
    var fights: Bool
    /// Heroes get health to spare, as in the Swift level tests, so the run is about the route.
    var sturdy: Bool
    var frames: Int
    /// "level", or a training room: "feel" (Caelen and waves) or "partner" (with Orion).
    var room = "level"
    /// Nil: the Autopilot drives. "brawl": a fixed input pattern by frame that mashes buttons, to reach
    /// what a good player avoids (losing, ringing bells out of order, a sworn twin raised).
    var script: String?
    /// Tuning.heroDamageScale for the run.
    var damageScale = 1.0

    var id: String {
        var base = room == "level"
            ? "\(slug(level!.name))-\(lead.rawValue)-s\(seed)-\(fights ? "fight" : "walk")\(sturdy ? "" : "-real")"
            : "training_\(room)-s\(seed)"
        if let script { base += "-\(script)" }
        if damageScale != 1 { base += "-x\(Int(damageScale))" }
        return base
    }

    var tuning: Tuning {
        var t = Tuning()
        if sturdy {
            t.caelen.maxHP = 100_000
            t.seraphine.maxHP = 100_000
            t.nimue.maxHP = 100_000
        }
        t.heroDamageScale = damageScale
        return t
    }

    func makeWorld() -> World {
        switch room {
        case "feel": World.feelSlice(seed: seed, tuning: tuning)
        case "partner": World.partnerSlice(seed: seed, tuning: tuning)
        default: World(level: level!, hero: lead, tuning: tuning, seed: seed)
        }
    }

    func input(_ world: World, _ pilot: inout Autopilot) -> InputFrame {
        guard script == "brawl" else { return pilot.input(for: world) }
        let f = world.frame
        return InputFrame(moveX: (f / 180) % 3 == 2 ? -1 : 1, jump: f % 61 == 0, jumpHeld: f % 61 < 10,
                          attack: f % 7 == 0, dodge: f % 89 == 0, special: f % 240 == 0, switchHero: f % 900 == 450)
    }
}

let allRuns: [Run] = {
    var runs: [Run] = []
    let frames = 60 * 240
    for level in Level.all {
        runs.append(Run(level: level, lead: .caelen, seed: 1, fights: true, sturdy: true, frames: frames))
        runs.append(Run(level: level, lead: .caelen, seed: 1, fights: false, sturdy: true, frames: frames))
    }
    for lead in [FighterKind.seraphine, .nimue] {
        for level in Level.chapter1(for: lead) {
            runs.append(Run(level: level, lead: lead, seed: 1, fights: true, sturdy: true, frames: frames))
        }
    }
    // Real health: these can be lost, which exercises death, retries and game over.
    for level in [Level.foundryYard, .machineHall, .emberMarket, .pilgrimRoad] {
        runs.append(Run(level: level, lead: .caelen, seed: 7, fights: true, sturdy: false, frames: 60 * 120))
    }
    // Branches the Autopilot never reaches.
    runs.append(Run(level: nil, lead: .caelen, seed: 3, fights: true, sturdy: false, frames: 60 * 150, room: "feel", script: "brawl"))
    runs.append(Run(level: nil, lead: .caelen, seed: 4, fights: true, sturdy: false, frames: 60 * 150, room: "partner", script: "brawl"))
    for seed: UInt64 in [8, 9] {
        runs.append(Run(level: nil, lead: .caelen, seed: seed, fights: true, sturdy: false, frames: 60 * 150, room: "partner", script: "brawl", damageScale: 2))
    }
    runs.append(Run(level: .bellTower, lead: .caelen, seed: 2, fights: true, sturdy: true, frames: 60 * 120, script: "brawl"))
    runs.append(Run(level: .cloisterGate, lead: .caelen, seed: 2, fights: true, sturdy: true, frames: 60 * 150, script: "brawl"))
    runs.append(Run(level: .theProtocol, lead: .caelen, seed: 5, fights: true, sturdy: false, frames: 60 * 120, damageScale: 4))
    runs.append(Run(level: .wardensGate, lead: .nimue, seed: 6, fights: true, sturdy: false, frames: 60 * 120, damageScale: 3))
    return runs
}()

/// A double as its int64 bit pattern: exact, and no decimal parser in between.
func bits(_ v: Double) -> String { String(Int64(bitPattern: v.bitPattern)) }

func inputText(_ i: InputFrame) -> String {
    let flags = [i.jump, i.jumpHeld, i.attack, i.dodge, i.special, i.switchHero].map { $0 ? "1" : "0" }.joined()
    return "\(bits(i.moveX)) \(flags)"
}

// MARK: Commands

switch command {
case "export":
    let repo = args.dropFirst().first ?? "."
    var index: [String] = []
    for level in Level.all {
        let name = slug(level.name)
        precondition(!index.contains(name), "two levels slug to \(name)")
        index.append(name)
        write(JSON.write(level), to: "\(repo)/data/levels/\(name).json")
    }
    write(JSON.write(Tuning()), to: "\(repo)/data/tuning.json")

    var chapters: [[String: Any]] = []
    for c in Chapter.all {
        var route: [String: [String]] = [:]
        for lead in [FighterKind.caelen, .seraphine, .nimue] { route[lead.rawValue] = c.levels(for: lead).map { slug($0.name) } }
        chapters.append(["id": c.id, "number": c.number, "title": c.title, "ending": c.ending, "route": route])
    }
    let meta: [String: Any] = [
        "swiftTag": "swift-final",
        "levels": index,
        "chapters": chapters,
        "fighterKinds": FighterKind.allCases.map(\.rawValue),
        "factions": Faction.allCases.map { ["id": $0.rawValue, "lead": $0.lead.rawValue, "opening": slug($0.opening.name)] },
    ]
    write(JSON.write(meta), to: "\(repo)/data/index.json")

    // Every decimal written above with its bits, so the port can prove its JSON reader is exact.
    let pairs = JSON.doublesSeen.sorted { $0.key < $1.key }.map { [$0.key, String($0.value, radix: 16)] }
    write(JSON.write(pairs, indent: false), to: "\(repo)/tests/golden/doubles.json")
    print("exported \(index.count) levels, \(Chapter.all.count) chapters, \(pairs.count) distinct doubles")

case "trace":
    let repo = args.dropFirst().first ?? "."
    var list: [String] = []
    for run in allRuns {
        var world = run.makeWorld()
        var pilot = Autopilot(fights: run.fights)
        var lines: [String] = []
        lines.append(Canon.of(world).hash)
        for _ in 0..<run.frames where !world.isOver {
            let input = run.input(world, &pilot)
            let events = world.step(input)
            var line = "\(Canon.of(world).hash) \(inputText(input))"
            if !events.isEmpty { line += " " + Canon.of(events).json }
            lines.append(line)
        }
        let header: [String: Any] = [
            "id": run.id, "level": run.level.map { slug($0.name) } ?? "", "lead": run.lead.rawValue, "seed": run.seed,
            "fights": run.fights, "sturdy": run.sturdy, "frames": lines.count - 1, "room": run.room,
            "script": run.script ?? "", "damageScale": run.damageScale,
            "complete": world.isComplete, "over": world.isOver,
        ]
        write(JSON.write(header, indent: false) + "\n" + lines.joined(separator: "\n"),
              to: "\(repo)/tests/golden/\(run.id).trace")
        list.append(run.id)
        var cases = Set<String>()
        for l in lines { if let r = l.range(of: "\"case\":\"") { _ = r; for m in l.components(separatedBy: "\"case\":\"").dropFirst() { cases.insert(String(m.prefix { $0 != "\"" })) } } }
        let rare = ["waveStarted", "waveCleared", "revived", "heroDown", "discord", "raised", "faded", "eclipsed"].filter(cases.contains)
        print("\(run.id): \(lines.count - 1) frames, complete \(world.isComplete)\(rare.isEmpty ? "" : " " + rare.joined(separator: ","))")
    }
    write(JSON.write(list), to: "\(repo)/tests/golden/runs.json")

case "rng":
    // Swift's stdlib turns raw SplitMix64 output into ranges with its own algorithms (Lemire's
    // multiply-shift with rejection for integers). Record a mixed sequence so the port matches them.
    let repo = args.dropFirst().first ?? "."
    var lines: [String] = []
    for seed: UInt64 in [0, 1, 7, 0xDEAD_BEEF_CAFE_F00D] {
        var rng = SeededRandom(seed: seed)
        func state() -> String { String(Int64(bitPattern: field(rng, "state") as! UInt64)) }
        lines.append("seed \(Int64(bitPattern: seed)) \(state())")
        for n in 0..<400 {
            switch n % 7 {
            case 0: lines.append("next \(Int64(bitPattern: rng.next())) \(state())")
            case 1:
                let lo = [0, 3, 30, 90, -5][n % 5], hi = lo + [0, 1, 7, 60, 400][(n / 6) % 5]
                lines.append("closed \(lo) \(hi) \(Int.random(in: lo...hi, using: &rng)) \(state())")
            case 2:
                let count = [1, 2, 3, 5, 7, 1000][(n / 6) % 6]
                lines.append("half 0 \(count) \(Int.random(in: 0..<count, using: &rng)) \(state())")
            case 3: lines.append("unit \(bits(Double.random(in: 0..<1, using: &rng))) \(state())")
            case 4:
                let lo = [0.0, 120.0, -40.5][n % 3], hi = lo + [1.0, 900.0, 1233.7][(n / 6) % 3]
                lines.append("double \(bits(lo)) \(bits(hi)) \(bits(Double.random(in: lo..<hi, using: &rng))) \(state())")
            case 5:
                let lo = [40.0, 0.0, -300.25][n % 3], hi = lo + [1320.0, 0.5, 77.125][(n / 7) % 3]
                lines.append("dclosed \(bits(lo)) \(bits(hi)) \(bits(Double.random(in: lo...hi, using: &rng))) \(state())")
            default: lines.append("bool \(Bool.random(using: &rng) ? 1 : 0) \(state())")
            }
        }
    }
    write(lines.joined(separator: "\n"), to: "\(repo)/tests/golden/rng.txt")
    print("rng: \(lines.count) lines")

case "story":
    // Every scene played under several choice policies and starting flags: the lines shown, the
    // choices offered, and the state at the end. The GDScript Story runner must give the same.
    let repo = args.dropFirst().first ?? "."
    var scenes: [String: StoryScene] = [:]
    for c in Chapter.all {
        let url = URL(fileURLWithPath: "\(repo)/data/story/\(c.id).json")
        guard let data = try? Data(contentsOf: url), let lib = try? StoryLibrary(json: data) else { continue }
        scenes.merge(lib.scenes) { first, _ in first }
    }
    let library = StoryLibrary(scenes: scenes)
    // Every flag value any choice or line can set, so later scenes see each branch.
    var values: [String: Set<String>] = [:]
    for scene in scenes.values {
        for line in scene.lines.values {
            for (k, v) in line.set ?? [:] { values[k, default: []].insert(v) }
            for ch in line.choices ?? [] { for (k, v) in ch.set ?? [:] { values[k, default: []].insert(v) } }
            for (k, v) in line.requires ?? [:] { values[k, default: []].insert(v) }
            for ch in line.choices ?? [] { for (k, v) in ch.requires ?? [:] { values[k, default: []].insert(v) } }
        }
    }
    let keys = values.keys.sorted()
    var starts: [StoryState] = [StoryState()]
    for n in 0..<4 {
        var st = StoryState()
        for k in keys {
            let vs = values[k]!.sorted()
            st.flags[k] = vs[n % vs.count]
        }
        starts.append(st)
    }
    for lead in ["caelen", "seraphine", "nimue"] {
        var st = StoryState()
        st.flags["lead"] = lead
        starts.append(st)
    }
    var out: [[String: Any]] = []
    for id in scenes.keys.sorted() {
        for (si, start) in starts.enumerated() {
            for policy in 0..<3 {
                guard var runner = StoryRunner(sceneID: id, library: library, state: start) else { continue }
                var steps: [String] = []
                var n = 0
                while let line = runner.line, n < 200 {
                    let offered = runner.choices
                    steps.append("\(line.speaker)|\(line.text)|\(offered.map(\.text).joined(separator: "/"))")
                    if offered.isEmpty { runner.advance() } else { runner.choose((n + policy) % offered.count) }
                    n += 1
                }
                out.append(["scene": id, "start": si, "policy": policy, "startFlags": start.flags,
                            "steps": steps, "flags": runner.state.flags, "seen": runner.state.seen.sorted()])
            }
        }
    }
    write(JSON.write(["problems": library.problems(), "runs": out], indent: false), to: "\(repo)/tests/golden/story.json")
    print("story: \(scenes.count) scenes, \(out.count) runs, \(library.problems().count) problems")

case "dump":
    let rest = Array(args.dropFirst())
    guard rest.count == 2, let run = allRuns.first(where: { $0.id == rest[0] }), let target = Int(rest[1]) else {
        print("usage: oracle dump <run id> <frame>")
        exit(2)
    }
    var world = run.makeWorld()
    var pilot = Autopilot(fights: run.fights)
    for _ in 0..<target where !world.isOver { _ = world.step(run.input(world, &pilot)) }
    print(Canon.of(world).json)

default:
    print("unknown command \(command)")
    exit(2)
}
