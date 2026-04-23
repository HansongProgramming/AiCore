"""
AiCore InstantSplat Setup Script
---------------------------------
Run this from the InstantSplat_Windows root folder.

What it does:
  1. Patches all submodule setup.py files with --allow-unsupported-compiler flags
  2. Patches gradio UI to allow more than 12 views
  3. Provides image preprocessing (resize + HEIC convert) before running inference
"""

import os
import re
import sys
import shutil
from pathlib import Path

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg, level="INFO"):
    prefix = {"INFO": "  ", "OK": "✓ ", "FAIL": "✗ ", "STEP": "\n▶ "}
    print(f"{prefix.get(level, '  ')}{msg}")

def patch_file(filepath, find, replace, label):
    path = Path(filepath)
    if not path.exists():
        log(f"Not found, skipping: {filepath}", "FAIL")
        return False
    content = path.read_text(encoding="utf-8")
    if find not in content:
        if "--allow-unsupported-compiler" in content:
            log(f"Already patched: {label}", "OK")
            return True
        log(f"Pattern not found in {label} — may need manual check", "FAIL")
        return False
    patched = content.replace(find, replace)
    path.write_text(patched, encoding="utf-8")
    log(f"Patched: {label}", "OK")
    return True

# ── Step 1: Patch submodule setup.py files ────────────────────────────────────

def patch_submodules():
    log("Patching submodule setup.py files", "STEP")

    # simple-knn
    patch_file(
        "submodules/simple-knn/setup.py",
        'extra_compile_args={"nvcc": [], "cxx": cxx_compiler_flags})',
        'extra_compile_args={"nvcc": ["--allow-unsupported-compiler", "-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"], "cxx": cxx_compiler_flags})',
        "simple-knn"
    )

    # diff-gaussian-rasterization
    patch_file(
        "submodules/diff-gaussian-rasterization/setup.py",
        'extra_compile_args={"nvcc": ["-I" + os.path.join(os.path.dirname(os.path.abspath(__file__)), "third_party/glm/")]})',
        'extra_compile_args={"nvcc": ["-I" + os.path.join(os.path.dirname(os.path.abspath(__file__)), "third_party/glm/"), "--allow-unsupported-compiler", "-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"]})',
        "diff-gaussian-rasterization"
    )

    # fused-ssim — has no extra_compile_args so we insert one
    fused_path = Path("submodules/fused-ssim/setup.py")
    if fused_path.exists():
        content = fused_path.read_text(encoding="utf-8")
        if "--allow-unsupported-compiler" in content:
            log("Already patched: fused-ssim", "OK")
        elif '"ext.cpp"])' in content:
            patched = content.replace(
                '"ext.cpp"])',
                '"ext.cpp"],\n            extra_compile_args={"nvcc": ["--allow-unsupported-compiler", "-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"]})'
            )
            fused_path.write_text(patched, encoding="utf-8")
            log("Patched: fused-ssim", "OK")
        else:
            log("fused-ssim pattern not found — may need manual check", "FAIL")

    # curope (RoPE kernels)
    patch_file(
        "croco/models/curope/setup.py",
        "nvcc=['-O3','--ptxas-options=-v',\"--use_fast_math\"]+all_cuda_archs,",
        "nvcc=['-O3','--ptxas-options=-v',\"--use_fast_math\",\"--allow-unsupported-compiler\",\"-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH\"]+all_cuda_archs,",
        "curope (RoPE kernels)"
    )

# ── Step 2: Patch gradio UI for more views ────────────────────────────────────

def patch_gradio():
    log("Patching Gradio UI view limit", "STEP")

    gradio_path = Path("instantsplat_gradio.py")
    if not gradio_path.exists():
        log("instantsplat_gradio.py not found", "FAIL")
        return

    content = gradio_path.read_text(encoding="utf-8")

    # Bump slider maximum from 12 to 50
    patched = re.sub(
        r'(gr\.Slider\([^)]*maximum\s*=\s*)12',
        r'\g<1>50',
        content
    )

    if patched == content:
        log("Gradio view limit already patched or pattern changed", "OK")
    else:
        gradio_path.write_text(patched, encoding="utf-8")
        log("Gradio UI: max views raised to 50", "OK")

# ── Step 3: Image preprocessing ───────────────────────────────────────────────

def preprocess_images(input_folder, output_folder=None, max_width=1600):
    log(f"Preprocessing images in: {input_folder}", "STEP")

    try:
        from PIL import Image
    except ImportError:
        log("Pillow not installed. Run: pip install pillow", "FAIL")
        return

    # Try HEIC support
    heic_supported = False
    try:
        from pillow_heif import register_heif_opener
        register_heif_opener()
        heic_supported = True
        log("HEIC support enabled", "OK")
    except ImportError:
        log("HEIC support not available (pip install pillow-heif to enable)", "INFO")

    input_path = Path(input_folder)
    if not input_path.exists():
        log(f"Input folder not found: {input_folder}", "FAIL")
        return

    # If no output folder, create an 'images' subfolder inside input
    if output_folder is None:
        out_path = input_path / "images"
    else:
        out_path = Path(output_folder)
    out_path.mkdir(parents=True, exist_ok=True)

    extensions = [".jpg", ".jpeg", ".png", ".tiff", ".tif"]
    if heic_supported:
        extensions += [".heic", ".HEIC"]

    files = [f for f in input_path.iterdir() if f.suffix.lower() in extensions]

    if not files:
        log("No supported image files found", "FAIL")
        return

    log(f"Found {len(files)} images, resizing to max width {max_width}px", "INFO")

    for f in files:
        try:
            img = Image.open(f)
            w, h = img.size

            if w > max_width:
                ratio = max_width / w
                new_size = (max_width, int(h * ratio))
                img = img.resize(new_size, Image.LANCZOS)
                log(f"{f.name}: {w}x{h} → {new_size[0]}x{new_size[1]}", "INFO")
            else:
                log(f"{f.name}: {w}x{h} (no resize needed)", "INFO")

            # Always save as JPG for consistency
            out_file = out_path / (f.stem + ".jpg")
            img.convert("RGB").save(out_file, "JPEG", quality=95)

        except Exception as e:
            log(f"Failed to process {f.name}: {e}", "FAIL")

    log(f"Done. Images saved to: {out_path}", "OK")
    log(f"Use this path in InstantSplat: {out_path}", "INFO")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]

    if not args or args[0] == "patch":
        # Run from InstantSplat_Windows root
        root = Path(".")
        if not (root / "instantsplat_gradio.py").exists():
            log("Run this script from your InstantSplat_Windows root folder.", "FAIL")
            log("Example: cd E:\\AiCore-Splat\\InstantSplat_Windows && python aicore_setup.py patch", "INFO")
            sys.exit(1)

        patch_submodules()
        patch_gradio()
        log("\nAll patches applied. Now run:", "OK")
        log("  pip install --no-build-isolation submodules/simple-knn", "INFO")
        log("  pip install --no-build-isolation submodules/diff-gaussian-rasterization", "INFO")
        log("  pip install --no-build-isolation submodules/fused-ssim", "INFO")
        log("  cd croco/models/curope && python setup.py build_ext --inplace && cd ../../..", "INFO")

    elif args[0] == "prep":
        if len(args) < 2:
            log("Usage: python aicore_setup.py prep <image_folder> [output_folder]", "FAIL")
            sys.exit(1)
        input_folder = args[1]
        output_folder = args[2] if len(args) > 2 else None
        preprocess_images(input_folder, output_folder)

    else:
        print("Usage:")
        print("  python aicore_setup.py patch          — patch all setup.py files")
        print("  python aicore_setup.py prep <folder>  — resize + convert images")

if __name__ == "__main__":
    main()
