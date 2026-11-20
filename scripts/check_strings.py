"""Lists UI text in the Swift code that has no Arabic translation in Localizable.xcstrings.

Run:  python scripts/check_strings.py   (prints nothing and exits 0 when everything is translated)
"""
import itertools
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEYS = set(json.loads((ROOT / "HallakAdmin/Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"])

LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
INTERP = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
# Lines whose literals are not UI text.
SKIP_LINE = ("verbatim", "forKey", "Image(\"", "rawValue", "Endpoint(", "identifier:",
             "dateFormat", "setValue", "forHTTPHeaderField", "print(", "precondition", "CodingKey", "appendingPathComponent",
             "service:", "Color(\"", "Keychain(", "decode(", "replacingOccurrences", "hasPrefix", "kSec", "#Preview",
             "XCT", "\"Using", "Locale(", "badge(Text(\"M")
SKIP_TEXT = re.compile(r"^(smapi_|https?:|/|[a-z_]+$|[A-Z][a-zA-Z]+[A-Z]|en|ar|M\d)$|^[^A-Za-z]*$")


def variants(text):
    if "\\(" not in text:
        return [text]
    base = INTERP.sub("\0", text)
    out = []
    for combo in itertools.product(["%lld", "%@"], repeat=base.count("\0")):
        t = base
        for c in combo:
            t = t.replace("\0", c, 1)
        out.append(t)
    return out


def main():
    missing = []
    for f in sorted((ROOT / "HallakAdmin").rglob("*.swift")):
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip().startswith("//") or any(s in line for s in SKIP_LINE):
                continue
            for m in LITERAL.finditer(line):
                text = m.group(1)
                before = line[max(0, m.start() - 20):m.start()]
                if before.endswith(("systemImage: ", "systemName: ", "Image(")):
                    continue
                if SKIP_TEXT.search(text) or " " not in text and text[:1].islower():
                    continue
                if not any(v in KEYS for v in variants(text)):
                    missing.append(f"{f.relative_to(ROOT)}:{n}: {text}")
    print("\n".join(missing))
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
