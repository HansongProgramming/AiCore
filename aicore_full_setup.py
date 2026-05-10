# =============================================================================
# AiCore InstantSplat - Full Setup Script
# Run this from the x64 Native Tools Command Prompt for VS 2022
# as Administrator on a fresh machine.
#
# Usage:
#   cd <directory where you want InstantSplat installed>
#   python aicore_full_setup.py
# =============================================================================

import os
import re
import sys
import subprocess
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

REPO_URL    = "https://github.com/jonstephens85/InstantSplat_Windows.git"
INSTALL_DIR = Path(".")
CONDA_ENV   = "instantsplat"
PYTHON_VER  = "3.10.13"
CUDA_VER    = "12.1"

MAST3R_WEIGHTS_URL = (
    "https://download.europe.naverlabs.com/ComputerVision/MASt3R/"
    "MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg, level="INFO"):
    icons = {"INFO": "  ", "OK": "✓ ", "FAIL": "✗ ", "STEP": "\n▶ ", "WARN": "⚠ "}
    print(f"{icons.get(level, '  ')}{msg}", flush=True)

def run(cmd, cwd=None, check=True):
    log(f"Running: {cmd}", "INFO")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if check and result.returncode != 0:
        log(f"Command failed: {cmd}", "FAIL")
        sys.exit(1)
    return result.returncode == 0

def patch_file(filepath, find, replace, label):
    path = Path(filepath)
    if not path.exists():
        log(f"Not found, skipping: {label}", "WARN")
        return
    content = path.read_text(encoding="utf-8")
    if "--allow-unsupported-compiler" in content:
        log(f"Already patched: {label}", "OK")
        return
    if find not in content:
        log(f"Pattern not found in {label} — check manually", "WARN")
        return
    path.write_text(content.replace(find, replace), encoding="utf-8")
    log(f"Patched: {label}", "OK")

# ── Step 1: Clone repo ────────────────────────────────────────────────────────

def clone_repo():
    log("Cloning InstantSplat_Windows", "STEP")
    target = INSTALL_DIR / "InstantSplat_Windows"
    if target.exists():
        log("Repo already exists, skipping clone", "OK")
        return target
    run(f'git clone --recursive {REPO_URL} "{target}"')
    log("Clone complete", "OK")
    return target

# ── Step 2: Download model weights ───────────────────────────────────────────

def download_weights(repo_dir):
    log("Downloading MASt3R model weights (1.5GB)", "STEP")
    weights_dir = repo_dir / "mast3r" / "checkpoints"
    weights_dir.mkdir(parents=True, exist_ok=True)
    weights_file = weights_dir / "MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth"
    if weights_file.exists():
        log("Weights already downloaded, skipping", "OK")
        return
    run(f'curl -L -o "{weights_file}" {MAST3R_WEIGHTS_URL}')
    log("Weights downloaded", "OK")

# ── Step 3: Create conda env ──────────────────────────────────────────────────

def setup_conda_env():
    log(f"Setting up conda env: {CONDA_ENV}", "STEP")
    result = subprocess.run("conda env list", shell=True, capture_output=True, text=True)
    if CONDA_ENV in result.stdout:
        log(f"Conda env '{CONDA_ENV}' already exists, skipping", "OK")
        return
    # Accept TOS silently
    run("conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main", check=False)
    run("conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r", check=False)
    run("conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2", check=False)
    run(f"conda create -n {CONDA_ENV} python={PYTHON_VER} cmake=3.14.0 -y")
    log("Conda env created", "OK")

# ── Step 4: Install PyTorch ───────────────────────────────────────────────────

def install_pytorch():
    log("Installing PyTorch with CUDA support", "STEP")
    run(
        f"conda run -n {CONDA_ENV} conda install pytorch torchvision "
        f"pytorch-cuda={CUDA_VER} -c pytorch -c nvidia -y"
    )
    log("PyTorch installed", "OK")

# ── Step 5: Install Python dependencies ───────────────────────────────────────

def install_deps(repo_dir):
    log("Installing Python dependencies", "STEP")
    run(f'conda run -n {CONDA_ENV} pip install -r "{repo_dir / "requirements.txt"}"')
    run(f'conda run -n {CONDA_ENV} pip install plyfile open3d "imageio[ffmpeg]"')
    log("Dependencies installed", "OK")

# ── Step 6: Patch all setup.py files ─────────────────────────────────────────

def patch_all(repo_dir):
    log("Patching submodule setup.py files", "STEP")

    # simple-knn
    patch_file(
        repo_dir / "submodules/simple-knn/setup.py",
        'extra_compile_args={"nvcc": [], "cxx": cxx_compiler_flags})',
        'extra_compile_args={"nvcc": ["--allow-unsupported-compiler", "-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"], "cxx": cxx_compiler_flags})',
        "simple-knn"
    )

    # diff-gaussian-rasterization
    patch_file(
        repo_dir / "submodules/diff-gaussian-rasterization/setup.py",
        'extra_compile_args={"nvcc": ["-I" + os.path.join(os.path.dirname(os.path.abspath(__file__)), "third_party/glm/")]})',
        'extra_compile_args={"nvcc": ["-I" + os.path.join(os.path.dirname(os.path.abspath(__file__)), "third_party/glm/"), "--allow-unsupported-compiler", "-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"]})',
        "diff-gaussian-rasterization"
    )

    # fused-ssim
    fused_path = repo_dir / "submodules/fused-ssim/setup.py"
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

    # curope
    patch_file(
        repo_dir / "croco/models/curope/setup.py",
        "nvcc=['-O3','--ptxas-options=-v',\"--use_fast_math\"]+all_cuda_archs,",
        "nvcc=['-O3','--ptxas-options=-v',\"--use_fast_math\",\"--allow-unsupported-compiler\",\"-D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH\"]+all_cuda_archs,",
        "curope"
    )

    # Gradio view limit
    gradio_path = repo_dir / "instantsplat_gradio.py"
    if gradio_path.exists():
        content = gradio_path.read_text(encoding="utf-8")
        patched = re.sub(r'(gr\.Slider\([^)]*maximum\s*=\s*)12', r'\g<1>50', content)
        if patched != content:
            gradio_path.write_text(patched, encoding="utf-8")
            log("Gradio view limit raised to 50", "OK")
        else:
            log("Gradio already patched or pattern changed", "OK")

# ── Step 7: Compile submodules ────────────────────────────────────────────────

def compile_submodules(repo_dir):
    log("Compiling CUDA submodules", "STEP")

    env_vars = "set DISTUTILS_USE_SDK=1 && set MSSdk=1 && "

    submodules = [
        "submodules/simple-knn",
        "submodules/diff-gaussian-rasterization",
        "submodules/fused-ssim",
    ]

    for sub in submodules:
        log(f"Compiling {sub}", "INFO")
        run(f'{env_vars} conda run -n {CONDA_ENV} pip install --no-build-isolation "{repo_dir / sub}"')
        log(f"Done: {sub}", "OK")

    # curope — use direct python.exe to preserve env vars (conda run strips them)
    log("Compiling curope (RoPE kernels)", "INFO")
    curope_dir = repo_dir / "croco" / "models" / "curope"
    env = os.environ.copy()
    env["DISTUTILS_USE_SDK"] = "1"
    env["MSSdk"] = "1"
    python_exe = Path(os.path.expanduser("~")) / "miniconda3" / "envs" / CONDA_ENV / "python.exe"
    subprocess.run(
        f'"{python_exe}" setup.py build_ext --inplace',
        shell=True, cwd=str(curope_dir), env=env, check=True
    )
    log("Done: curope", "OK")

# ── Step 8: Validate ──────────────────────────────────────────────────────────

def validate():
    log("Validating installation", "STEP")
    checks = [
        ("torch + CUDA",                "import torch; assert torch.cuda.is_available(), 'CUDA not available'"),
        ("simple_knn",                  "import simple_knn"),
        ("diff_gaussian_rasterization", "import diff_gaussian_rasterization"),
        ("fused_ssim",                  "import fused_ssim"),
    ]
    all_passed = True
    for label, code in checks:
        result = subprocess.run(
            f'conda run -n {CONDA_ENV} python -c "{code}"',
            shell=True, capture_output=True
        )
        if result.returncode == 0:
            log(label, "OK")
        else:
            log(f"{label} FAILED", "FAIL")
            all_passed = False

    if all_passed:
        log("\nInstallation complete! To run:", "OK")
        log(f"  conda activate {CONDA_ENV}", "INFO")
        log(f"  cd InstantSplat_Windows", "INFO")
        log(f"  python instantsplat_gradio.py", "INFO")
        log(f"  Open http://127.0.0.1:7860", "INFO")
    else:
        log("\nSome checks failed. Review errors above.", "FAIL")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    log("AiCore InstantSplat Full Setup", "STEP")
    log("Make sure you are running from x64 Native Tools Command Prompt for VS 2022", "WARN")

    repo_dir = clone_repo()
    download_weights(repo_dir)
    setup_conda_env()
    install_pytorch()
    install_deps(repo_dir)
    patch_all(repo_dir)
    compile_submodules(repo_dir)
    validate()

if __name__ == "__main__":
    main()
