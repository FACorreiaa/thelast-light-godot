import Foundation

/// Writes any Swift value as JSON by reflection, so the Swift level and tuning literals can be
/// exported without changing game-proto.
///
/// - Structs become objects, keys in declaration order.
/// - Enums without a payload become their case name; enums with a payload become
///   `{"case": name, ...payload}`. Unlabelled payload values are keyed `_0`, `_1`, ….
/// - Sets are written sorted; dictionaries become objects with sorted string keys.
/// - Doubles use Swift's shortest round-trip form; non-finite doubles become strings.
enum JSON {
    static func write(_ value: Any, indent: Bool = true) -> String {
        var out = ""
        emit(value, into: &out, depth: 0, indent: indent)
        return out
    }

    /// Every distinct Double written, as (decimal text, bit pattern). The GDScript side checks that
    /// its JSON parser turns each text back into the same bits.
    nonisolated(unsafe) static var doublesSeen: [String: UInt64] = [:]

    private static func emit(_ value: Any, into out: inout String, depth: Int, indent: Bool) {
        switch value {
        case let v as Double: out += number(v); return
        case let v as Int: out += String(v); return
        case let v as UInt64: out += String(v); return
        case let v as Bool: out += v ? "true" : "false"; return
        case let v as String: out += quote(v); return
        default: break
        }

        let m = Mirror(reflecting: value)
        switch m.displayStyle {
        case .optional:
            if let some = m.children.first?.value { emit(some, into: &out, depth: depth, indent: indent) } else { out += "null" }
        case .collection:
            emitArray(m.children.map(\.value), into: &out, depth: depth, indent: indent)
        case .set:
            let items = m.children.map(\.value).sorted { sortKey($0) < sortKey($1) }
            emitArray(items, into: &out, depth: depth, indent: indent)
        case .dictionary:
            var pairs: [(String, Any)] = []
            for c in m.children {
                let kv = Mirror(reflecting: c.value).children.map(\.value)
                pairs.append((String(describing: kv[0]), kv[1]))
            }
            pairs.sort { sortKey($0.0) < sortKey($1.0) }
            emitObject(pairs, into: &out, depth: depth, indent: indent)
        case .enum:
            if let payload = m.children.first {
                var pairs: [(String, Any)] = [("case", payload.label ?? "?")]
                let pm = Mirror(reflecting: payload.value)
                if pm.displayStyle == .tuple {
                    for (n, c) in pm.children.enumerated() {
                        let label = c.label.flatMap { $0.hasPrefix(".") ? nil : $0 } ?? "_\(n)"
                        pairs.append((label, c.value))
                    }
                } else {
                    pairs.append(("_0", payload.value))
                }
                emitObject(pairs, into: &out, depth: depth, indent: indent)
            } else {
                out += quote(String(describing: value))
            }
        case .tuple:
            emitArray(m.children.map(\.value), into: &out, depth: depth, indent: indent)
        default:
            // Structs and classes. A struct with no stored properties (a brain) is written as its
            // type name; closures are left out.
            if m.children.isEmpty {
                out += quote(String(describing: type(of: value)))
            } else {
                let pairs = m.children.compactMap { c -> (String, Any)? in
                    guard let label = c.label, !isClosure(c.value) else { return nil }
                    return (label.hasPrefix("_") ? String(label.dropFirst()) : label, c.value)
                }
                emitObject(pairs, into: &out, depth: depth, indent: indent)
            }
        }
    }

    private static func emitArray(_ items: [Any], into out: inout String, depth: Int, indent: Bool) {
        if items.isEmpty { out += "[]"; return }
        let pad = indent ? String(repeating: "  ", count: depth + 1) : ""
        let close = indent ? String(repeating: "  ", count: depth) : ""
        let nl = indent ? "\n" : ""
        out += "[" + nl
        for (n, item) in items.enumerated() {
            out += pad
            emit(item, into: &out, depth: depth + 1, indent: indent)
            out += (n < items.count - 1 ? "," : "") + nl
        }
        out += close + "]"
    }

    private static func emitObject(_ pairs: [(String, Any)], into out: inout String, depth: Int, indent: Bool) {
        if pairs.isEmpty { out += "{}"; return }
        let pad = indent ? String(repeating: "  ", count: depth + 1) : ""
        let close = indent ? String(repeating: "  ", count: depth) : ""
        let nl = indent ? "\n" : ""
        let sep = indent ? ": " : ":"
        out += "{" + nl
        for (n, (k, v)) in pairs.enumerated() {
            out += pad + quote(k) + sep
            emit(v, into: &out, depth: depth + 1, indent: indent)
            out += (n < pairs.count - 1 ? "," : "") + nl
        }
        out += close + "}"
    }

    static func number(_ v: Double) -> String {
        guard v.isFinite else { return quote(v.isNaN ? "nan" : (v > 0 ? "inf" : "-inf")) }
        let text = "\(v)"
        doublesSeen[text] = v.bitPattern
        return text
    }

    static func quote(_ s: String) -> String {
        var r = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\"": r += "\\\""
            case "\\": r += "\\\\"
            case "\n": r += "\\n"
            case "\r": r += "\\r"
            case "\t": r += "\\t"
            default:
                if ch.value < 0x20 { r += String(format: "\\u%04x", ch.value) } else { r.unicodeScalars.append(ch) }
            }
        }
        return r + "\""
    }

    private static func sortKey(_ v: Any) -> String {
        if let i = v as? Int { return String(format: "%020lld", Int64(i) &+ Int64.max / 2) }
        return String(describing: v)
    }

    private static func isClosure(_ v: Any) -> Bool {
        String(describing: type(of: v)).contains("->")
    }
}

/// Reads a stored property by name, including private ones.
func field(_ value: Any, _ name: String) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == name }?.value
}
