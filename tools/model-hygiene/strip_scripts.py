"""Remove all Script/LocalScript/ModuleScript instances from a .rbxmx model.

Used to strip the free-model backdoor (qPerfectionWeld + CoreSkyboxSystem) out
of assets/Models/Chiikawa.rbxmx while leaving geometry, meshes and decals alone.
The original is copied to a quarantine path OUTSIDE the repo first, so the
backdoor never enters Git history.
"""

import shutil
import sys
import xml.etree.ElementTree as ET

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}


def describe(item):
    name = item.find("./Properties/string[@name='Name']")
    return f"{item.get('class')} '{name.text if name is not None else '?'}'"


def count_classes(path):
    root = ET.parse(path).getroot()
    tally = {}
    for item in root.iter("Item"):
        cls = item.get("class")
        tally[cls] = tally.get(cls, 0) + 1
    return tally


def main(src, quarantine):
    before = count_classes(src)

    shutil.copy2(src, quarantine)
    print(f"quarantined original -> {quarantine}")

    tree = ET.parse(src)
    root = tree.getroot()

    # ElementTree has no parent pointers; build a child -> parent map.
    parents = {child: parent for parent in root.iter() for child in parent}

    doomed = [e for e in root.iter("Item") if e.get("class") in SCRIPT_CLASSES]
    for item in doomed:
        print(f"  removing {describe(item)}")
        parents[item].remove(item)

    tree.write(src, encoding="utf-8", xml_declaration=False)

    after = count_classes(src)
    print(f"\nremoved {len(doomed)} script instance(s)")
    print(f"{'class':<20} before  after")
    for cls in sorted(set(before) | set(after)):
        b, a = before.get(cls, 0), after.get(cls, 0)
        flag = "  <-- changed" if b != a else ""
        print(f"{cls:<20} {b:>6}  {a:>5}{flag}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
