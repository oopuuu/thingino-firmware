#!/usr/bin/env python3
"""
Sort all keys alphabetically in all thingino-camera.json files.
"""

import json
from pathlib import Path

def main():
    """Process all thingino-camera.json files."""
    cameras_dir = Path('/home/paul/dev/thingino-firmware-stable/configs/cameras')
    json_files = sorted(cameras_dir.glob('*/thingino-camera.json'))

    print(f"Processing {len(json_files)} JSON files...\n")

    updated = 0
    for json_path in json_files:
        with open(json_path, 'r') as f:
            config = json.load(f)

        # Write with sorted keys
        with open(json_path, 'w') as f:
            json.dump(config, f, indent=2, sort_keys=True)

        print(f"✓ {json_path.parent.name}")
        updated += 1

    print(f"\nSorted {updated} files")

if __name__ == '__main__':
    main()
