"""Report every script inside a .rbxmx and flag known free-model backdoor tells.

Read-only. Prints an inventory plus any line matching a pattern associated with
remote code execution or anti-inspection, so a model can be judged before it is
committed into assets/.
"""

import html
import re
import sys
import xml.etree.ElementTree as ET

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}

# (label, regex) — each is a reason to look closer, not proof on its own.
TELLS = [
    # NOTE ON `.*` vs `[^)]*`: these must span nested parens. The real payload
    # seen in this project was
    #     require(script:WaitForChild("TextureConfiguration", 4):GetAttribute("Version"))
    # and a `[^)]*` bridge stops dead at the `)` closing WaitForChild, which is
    # how the first version of this scanner reported two backdoored models clean.
    ("require by asset id", re.compile(r"require\s*\(\s*\d{6,}")),
    ("require of a .Value", re.compile(r"require\s*\(.*\.Value")),
    ("require of an attribute", re.compile(r"require\s*\(.*GetAttribute")),
    ("id stashed in an instance", re.compile(r"Instance\.new\s*\(\s*[\"'](?:NumberPose|IntValue|NumberValue|StringValue)")),
    ("big bare number literal", re.compile(r"(?<![\w.])\d{11,}(?![\w.])")),
    ("studio-mode evasion", re.compile(r"InStudioMode|JobId|RunService:IsStudio")),
    ("script identifier reassigned", re.compile(r"^\s*script\s*=")),
    ("dynamic code", re.compile(r"loadstring|getfenv|setfenv")),
    ("http egress", re.compile(r"HttpService|GetAsync|PostAsync|RequestAsync")),
    ("marketplace/insert fetch", re.compile(r"InsertService|MarketplaceService")),
]


def scripts_in(path):
    root = ET.parse(path).getroot()
    found = []
    for item in root.iter("Item"):
        if item.get("class") not in SCRIPT_CLASSES:
            continue
        props = item.find("Properties")
        if props is None:
            continue
        name_el = props.find("string[@name='Name']")
        src_el = props.find("ProtectedString[@name='Source']")
        name = name_el.text if name_el is not None else "?"
        source = html.unescape(src_el.text or "") if src_el is not None else ""
        found.append((item.get("class"), name, source))
    return found


def main(paths):
    for path in paths:
        found = scripts_in(path)
        print(f"\n{'=' * 70}\n{path}\n{'=' * 70}")
        if not found:
            print("  no scripts - clean")
            continue

        for cls, name, source in found:
            lines = source.split("\n")
            print(f"\n  {cls} '{name}'  ({len(lines)} lines)")
            hits = []
            for i, line in enumerate(lines, 1):
                for label, pattern in TELLS:
                    if pattern.search(line):
                        hits.append((i, label, line.strip()[:120]))
                        break
            if hits:
                for i, label, text in hits:
                    print(f"    !! L{i:<5} [{label}]  {text}")
            else:
                print("    no tells matched (still worth reading before trusting)")


if __name__ == "__main__":
    main(sys.argv[1:])
