@echo off
setlocal ENABLEEXTENSIONS

echo ========================================
echo  InstantSplat App - Windows Setup
echo ========================================
echo.

REM ------------------------------
REM Check Python
REM ------------------------------
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    pause
    exit /b 1
)
echo [OK] Python found

REM ------------------------------
REM Check Node.js
REM ------------------------------
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found
    pause
    exit /b 1
)
echo [OK] Node.js found

REM ------------------------------
REM Check Git
REM ------------------------------
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

cd backend || (
    echo [ERROR] backend folder not found
    pause
    exit /b 1
)

REM ------------------------------
REM Create virtual environment
REM ------------------------------
if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

REM ------------------------------
REM Upgrade pip
REM ------------------------------
echo Upgrading pip...
venv\Scripts\python -m pip install --upgrade pip

REM ------------------------------
REM Install PyTorch (CUDA 11.8)
REM ------------------------------
echo Installing PyTorch...
venv\Scripts\pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118

REM ------------------------------
REM Install backend requirements
REM ------------------------------
echo Installing backend requirements...
venv\Scripts\pip install -r requirements.txt

REM ------------------------------
REM Clone InstantSplat
REM ------------------------------
if not exist "InstantSplat" (
    echo.
    echo Cloning InstantSplat repository...
    git clone --recursive https://github.com/NVlabs/InstantSplat.git

    cd InstantSplat || (
        echo [ERROR] Failed to enter InstantSplat directory
        pause
        exit /b 1
    )

    if not exist "mast3r\checkpoints" (
        mkdir mast3r\checkpoints
    )

    echo Downloading MASt3R model - this may take a while...
    curl -L -o mast3r\checkpoints\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth https://download.europe.naverlabs.com/ComputerVision/MASt3R/MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth

    echo Installing InstantSplat requirements...
    venv\Scripts\pip install -r requirements.txt

    echo Installing CUDA submodules...
    venv\Scripts\pip install submodules/simple-knn
    venv\Scripts\pip install submodules/diff-gaussian-rasterization

    cd ..
) else (
    echo InstantSplat already installed
)


echo [OK] Backend setup complete!

REM ------------------------------
REM Setup Frontend
REM ------------------------------
cd ..\frontend || (
    echo [ERROR] frontend folder not found
    pause
    exit /b 1
)

echo.
echo ========================================
echo Setting up Frontend...
echo ========================================

if not exist "node_modules" (
    echo Installing npm dependencies...
    npm install
) else (
    echo npm dependencies already installed
)

echo [OK] Frontend setup complete!

cd ..

echo.
echo ========================================
echo          Setup Complete!
echo ========================================
pause
