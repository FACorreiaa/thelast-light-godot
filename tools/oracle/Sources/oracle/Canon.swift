import ActionCore
import CryptoKit
import Foundation

/// The canonical form of simulation state that both engines hash. The GDScript port builds the
/// same tree by hand (`to_canon()` on each sim class); this side builds it by reflection.
///
/// Rules (mirrored in `sim/canon.gd`):
/// - Structs are objects keyed by their Swift property names, written in byte order of the key.
/// - Enums without a payload are their case name. Enums with one are objects:
///   `{"case": name, <label or _n>: value, ...}`.
/// - Optionals are their value or null. Sets are sorted arrays. Int-keyed dictionaries are
///   objects keyed by the decimal key.
/// - UInt64 (the RNG state) is stored as its Int64 bit pattern.
indirect enum Canon {
    case null
    case bool(Bool)
    case int(Int64)
    case float(Double)
    case string(String)
    case array([Canon])
    case object([(String, Canon)])

    /// Properties left out because they never change after the world is built, or belong to the
    /// data files rather than the state.
    static let skip: [String: Set<String>] = [
        "World": ["tuning", "arena", "level", "platforms", "gatePlatform", "waves"],
        "Fighter": ["spec"],
    ]

    static func of(_ value: Any) -> Canon {
        switch value {
        case let v as Double: return .float(v)
        case let v as Int: return .int(Int64(v))
        case let v as UInt64: return .int(Int64(bitPattern: v))
        case let v as Bool: return .bool(v)
        case let v as String: return .string(v)
        default: break
        }
        let m = Mirror(reflecting: value)
        switch m.displayStyle {
        case .optional:
            return m.children.first.map { of($0.value) } ?? .null
        case .collection, .tuple:
            return .array(m.children.map { of($0.value) })
        case .set:
            return .array(m.children.map { of($0.value) }.sorted(by: lessThan))
        case .dictionary:
            let pairs = m.children.map { c -> (String, Canon) in
                let kv = Mirror(reflecting: c.value).children.map(\.value)
                return (String(describing: kv[0]), of(kv[1]))
            }
            return .object(sortedPairs(pairs))
        case .enum:
            guard let payload = m.children.first else { return .string(String(describing: value)) }
            var pairs: [(String, Canon)] = [("case", .string(payload.label ?? "?"))]
            let pm = Mirror(reflecting: payload.value)
            if pm.displayStyle == .tuple {
                for (n, c) in pm.children.enumerated() {
                    let label = c.label.flatMap { $0.hasPrefix(".") ? nil : $0 } ?? "_\(n)"
                    pairs.append((label, of(c.value)))
                }
            } else {
                pairs.append(("_0", of(payload.value)))
            }
            return .object(sortedPairs(pairs))
        default:
            let typeName = String(describing: type(of: value))
            let skipped = skip[typeName] ?? []
            if m.children.isEmpty { return .string(typeName) }
            let pairs = m.children.compactMap { c -> (String, Canon)? in
                guard let label = c.label, !skipped.contains(label) else { return nil }
                return (label, of(c.value))
            }
            return .object(sortedPairs(pairs))
        }
    }

    private static func sortedPairs(_ p: [(String, Canon)]) -> [(String, Canon)] {
        p.sorted { $0.0.utf8.lexicographicallyPrecedes($1.0.utf8) }
    }

    private static func lessThan(_ a: Canon, _ b: Canon) -> Bool {
        switch (a, b) {
        case let (.int(x), .int(y)): x < y
        case let (.string(x), .string(y)): x.utf8.lexicographicallyPrecedes(y.utf8)
        default: false
        }
    }

    // MARK: Encoding

    func encode(into d: inout Data) {
        switch self {
        case .null: d.append(UInt8(ascii: "n"))
        case .bool(let v): d.append(UInt8(ascii: "b")); d.append(v ? 1 : 0)
        case .int(let v): d.append(UInt8(ascii: "i")); Canon.le(UInt64(bitPattern: v), &d)
        case .float(let v): d.append(UInt8(ascii: "f")); Canon.le(v.bitPattern, &d)
        case .string(let s): d.append(UInt8(ascii: "s")); Canon.str(s, &d)
        case .array(let a):
            d.append(UInt8(ascii: "a")); Canon.le32(UInt32(a.count), &d)
            for x in a { x.encode(into: &d) }
        case .object(let o):
            d.append(UInt8(ascii: "o")); Canon.le32(UInt32(o.count), &d)
            for (k, v) in o { Canon.str(k, &d); v.encode(into: &d) }
        }
    }

    private static func le(_ v: UInt64, _ d: inout Data) {
        for i in 0..<8 { d.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(i)))) }
    }

    private static func le32(_ v: UInt32, _ d: inout Data) {
        for i in 0..<4 { d.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) }
    }

    private static func str(_ s: String, _ d: inout Data) {
        let bytes = Array(s.utf8)
        le32(UInt32(bytes.count), &d)
        d.append(contentsOf: bytes)
    }

    /// First 8 bytes of SHA-256 over the encoding, as hex.
    var hash: String {
        var d = Data()
        encode(into: &d)
        return SHA256.hash(data: d).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// JSON for reading a state by eye or diffing it key by key. Doubles carry their bits so
    /// nothing is lost to decimal printing.
    var json: String {
        switch self {
        case .null: "null"
        case .bool(let v): v ? "true" : "false"
        case .int(let v): String(v)
        case .float(let v): "\"f:\(v):\(String(v.bitPattern, radix: 16))\""
        case .string(let s): JSON.quote(s)
        case .array(let a): "[" + a.map(\.json).joined(separator: ",") + "]"
        case .object(let o): "{" + o.map { JSON.quote($0.0) + ":" + $0.1.json }.joined(separator: ",") + "}"
        }
    }
}
