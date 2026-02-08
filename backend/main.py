import os
import sys
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import shutil
import subprocess
import json

app = FastAPI()

# CORS settings - Allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Get the backend directory (where main.py is located)
BACKEND_DIR = Path(__file__).parent.absolute()
INSTANTSPLAT_PATH = BACKEND_DIR / "InstantSplat"
UPLOAD_DIR = BACKEND_DIR / "uploads"
OUTPUT_DIR = BACKEND_DIR / "outputs"

# Create necessary directories
UPLOAD_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

def check_instantsplat():
    """Check if InstantSplat is properly installed"""
    checks = {
        "instantsplat_dir": INSTANTSPLAT_PATH.exists(),
        "mast3r_dir": (INSTANTSPLAT_PATH / "mast3r").exists(),
        "checkpoint": (INSTANTSPLAT_PATH / "mast3r" / "checkpoints" / "MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth").exists(),
        "simple_knn": (INSTANTSPLAT_PATH / "submodules" / "simple-knn").exists(),
        "diff_gaussian": (INSTANTSPLAT_PATH / "submodules" / "diff-gaussian-rasterization").exists(),
    }
    
    return checks

@app.get("/")
async def root():
    return {
        "message": "InstantSplat Backend API",
        "backend_dir": str(BACKEND_DIR),
        "instantsplat_path": str(INSTANTSPLAT_PATH),
        "status": "online"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint with detailed status"""
    checks = check_instantsplat()
    
    all_ok = all(checks.values())
    
    return {
        "status": "ok" if all_ok else "error",
        "instantsplat_installed": all_ok,
        "checks": checks,
        "paths": {
            "backend": str(BACKEND_DIR),
            "instantsplat": str(INSTANTSPLAT_PATH),
            "uploads": str(UPLOAD_DIR),
            "outputs": str(OUTPUT_DIR),
        }
    }

@app.post("/upload")
async def upload_images(files: list[UploadFile] = File(...)):
    """Upload images for 3D reconstruction"""
    
    # Check InstantSplat installation
    checks = check_instantsplat()
    if not all(checks.values()):
        missing = [k for k, v in checks.items() if not v]
        raise HTTPException(
            status_code=500,
            detail={
                "error": "InstantSplat not properly installed",
                "missing_components": missing,
                "checks": checks
            }
        )
    
    if not files or len(files) < 3:
        raise HTTPException(status_code=400, detail="Please upload at least 3 images")
    
    # Create a unique session directory
    import uuid
    session_id = str(uuid.uuid4())[:8]
    session_dir = UPLOAD_DIR / session_id
    session_dir.mkdir(exist_ok=True)
    
    # Save uploaded files
    saved_files = []
    for file in files:
        file_path = session_dir / file.filename
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        saved_files.append(str(file_path))
    
    return {
        "message": f"Uploaded {len(files)} images successfully",
        "session_id": session_id,
        "files": saved_files
    }

@app.post("/reconstruct/{session_id}")
async def reconstruct(session_id: str):
    """Run InstantSplat reconstruction"""
    
    session_dir = UPLOAD_DIR / session_id
    if not session_dir.exists():
        raise HTTPException(status_code=404, detail="Session not found")
    
    output_dir = OUTPUT_DIR / session_id
    output_dir.mkdir(exist_ok=True)
    
    # Get Python from virtual environment
    if sys.platform == "win32":
        python_exe = BACKEND_DIR / "venv" / "Scripts" / "python.exe"
    else:
        python_exe = BACKEND_DIR / "venv" / "bin" / "python"
    
    if not python_exe.exists():
        raise HTTPException(
            status_code=500,
            detail=f"Python virtual environment not found at {python_exe}"
        )
    
    # InstantSplat command
    cmd = [
        str(python_exe),
        str(INSTANTSPLAT_PATH / "run.py"),
        str(session_dir),
        "--output_dir", str(output_dir),
    ]
    
    try:
        # Run InstantSplat
        result = subprocess.run(
            cmd,
            cwd=str(INSTANTSPLAT_PATH),
            capture_output=True,
            text=True,
            timeout=600  # 10 minute timeout
        )
        
        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail={
                    "error": "InstantSplat processing failed",
                    "stdout": result.stdout,
                    "stderr": result.stderr
                }
            )
        
        # Find the output .ply file
        ply_files = list(output_dir.glob("*.ply"))
        if not ply_files:
            raise HTTPException(
                status_code=500,
                detail="No .ply file generated"
            )
        
        return {
            "message": "Reconstruction successful",
            "session_id": session_id,
            "output_file": ply_files[0].name
        }
        
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="Reconstruction timeout")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/download/{session_id}/{filename}")
async def download_result(session_id: str, filename: str):
    """Download the resulting .ply file"""
    
    file_path = OUTPUT_DIR / session_id / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(
        path=file_path,
        filename=filename,
        media_type="application/octet-stream"
    )

if __name__ == "__main__":
    import uvicorn
    
    print("\n" + "="*50)
    print("InstantSplat Backend Starting...")
    print("="*50)
    print(f"Backend Directory: {BACKEND_DIR}")
    print(f"InstantSplat Path: {INSTANTSPLAT_PATH}")
    print("\nChecking installation...")
    
    checks = check_instantsplat()
    for name, status in checks.items():
        symbol = "✓" if status else "✗"
        print(f"  {symbol} {name}: {'OK' if status else 'MISSING'}")
    
    if all(checks.values()):
        print("\n✓ All checks passed!")
    else:
        print("\n✗ Some components are missing. Please run setup.bat")
    
    print("\nStarting server on http://localhost:8000")
    print("CORS enabled for all origins")
    print("="*50 + "\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000)