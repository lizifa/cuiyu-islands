#!/usr/bin/env python3
"""Build a signed test APK without opening a window or changing global editor settings."""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT_APP = Path("/Applications/Godot.app")
GODOT_DATA = Path.home() / "Library/Application Support/Godot"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk", type=Path, default=Path.home() / "android_sdk")
    parser.add_argument("--java", type=Path, default=Path("/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"))
    args = parser.parse_args()
    if not (args.sdk / "platform-tools/adb").is_file():
        raise SystemExit("Android SDK not found; pass --sdk")
    if not (args.java / "bin/java").is_file():
        raise SystemExit("JDK not found; pass --java")
    if not (GODOT_DATA / "export_templates/4.7.2.stable/android_debug.apk").is_file():
        subprocess.run(["python3", str(ROOT / "tools/fetch_android_template.py")], check=True)
    destination = ROOT / "build/android/qinggeng-yuhang-0.4.1-debug.apk"
    destination.parent.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/.gdignore").touch()
    with tempfile.TemporaryDirectory(prefix="qgyh-android-build-") as directory:
        temporary = Path(directory)
        app = temporary / "Godot.app"
        # APFS copy-on-write clone; copying is a fallback for other filesystems.
        clone = subprocess.run(["cp", "-cR", str(GODOT_APP), str(app)], capture_output=True)
        if clone.returncode:
            if app.exists(): shutil.rmtree(app)
            shutil.copytree(GODOT_APP, app, symlinks=True)
        data = temporary / "editor_data"
        data.mkdir()
        (data / "export_templates").symlink_to(GODOT_DATA / "export_templates", target_is_directory=True)
        settings = '\n'.join([
            '[gd_resource type="EditorSettings" format=3]', '', '[resource]',
            f'export/android/java_sdk_path = "{args.java}"',
            f'export/android/android_sdk_path = "{args.sdk}"', '',
        ])
        (data / "editor_settings-4.7.tres").write_text(settings)
        # macOS self-contained editor data lives alongside the .app bundle.
        (temporary / "_sc_").touch()
        binary = app / "Contents/MacOS/Godot"
        environment = os.environ.copy()
        environment["JAVA_HOME"] = str(args.java)
        environment["ANDROID_HOME"] = str(args.sdk)
        environment["GODOT_ANDROID_KEYSTORE_DEBUG_PATH"] = str(Path.home() / ".android/debug.keystore")
        environment["GODOT_ANDROID_KEYSTORE_DEBUG_USER"] = "androiddebugkey"
        environment["GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"] = "android"
        print("Building arm64 Android test APK using isolated editor settings", flush=True)
        subprocess.run([
            str(binary), "--headless", "--path", str(ROOT),
            "--export-debug", "Android Test APK", str(destination),
        ], env=environment, check=True)
        if not destination.is_file(): raise RuntimeError("Godot did not produce an APK")
        print(f"APK: {destination} ({destination.stat().st_size / 1048576:.1f} MiB)")


if __name__ == "__main__":
    main()
