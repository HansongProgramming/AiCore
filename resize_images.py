from PIL import Image
from pathlib import Path

MAX_WIDTH = 1600

files = [f for f in Path(".").iterdir() if f.suffix.lower() in [".jpg", ".jpeg", ".png"]]
print(f"Found {len(files)} images")

for f in files:
    img = Image.open(f)
    w, h = img.size
    ratio = MAX_WIDTH / w
    img = img.resize((MAX_WIDTH, int(h * ratio)), Image.LANCZOS)
    img.convert("RGB").save(f, "JPEG", quality=95)
    print(f"{f.name}: {w}x{h} → {MAX_WIDTH}x{int(h * ratio)}")

print("Done.")
