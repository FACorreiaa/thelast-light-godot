import ActionCore
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
    var level: Level
    var lead: FighterKind
    var seed: UInt64
    var fights: Bool
    /// Heroes get health to spare, as in the Swift level tests, so the run is about the route.
    var sturdy: Bool
    var frames: Int

    var id: String {
        "\(slug(level.name))-\(lead.rawValue)-s\(seed)-\(fights ? "fight" : "walk")\(sturdy ? "" : "-real")"
    }

    var tuning: Tuning {
        var t = Tuning()
        if sturdy {
            t.caelen.maxHP = 100_000
            t.seraphine.maxHP = 100_000
            t.nimue.maxHP = 100_000
        }
        return t
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
    return runs
}()

func inputText(_ i: InputFrame) -> String {
    let flags = [i.jump, i.jumpHeld, i.attack, i.dodge, i.special, i.switchHero].map { $0 ? "1" : "0" }.joined()
    return "\(JSON.number(i.moveX)) \(flags)"
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
        var world = World(level: run.level, hero: run.lead, tuning: run.tuning, seed: run.seed)
        var pilot = Autopilot(fights: run.fights)
        var lines: [String] = []
        lines.append(Canon.of(world).hash)
        for _ in 0..<run.frames where !world.isOver {
            let input = pilot.input(for: world)
            let events = world.step(input)
            var line = "\(Canon.of(world).hash) \(inputText(input))"
            if !events.isEmpty { line += " " + JSON.write(events, indent: false) }
            lines.append(line)
        }
        let header: [String: Any] = [
            "id": run.id, "level": slug(run.level.name), "lead": run.lead.rawValue, "seed": run.seed,
            "fights": run.fights, "sturdy": run.sturdy, "frames": lines.count - 1,
            "complete": world.isComplete, "over": world.isOver,
        ]
        write(JSON.write(header, indent: false) + "\n" + lines.joined(separator: "\n"),
              to: "\(repo)/tests/golden/\(run.id).trace")
        list.append(run.id)
        print("\(run.id): \(lines.count - 1) frames, complete \(world.isComplete)")
    }
    write(JSON.write(list), to: "\(repo)/tests/golden/runs.json")

case "dump":
    let rest = Array(args.dropFirst())
    guard rest.count == 2, let run = allRuns.first(where: { $0.id == rest[0] }), let target = Int(rest[1]) else {
        print("usage: oracle dump <run id> <frame>")
        exit(2)
    }
    var world = World(level: run.level, hero: run.lead, tuning: run.tuning, seed: run.seed)
    var pilot = Autopilot(fights: run.fights)
    for _ in 0..<target where !world.isOver { _ = world.step(pilot.input(for: world)) }
    print(Canon.of(world).json)

default:
    print("unknown command \(command)")
    exit(2)
}
