"""Extract inert geometry from a named model in a Rojo-built XML place.

Rojo can decode binary .rbxm files while writing an XML .rbxlx. This tool
copies one named model out of that temporary place, keeps only geometry-bearing
instances, clears attributes, and writes a standalone .rbxmx suitable for the
normal scan/strip workflow.
"""

from __future__ import annotations

import copy
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


GEOMETRY_CLASSES = {
    "CornerWedgePart",
    "Decal",
    "MeshPart",
    "Model",
    "Part",
    "SpecialMesh",
    "SurfaceAppearance",
    "Texture",
    "TrussPart",
    "UnionOperation",
    "WedgePart",
}


def item_name(item: ET.Element) -> str:
    props = item.find("Properties")
    if props is None:
        return "?"
    for prop in props:
        if prop.tag == "string" and prop.get("name") == "Name":
            return prop.text or ""
    return "?"


def prune(item: ET.Element) -> None:
    props = item.find("Properties")
    if props is not None:
        attributes = props.find("BinaryString[@name='AttributesSerialize']")
        if attributes is not None:
            attributes.text = ""

    for child in list(item.findall("Item")):
        if child.get("class") not in GEOMETRY_CLASSES:
            item.remove(child)
            continue
        prune(child)


def count_classes(item: ET.Element) -> dict[str, int]:
    tally: dict[str, int] = {}
    for descendant in item.iter("Item"):
        class_name = descendant.get("class") or "?"
        tally[class_name] = tally.get(class_name, 0) + 1
    return tally


def main(source: str, model_name: str, output: str) -> None:
    source_root = ET.parse(source).getroot()
    source_item = next(
        (item for item in source_root.iter("Item") if item_name(item) == model_name),
        None,
    )
    if source_item is None:
        raise SystemExit(f'model "{model_name}" not found in {source}')

    before = count_classes(source_item)
    model = copy.deepcopy(source_item)
    prune(model)

    props = model.find("Properties")
    if props is not None:
        name = props.find("string[@name='Name']")
        if name is not None:
            name.text = Path(output).stem

    namespace = "http://www.w3.org/2001/XMLSchema-instance"
    ET.register_namespace("xsi", namespace)
    output_root = ET.Element(
        "roblox",
        {
            f"{{{namespace}}}noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
            "version": "4",
        },
    )
    meta = ET.SubElement(output_root, "Meta", {"name": "ExplicitAutoJoints"})
    meta.text = "false"
    ET.SubElement(output_root, "External").text = "null"
    ET.SubElement(output_root, "External").text = "nil"
    output_root.append(model)

    referenced = {
        value.text
        for value in model.iter("SharedString")
        if value.get("md5") is None and value.text
    }
    source_shared = source_root.find("SharedStrings")
    output_shared = ET.SubElement(output_root, "SharedStrings")
    if source_shared is not None:
        for value in source_shared.findall("SharedString"):
            if value.get("md5") in referenced:
                output_shared.append(copy.deepcopy(value))

    ET.indent(output_root, space="\t")
    ET.ElementTree(output_root).write(output, encoding="unicode", xml_declaration=False)

    after = count_classes(model)
    print(f'extracted "{model_name}" -> {output}')
    print(f"{'class':<24} before  after")
    for class_name in sorted(set(before) | set(after)):
        left, right = before.get(class_name, 0), after.get(class_name, 0)
        marker = "  <-- removed" if left != right else ""
        print(f"{class_name:<24} {left:>6}  {right:>5}{marker}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: extract_geometry.py place.rbxlx ModelName output.rbxmx")
    main(sys.argv[1], sys.argv[2], sys.argv[3])
