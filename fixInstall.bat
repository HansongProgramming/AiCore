@echo off
echo ========================================
echo  InstantSplat Fixed Installation
echo ========================================
echo.

cd backend || (
    echo [ERROR] backend folder not found
    pause
    exit /b 1
)

echo Activating virtual environment...
call venv\Scripts\activate

echo.
echo ========================================
echo Fixing NumPy version conflict...
echo ========================================
echo Uninstalling NumPy 2.x...
pip uninstall numpy -y

echo Installing NumPy 1.26.4 (compatible with PyTorch 2.1.2)...
pip install "numpy<2.0" numpy==1.26.4

echo.
echo ========================================
echo Verifying PyTorch can import...
echo ========================================
python -c "import torch; print(f'PyTorch {torch.__version__} - CUDA available: {torch.cuda.is_available()}')"

if errorlevel 1 (
    echo [ERROR] PyTorch not working properly
    echo Reinstalling PyTorch...
    pip uninstall torch torchvision -y
    pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118
)

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
echo IMPORTANT: This compiles CUDA code and takes 5-10 minutes
echo Please be patient and don't close this window!
echo.

echo.
echo [1/2] Installing simple-knn...
echo.
pip install -v submodules/simple-knn

if errorlevel 1 (
    echo.
    echo [ERROR] simple-knn installation failed
    echo This is usually due to missing CUDA toolkit or compiler
    echo.
    pause
    exit /b 1
)

echo.
echo [2/2] Installing diff-gaussian-rasterization...
echo.
pip install -v submodules/diff-gaussian-rasterization

if errorlevel 1 (
    echo.
    echo [ERROR] diff-gaussian-rasterization installation failed
    echo This is usually due to missing CUDA toolkit or compiler
    echo.
    pause
    exit /b 1
)

cd ..

echo.
echo ========================================
echo Verifying installation...
echo ========================================
echo.

python -c "import torch; print('✓ PyTorch:', torch.__version__)"
python -c "import numpy; print('✓ NumPy:', numpy.__version__)"
python -c "import torchvision; print('✓ torchvision OK')"
python -c "import fastapi; print('✓ FastAPI OK')"
python -c "import diff_gaussian_rasterization; print('✓ diff-gaussian-rasterization OK')" || echo "✗ diff-gaussian-rasterization FAILED"
python -c "import simple_knn; print('✓ simple-knn OK')" || echo "✗ simple-knn FAILED"

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