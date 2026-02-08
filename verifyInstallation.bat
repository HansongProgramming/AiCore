@echo off
echo ========================================
echo  InstantSplat Installation Diagnostics
echo ========================================
echo.

echo Checking backend directory structure...
echo.

if exist "backend" (
    echo [OK] backend folder exists
) else (
    echo [ERROR] backend folder NOT found
    pause
    exit /b 1
)

cd backend

echo.
echo Current directory: %CD%
echo.

if exist "InstantSplat" (
    echo [OK] InstantSplat folder exists
) else (
    echo [ERROR] InstantSplat folder NOT found
    echo Please run setup.bat again
    pause
    exit /b 1
)

if exist "venv" (
    echo [OK] venv folder exists
) else (
    echo [ERROR] venv folder NOT found
    pause
    exit /b 1
)

if exist "main.py" (
    echo [OK] main.py exists
) else (
    echo [ERROR] main.py NOT found
    pause
    exit /b 1
)

echo.
echo Checking InstantSplat contents...
echo.

cd InstantSplat

if exist "mast3r" (
    echo [OK] mast3r folder exists
) else (
    echo [ERROR] mast3r folder NOT found
)

if exist "mast3r\checkpoints\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth" (
    echo [OK] MASt3R model checkpoint exists
) else (
    echo [ERROR] MASt3R model checkpoint NOT found
)

if exist "submodules\simple-knn" (
    echo [OK] simple-knn submodule exists
) else (
    echo [ERROR] simple-knn submodule NOT found
)

if exist "submodules\diff-gaussian-rasterization" (
    echo [OK] diff-gaussian-rasterization submodule exists
) else (
    echo [ERROR] diff-gaussian-rasterization submodule NOT found
)

cd ..

echo.
echo Checking Python packages...
echo.

venv\Scripts\python -c "import sys; print('Python version:', sys.version)"
venv\Scripts\python -c "import torch; print('PyTorch version:', torch.__version__)"
venv\Scripts\python -c "import torch; print('CUDA available:', torch.cuda.is_available())"

echo.
echo ========================================
echo Checking main.py configuration...
echo ========================================
echo.
type main.py | findstr /C:"INSTANTSPLAT_PATH" /C:"InstantSplat"

echo.
echo ========================================
echo Diagnostics Complete
echo ========================================
pause