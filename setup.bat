@echo off
echo ========================================
echo  InstantSplat App - Windows Setup
echo ========================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    pause
    exit /b 1
)
echo [OK] Python found

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found
    pause
    exit /b 1
)
echo [OK] Node.js found

REM Check Git
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git not found
    pause
    exit /b 1
)
echo [OK] Git found

echo.
echo ========================================
echo Setting up Backend...
echo ========================================
cd backend

REM Create virtual environment
if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install PyTorch
echo Installing PyTorch...
pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118 --quiet

REM Install FastAPI requirements
echo Installing backend requirements...
pip install -r requirements.txt --quiet

REM Clone InstantSplat
if not exist "InstantSplat" (
    echo.
    echo Cloning InstantSplat repository...
    git clone --recursive https://github.com/NVlabs/InstantSplat.git
    
    echo.
    echo Setting up InstantSplat...
    cd InstantSplat
    
    REM Create checkpoints directory
    if not exist "mast3r\checkpoints" mkdir mast3r\checkpoints
    
    REM Download model (fixed - single line)
    echo Downloading MASt3R model (this may take a while - ~600MB)...
    curl -L -o mast3r\checkpoints\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth https://download.europe.naverlabs.com/ComputerVision/MASt3R/MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth
    
    REM Install InstantSplat dependencies
    echo Installing InstantSplat requirements...
    pip install -r requirements.txt --quiet
    
    REM Install submodules
    echo Installing CUDA submodules...
    pip install submodules/simple-knn --quiet
    pip install submodules/diff-gaussian-rasterization --quiet
    
    cd ..
) else (
    echo InstantSplat already installed
)

echo [OK] Backend setup complete!

REM Setup Frontend
cd ..\frontend
echo.
echo ========================================
echo Setting up Frontend...
echo ========================================

if not exist "node_modules" (
    echo Installing npm dependencies...
    call npm install --silent
) else (
    echo npm dependencies already installed
)

echo [OK] Frontend setup complete!

cd ..

echo.
echo ========================================
echo          Setup Complete!
echo ========================================
echo.
echo Next Steps:
echo.
echo 1. Start backend: startBackend.bat
echo 2. Start frontend: startFrontend.bat
echo 3. Open browser: http://localhost:3000
echo.
echo ========================================
pause