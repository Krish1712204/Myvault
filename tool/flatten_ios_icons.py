"""Removes the alpha channel from the iOS app icons (the App Store rejects icons that have one).

Run after `flutter test tool/generate_app_icons.dart`:
    python tool/flatten_ios_icons.py
"""
from pathlib import Path

from PIL import Image

ICONS = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")

for path in sorted(ICONS.glob("*.png")):
    image = Image.open(path)
    if image.mode != "RGB":
        flat = Image.new("RGB", image.size, (13, 71, 161))
        flat.paste(image, mask=image.getchannel("A") if "A" in image.getbands() else None)
        flat.save(path, optimize=True)
        print(f"flattened {path.name}")
