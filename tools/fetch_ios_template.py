#!/usr/bin/env python3
"""Fetch only the iOS template from the official, version-pinned template ZIP.

HTTP Range avoids downloading 1+ GB of templates for unrelated platforms. Verify both
ZIP entry sizes and CRC before installing; preserve all existing template files.
"""
import argparse
import binascii
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path

VERSION = "4.7.2.stable"
URL = "https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"


def fetch_range(spec: str) -> bytes:
    with tempfile.TemporaryDirectory(prefix="qgyh-template-") as directory:
        body = Path(directory) / "part"
        headers = Path(directory) / "headers"
        subprocess.run([
            "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2",
            "--max-time", "180", "--range", spec,
            "--dump-header", str(headers), "--output", str(body), URL,
        ], check=True)
        response = headers.read_text()
        if " 206 " not in response or "content-range:" not in response.lower():
            raise RuntimeError("Server did not honor HTTP Range; refusing a full archive download")
        return body.read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--destination", type=Path, default=Path.home() / "Library/Application Support/Godot/export_templates" / VERSION)
    args = parser.parse_args()
    destination = args.destination / "ios.zip"
    if destination.is_file():
        print(f"Already installed: {destination}")
        return
    tail = fetch_range("-65557")
    offset = tail.rfind(b"PK\x05\x06")
    if offset < 0:
        raise RuntimeError("No ZIP central directory found")
    end = struct.unpack_from("<4s4H2IH", tail, offset)
    cd_size, cd_start = end[5], end[6]
    directory = fetch_range(f"{cd_start}-{cd_start + cd_size - 1}")
    cursor = 0
    target = None
    while cursor < len(directory):
        entry = struct.unpack_from("<4s6H3I5H2I", directory, cursor)
        if entry[0] != b"PK\x01\x02":
            raise RuntimeError("Invalid ZIP directory")
        name = directory[cursor + 46:cursor + 46 + entry[10]].decode("utf-8")
        if name == "templates/ios.zip":
            target = (entry[4], entry[7], entry[8], entry[9], entry[16])
            break
        cursor += 46 + entry[10] + entry[11] + entry[12]
    if target is None:
        raise RuntimeError("Official archive has no iOS template")
    method, crc, compressed, uncompressed, local_start = target
    local = fetch_range(f"{local_start}-{local_start + 29}")
    if local[:4] != b"PK\x03\x04":
        raise RuntimeError("Invalid local ZIP header")
    name_length, extra_length = struct.unpack_from("<HH", local, 26)
    data_start = local_start + 30 + name_length + extra_length
    print(f"Downloading iOS template only: {compressed / 1048576:.1f} MiB", flush=True)
    packed = fetch_range(f"{data_start}-{data_start + compressed - 1}")
    if len(packed) != compressed:
        raise RuntimeError("Incomplete template download")
    raw = zlib.decompress(packed, -15) if method == 8 else packed
    if method not in (0, 8) or len(raw) != uncompressed or binascii.crc32(raw) & 0xffffffff != crc:
        raise RuntimeError("Template ZIP CRC/size mismatch")
    args.destination.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(".tmp")
    temporary.write_bytes(raw)
    temporary.replace(destination)
    print(f"Installed verified template: {destination}")


if __name__ == "__main__":
    main()
