"""
FastAPI Backend for InstantSplat Gaussian Splatting
Converts sparse-view smartphone photos into 3D Gaussian Splats
Faster reconstruction with SfM-free approach
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from typing import List
import torch
import os
import tempfile
import uuid
import subprocess
from pathlib import Path
import shutil

app = FastAPI(title="InstantSplat API")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
OUTPUT_DIR = Path("outputs")
OUTPUT_DIR.mkdir(exist_ok=True)
INSTANTSPLAT_DIR = Path("InstantSplat")
DEVICE = None


def check_instantsplat_installed():
    """Check if InstantSplat is properly installed"""
    if not INSTANTSPLAT_DIR.exists():
        return False
    
    required_files = [
        INSTANTSPLAT_DIR / "run_infer.py",
        INSTANTSPLAT_DIR / "mast3r" / "checkpoints" / "MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth"
    ]
    
    return all(f.exists() for f in required_files)


def initialize_device():
    """Initialize CUDA/CPU device"""
    global DEVICE
    DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {DEVICE}")
    return DEVICE


@app.on_event("startup")
async def startup_event():
    """Initialize on startup"""
    initialize_device()
    
    if not check_instantsplat_installed():
        print("WARNING: InstantSplat not found or not fully set up")
        print("Please run setup script to install InstantSplat")


@app.get("/")
async def root():
    return {
        "message": "InstantSplat API",
        "status": "running",
        "device": str(DEVICE) if DEVICE else "not initialized",
        "instantsplat_ready": check_instantsplat_installed()
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "device": str(DEVICE) if DEVICE else None,
        "cuda_available": torch.cuda.is_available(),
        "instantsplat_installed": check_instantsplat_installed()
    }


@app.post("/api/generate-splat")
async def generate_splat(
    files: List[UploadFile] = File(...),
    iterations: int = 1000
):
    """
    Generate 3D Gaussian Splat from sparse-view images
    
    Args:
        files: List of image files (JPG/PNG) - 3-10 images recommended
        iterations: Training iterations (1000-5000), more = better quality but slower
    
    Returns:
        FileResponse with .ply file
    """
    
    # Validate InstantSplat installation
    if not check_instantsplat_installed():
        raise HTTPException(
            status_code=500,
            detail="InstantSplat not installed. Please run setup script."
        )
    
    # Validate input
    if len(files) < 3:
        raise HTTPException(
            status_code=400,
            detail="Please upload at least 3 images for sparse-view reconstruction"
        )
    
    if len(files) > 20:
        raise HTTPException(
            status_code=400,
            detail="Maximum 20 images allowed"
        )
    
    if iterations < 500 or iterations > 10000:
        raise HTTPException(
            status_code=400,
            detail="Iterations must be between 500 and 10000"
        )
    
    # Create temporary directories
    scene_id = str(uuid.uuid4())
    temp_input_dir = Path(tempfile.gettempdir()) / f"instantsplat_input_{scene_id}"
    temp_output_dir = Path(tempfile.gettempdir()) / f"instantsplat_output_{scene_id}"
    temp_input_dir.mkdir(exist_ok=True)
    temp_output_dir.mkdir(exist_ok=True)
    
    try:
        # Save uploaded images
        print(f"Processing {len(files)} images...")
        for i, file in enumerate(files):
            if not file.content_type.startswith('image/'):
                raise HTTPException(
                    status_code=400,
                    detail=f"File {file.filename} is not an image"
                )
            
            # Save with numbered filenames
            ext = Path(file.filename).suffix
            image_path = temp_input_dir / f"image_{i:04d}{ext}"
            with open(image_path, "wb") as f:
                content = await file.read()
                f.write(content)
        
        # Run InstantSplat inference
        print(f"Running InstantSplat with {iterations} iterations...")
        
        cmd = [
            "python", "run_infer.py",
            str(temp_input_dir),
            str(temp_output_dir),
            "--n_views", str(len(files)),
            "--iterations", str(iterations),
            "--quiet"
        ]
        
        # Run InstantSplat
        result = subprocess.run(
            cmd,
            cwd=INSTANTSPLAT_DIR,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        if result.returncode != 0:
            print(f"InstantSplat error: {result.stderr}")
            raise HTTPException(
                status_code=500,
                detail=f"InstantSplat processing failed: {result.stderr[:200]}"
            )
        
        # Find generated PLY file
        ply_files = list(temp_output_dir.glob("**/*.ply"))
        
        if not ply_files:
            raise HTTPException(
                status_code=500,
                detail="No PLY file generated. Check InstantSplat output."
            )
        
        # Copy to outputs directory
        output_filename = f"scene_{scene_id}.ply"
        output_path = OUTPUT_DIR / output_filename
        shutil.copy2(ply_files[0], output_path)
        
        print(f"Generated Gaussian Splat: {output_path}")
        
        # Return the file
        return FileResponse(
            path=output_path,
            media_type="application/octet-stream",
            filename=output_filename,
            headers={
                "Content-Disposition": f"attachment; filename={output_filename}"
            }
        )
        
    except subprocess.TimeoutExpired:
        raise HTTPException(
            status_code=500,
            detail="Processing timeout. Try reducing iterations or number of images."
        )
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate Gaussian Splat: {str(e)}"
        )
    finally:
        # Cleanup temporary directories
        if temp_input_dir.exists():
            shutil.rmtree(temp_input_dir, ignore_errors=True)
        if temp_output_dir.exists():
            shutil.rmtree(temp_output_dir, ignore_errors=True)


@app.get("/api/outputs/{filename}")
async def get_output(filename: str):
    """Retrieve a previously generated PLY file"""
    file_path = OUTPUT_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(
        path=file_path,
        media_type="application/octet-stream",
        filename=filename
    )


@app.delete("/api/outputs/{filename}")
async def delete_output(filename: str):
    """Delete a generated PLY file"""
    file_path = OUTPUT_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    try:
        os.remove(file_path)
        return {"message": "File deleted successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete file: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)