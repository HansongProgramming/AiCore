import os
from pathlib import Path
from pillow_heif import register_heif_opener
from PIL import Image

register_heif_opener()

heic_files = list(Path(".").glob("*.heic")) + list(Path(".").glob("*.HEIC"))

if not heic_files:
    print("No HEIC files found in current directory.")
else:
    for heic_path in heic_files:
        png_path = heic_path.with_suffix(".png")
        print(f"Converting {heic_path.name} -> {png_path.name}")
        Image.open(heic_path).save(png_path)
        heic_path.unlink()
        print(f"Deleted {heic_path.name}")

    print(f"\nDone. Converted {len(heic_files)} file(s).")
