#!/usr/bin/env python3
"""Restores data/cards/emberwright.json to the hand-authored compact layout.

The JSON is chosen over .tres because it is diffable in review (D-14), and a
one-key-per-line dump throws that away. Scalars pack onto wrapped lines; effect
arrays get their own.
"""
import collections
import json
import pathlib

ORDER = ["id", "title", "cost", "upgraded_cost", "type", "target", "rarity",
         "element", "tm", "exhaust", "ethereal", "innate", "retain",
         "overload_bonus", "text", "effects", "upgraded_effects"]
WIDTH = 98
PATH = pathlib.Path(__file__).resolve().parent.parent / "data/cards/emberwright.json"


def enc(value):
    return json.dumps(value, separators=(", ", ": "), ensure_ascii=False)


def effect_lines(key, effects, indent="    "):
    one = '%s"%s": %s' % (indent, key, enc(effects))
    if len(one) <= WIDTH:
        return [one]
    out = ['%s"%s": [' % (indent, key)]
    for i, effect in enumerate(effects):
        comma = "," if i < len(effects) - 1 else ""
        inner = indent + "  "
        flat = "%s%s%s" % (inner, enc(effect), comma)
        if len(flat) <= WIDTH or "effects" not in effect:
            out.append(flat)
            continue
        head = {k: v for k, v in effect.items() if k != "effects"}
        out.append("%s{%s," % (inner, enc(head)[1:-1]))
        out.append('%s "effects": %s}%s' % (inner, enc(effect["effects"]), comma))
    out.append("%s]" % indent)
    return out


def main() -> int:
    cards = json.load(open(PATH), object_pairs_hook=collections.OrderedDict)
    lines = ["["]
    for n, card in enumerate(cards):
        keys = [k for k in ORDER if k in card] + [k for k in card if k not in ORDER]
        lines.append("  {")
        buf = ""
        for key in keys:
            if key in ("effects", "upgraded_effects"):
                if buf:
                    lines.append("    " + buf)
                    buf = ""
                lines += effect_lines(key, card[key])
                lines[-1] += ","
                continue
            token = '"%s": %s,' % (key, enc(card[key]))
            if buf and len("    " + buf + " " + token) > WIDTH:
                lines.append("    " + buf)
                buf = token
            else:
                buf = (buf + " " + token).strip()
        if buf:
            lines.append("    " + buf)
        lines[-1] = lines[-1].rstrip(",")
        lines.append("  }" + ("," if n < len(cards) - 1 else ""))
    lines.append("]")
    out = "\n".join(lines) + "\n"
    assert json.loads(out) == json.loads(json.dumps(cards)), "round-trip changed the data"
    PATH.write_text(out)
    print("format_cards: %d cards, compact layout restored" % len(cards))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
