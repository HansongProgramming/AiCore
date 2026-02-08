@echo off
echo ========================================
echo  InstantSplat Complete Reinstall
echo ========================================
echo.

REM Check Python version
python --version
echo.

echo IMPORTANT: InstantSplat requires Python 3.9, 3.10, or 3.11
echo Python 3.13 is NOT supported!
echo.
echo Current Python version:
python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
echo.

python -c "import sys; exit(0 if sys.version_info >= (3,9) and sys.version_info < (3,12) else 1)"
if errorlevel 1 (
    echo.
    echo [ERROR] Wrong Python version!
    echo.
    echo You need Python 3.9, 3.10, or 3.11
    echo Please install from: https://www.python.org/downloads/
    echo.
    echo Recommended: Python 3.11.9
    echo Download: https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
    echo.
    pause
    exit /b 1
)

echo [OK] Python version is compatible!
echo.

cd backend || (
    echo [ERROR] backend folder not found
    pause
    exit /b 1
)

echo ========================================
echo Deleting old virtual environment...
echo ========================================
if exist venv (
    rmdir /s /q venv
    echo Old venv deleted
)

echo.
echo ========================================
echo Creating new virtual environment...
echo ========================================
python -m venv venv
call venv\Scripts\activate

echo.
echo ========================================
echo Upgrading pip...
echo ========================================
python -m pip install --upgrade pip

echo.
echo ========================================
echo Installing PyTorch with CUDA 11.8...
echo ========================================
pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118

echo.
echo Verifying PyTorch installation...
python -c "import torch; print(f'PyTorch {torch.__version__} installed'); print(f'CUDA available: {torch.cuda.is_available()}')"

echo.
echo ========================================
echo Installing backend requirements...
echo ========================================
pip install -r requirements.txt

echo.
echo ========================================
echo Installing InstantSplat requirements...
echo ========================================
cd InstantSplat || (
    echo [ERROR] InstantSplat folder not found
    pause
    exit /b 1
)

pip install -r requirements.txt

echo.
echo ========================================
echo Installing CUDA submodules...
echo ========================================
echo.
echo This will compile CUDA code - it may take 5-10 minutes...
echo.

echo Installing simple-knn...
pip install submodules/simple-knn

echo.
echo Installing diff-gaussian-rasterization...
pip install submodules/diff-gaussian-rasterization

cd ..

echo.
echo ========================================
echo Verifying installation...
echo ========================================
echo.

python -c "import torch; print('✓ PyTorch:', torch.__version__)"
python -c "import torchvision; print('✓ torchvision OK')"
python -c "import fastapi; print('✓ FastAPI OK')"
python -c "import diff_gaussian_rasterization; print('✓ diff-gaussian-rasterization OK')" 2>nul || echo "✗ diff-gaussian-rasterization FAILED"
python -c "import simple_knn; print('✓ simple-knn OK')" 2>nul || echo "✗ simple-knn FAILED"

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo To start the backend:
echo   cd backend
echo   venv\Scripts\activate
echo   python main.py
echo.
pause