#!/usr/bin/env python3
"""Inspect APK metadata without the proprietary Android SDK or third-party Python packages."""
import json
import struct
import sys
import zipfile
from pathlib import Path


def manifest_elements(data):
    strings = []
    cursor = 8
    while cursor < len(data):
        kind, header_size, size = struct.unpack_from("<HHI", data, cursor)
        if size < header_size or cursor + size > len(data):
            raise ValueError("Invalid binary Android manifest chunk")
        if kind == 0x0001:
            count, _, flags, start, _ = struct.unpack_from("<5I", data, cursor + 8)

            def read_length(pos, utf8):
                if utf8:
                    first = data[pos]
                    return ((first & 0x7F) << 8 | data[pos + 1], pos + 2) if first & 0x80 else (first, pos + 1)
                first = struct.unpack_from("<H", data, pos)[0]
                return (((first & 0x7FFF) << 16) | struct.unpack_from("<H", data, pos + 2)[0], pos + 4) if first & 0x8000 else (first, pos + 2)

            for index in range(count):
                offset = struct.unpack_from("<I", data, cursor + header_size + index * 4)[0]
                position = cursor + start + offset
                if flags & 0x100:
                    _, position = read_length(position, True)
                    length, position = read_length(position, True)
                    strings.append(data[position:position + length].decode("utf-8"))
                else:
                    length, position = read_length(position, False)
                    strings.append(data[position:position + length * 2].decode("utf-16-le"))
        elif kind == 0x0102:
            _, name, attr_start, attr_size, attr_count = struct.unpack_from("<IIHHH", data, cursor + 16)
            attrs = {}
            for index in range(attr_count):
                position = cursor + 16 + attr_start + index * attr_size
                _, attr_name, raw, _, _, value_type, value = struct.unpack_from("<IIIHBBI", data, position)
                if raw != 0xFFFFFFFF:
                    resolved = strings[raw]
                elif value_type == 3:
                    resolved = strings[value]
                elif value_type == 0x12:
                    resolved = bool(value)
                else:
                    resolved = value
                attrs[strings[attr_name]] = resolved
            yield strings[name], attrs
        cursor += size


def inspect(path):
    with zipfile.ZipFile(path) as apk:
        broken = apk.testzip()
        if broken:
            raise ValueError(f"Corrupt APK entry: {broken}")
        elements = list(manifest_elements(apk.read("AndroidManifest.xml")))
        root = next(attrs for name, attrs in elements if name == "manifest")
        sdk = next(attrs for name, attrs in elements if name == "uses-sdk")
        application = next(attrs for name, attrs in elements if name == "application")
        activities = [attrs for name, attrs in elements if name == "activity"]
        permissions = [attrs["name"] for name, attrs in elements if name == "uses-permission"]
        libraries = sorted({name.split("/")[1] for name in apk.namelist() if name.startswith("lib/") and name.endswith(".so")})
        assert root["package"] == "org.asterion.prototype", root
        assert libraries == ["arm64-v8a"], libraries
        assert any(activity.get("screenOrientation") == 0 for activity in activities), activities
        assert "android.permission.INTERNET" not in permissions, permissions
        assert "assets/project.binary" in apk.namelist(), "Missing exported project"
        return {
            "apk": str(Path(path).resolve()),
            "package": root["package"],
            "version": root.get("versionName"),
            "minimum_android_api": sdk.get("minSdkVersion"),
            "target_android_api": sdk.get("targetSdkVersion"),
            "architectures": libraries,
            "landscape": True,
            "debuggable": application.get("debuggable", False),
            "permissions": permissions,
            "size_bytes": Path(path).stat().st_size,
        }


if __name__ == "__main__":
    print(json.dumps(inspect(sys.argv[1]), indent=2, ensure_ascii=False))
