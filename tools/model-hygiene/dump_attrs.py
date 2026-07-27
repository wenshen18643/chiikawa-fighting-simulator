"""Decode Roblox AttributesSerialize blobs from a .rbxmx and print name -> value.

Only handles the types needed here (string, float64). Enough to answer "what id
is hidden in this attribute", which is the question when a free model does
require(someInstance:GetAttribute("Version")).
"""

import base64
import struct
import sys
import xml.etree.ElementTree as ET

TYPE_STRING = 0x02
TYPE_FLOAT64 = 0x06  # Roblox attribute "number" is a float64 under type tag 6
TYPE_FLOAT64_ALT = 0x09


def read_attributes(blob):
    data = base64.b64decode(blob)
    pos = 0
    (count,) = struct.unpack_from("<I", data, pos)
    pos += 4
    out = {}
    for _ in range(count):
        (name_len,) = struct.unpack_from("<I", data, pos)
        pos += 4
        name = data[pos : pos + name_len].decode("utf8", "replace")
        pos += name_len
        type_id = data[pos]
        pos += 1
        if type_id == TYPE_STRING:
            (slen,) = struct.unpack_from("<I", data, pos)
            pos += 4
            value = data[pos : pos + slen].decode("utf8", "replace")
            pos += slen
        elif type_id in (TYPE_FLOAT64, TYPE_FLOAT64_ALT):
            (value,) = struct.unpack_from("<d", data, pos)
            pos += 8
        else:
            out[name] = f"<unhandled type 0x{type_id:02x}, stopping>"
            break
        out[name] = value
    return out


def main(paths):
    for path in paths:
        print(f"\n=== {path} ===")
        root = ET.parse(path).getroot()
        for item in root.iter("Item"):
            props = item.find("Properties")
            if props is None:
                continue
            blob = props.find("BinaryString[@name='AttributesSerialize']")
            if blob is None or not (blob.text or "").strip():
                continue
            name_el = props.find("string[@name='Name']")
            name = name_el.text if name_el is not None else "?"
            attrs = read_attributes(blob.text)
            print(f"  {item.get('class')} '{name}': {attrs}")


if __name__ == "__main__":
    main(sys.argv[1:])
