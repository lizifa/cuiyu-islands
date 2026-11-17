#!/usr/bin/env python3
"""Prepare a supplied local video for Godot's built-in Theora player."""
import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('--ffmpeg', default='/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg')
    args = parser.parse_args()
    executable = shutil.which(args.ffmpeg)
    if executable is None:
        parser.error('ffmpeg with libtheora and libvorbis encoders is required')
    output = ROOT / 'assets/videos/home-tv.ogv'
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        executable, '-y', '-i', str(args.source.resolve()),
        '-vf', "crop=w='trunc(ih*16/9/2)*2':h=ih:x='(iw-ow)/2':y=0,scale=854:480:flags=lanczos,fps=24",
        '-c:v', 'libtheora', '-q:v', '5', '-c:a', 'libvorbis', '-q:a', '2',
        '-ar', '44100', '-ac', '2', str(output),
    ], check=True)

if __name__ == '__main__':
    main()
