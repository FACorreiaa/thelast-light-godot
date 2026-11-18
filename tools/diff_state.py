#!/usr/bin/env python3
"""Diffs two canonical state dumps (oracle `dump` vs tests/replay.gd --dump) key by key.

Floats are compared by their bits (the hex in "f:<decimal>:<hex>"), never by decimal text.
Usage: diff_state.py <swift.json> <godot.json>
"""
import json, sys


def norm(v):
    if isinstance(v, str) and v.startswith("f:"):
        return ("f", v.rsplit(":", 1)[1])
    return v


def walk(a, b, path, out):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                out.append(f"{path}.{k}: {'missing in swift' if k not in a else 'missing in godot'}")
            else:
                walk(a[k], b[k], f"{path}.{k}", out)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append(f"{path}: length {len(a)} vs {len(b)}")
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, f"{path}[{i}]", out)
    elif norm(a) != norm(b) or type(a) is not type(b):
        out.append(f"{path}: swift {a!r} godot {b!r}")


out = []
walk(json.load(open(sys.argv[1])), json.load(open(sys.argv[2])), "$", out)
print("\n".join(out) if out else "identical")
sys.exit(1 if out else 0)
