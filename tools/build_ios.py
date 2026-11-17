#!/usr/bin/env python3
"""Export, sign and optionally install the game without changing other projects."""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
OUTPUT = ROOT / 'build/ios'
PROJECT = OUTPUT / 'QinggengYuhang.xcodeproj'
DERIVED = ROOT / 'build/ios-derived'


def run(command):
    subprocess.run([str(arg) for arg in command], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--team', help='Apple Team ID; otherwise use the iOS export preset')
    parser.add_argument('--device', help='CoreDevice identifier, UDID or device name')
    parser.add_argument('--install', action='store_true', help='Install without launching; requires --device')
    parser.add_argument('--profile', action='store_true', help='Temporary telemetry build: freezes time and disables game saves')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--release', dest='release', action='store_true', help='Build optimized Release (default)')
    mode.add_argument('--debug', dest='release', action='store_false', help='Build a Debug application for debugging')
    parser.set_defaults(release=True)
    parser.add_argument('--export-only', action='store_true')
    args = parser.parse_args()
    if args.install and not args.device:
        parser.error('--install requires an explicit --device')
    preset = ROOT / 'export_presets.cfg'
    text = preset.read_text()
    section = text.index('[preset.2.options]')
    match = re.search(r'^application/app_store_team_id="([^"]*)"', text[section:], re.M)
    team = args.team or (match[1] if match else '')
    if not re.fullmatch(r'[A-Z0-9]{10}', team):
        parser.error('Choose an Apple Team ID with --team before signing')
    if args.team:
        text = text[:section] + re.sub(r'^application/app_store_team_id="[^"]*"',
            f'application/app_store_team_id="{team}"', text[section:], count=1, flags=re.M)
        preset.write_text(text)
    template = Path.home() / 'Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip'
    if not template.is_file():
        run(['python3', ROOT / 'tools/fetch_ios_template.py'])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'build/.gdignore').touch()
    original = preset.read_text()
    try:
        if args.profile:
            start = original.index('[preset.2]')
            profile = original[:start] + re.sub(r'^custom_features="[^"]*"',
                'custom_features="perf_probe"', original[start:], count=1, flags=re.M)
            preset.write_text(profile)
        run([GODOT, '--headless', '--path', ROOT, '--export-release' if args.release else '--export-debug', 'iOS', PROJECT])
    finally:
        if args.profile:
            preset.write_text(original)
    if args.export_only:
        return
    destination = 'generic/platform=iOS'
    if args.device:
        with tempfile.TemporaryDirectory(prefix='qgyh-ios-device-') as temporary:
            details = Path(temporary) / 'device.json'
            run(['xcrun', 'devicectl', 'device', 'info', 'details', '--device', args.device, '--json-output', details])
            info = json.loads(details.read_text())['result']
            destination = 'platform=iOS,id=' + info['hardwareProperties']['udid']
    run(['xcodebuild', '-project', PROJECT, '-scheme', 'QinggengYuhang',
         '-configuration', 'Release' if args.release else 'Debug', '-destination', destination, '-derivedDataPath', DERIVED,
         f'DEVELOPMENT_TEAM={team}', 'CODE_SIGN_STYLE=Automatic', 'CODE_SIGN_IDENTITY=Apple Development',
         '-allowProvisioningUpdates', '-allowProvisioningDeviceRegistration', 'build'])
    app = DERIVED / ('Build/Products/Release-iphoneos/QinggengYuhang.app' if args.release else 'Build/Products/Debug-iphoneos/QinggengYuhang.app')
    if not app.is_dir():
        raise RuntimeError('Xcode did not produce the expected application')
    print(f'Application: {app}', flush=True)
    if args.install:
        run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.device, app])
        print('Installed without launching; existing application data preserved.', flush=True)


if __name__ == '__main__':
    main()
