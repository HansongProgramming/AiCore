@echo off
echo ========================================
echo  Gaussian Splat App - Windows Setup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Please install Python 3.9 or 3.10
    echo Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo [OK] Python found: 
python --version

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found. Please install Node.js 18.x or higher
    echo Download from: https://nodejs.org/
    pause
    exit /b 1
)
echo [OK] Node.js found: 
node --version

REM Check for NVIDIA GPU
nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [WARNING] No NVIDIA GPU detected. Will run on CPU (slower)
) else (
    echo [OK] NVIDIA GPU detected
)

echo.
echo ========================================
echo Setting up Backend...
echo ========================================
cd backend

REM Clone Splatt3R if not exists
if not exist "splatt3r" (
    echo Cloning Splatt3R repository...
    git clone https://github.com/btsmart/splatt3r.git
) else (
    echo Splatt3R already cloned
)

REM Create virtual environment
if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install PyTorch (CUDA 11.8 for Windows)
echo Installing PyTorch with CUDA support...
pip install torch==2.0.1 torchvision==0.15.2 --index-url https://download.pytorch.org/whl/cu118 --quiet

REM Install Splatt3R dependencies
echo Installing Splatt3R dependencies...
cd splatt3r
pip install git+https://github.com/dcharatan/diff-gaussian-rasterization-modified --quiet
cd ..

REM Install FastAPI requirements
echo Installing FastAPI requirements...
pip install -r requirements.txt --quiet

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

REM Setup Electron
cd ..\electron
echo.
echo ========================================
echo Setting up Electron...
echo ========================================

if not exist "node_modules" (
    echo Installing Electron dependencies...
    call npm install --silent
) else (
    echo Electron dependencies already installed
)

echo [OK] Electron setup complete!

cd ..

@REM echo.
@REM echo ========================================
@REM echo          Setup Complete!
@REM echo ========================================
@REM echo.
@REM echo Next Steps:
@REM echo.
@REM echo 1. Start the backend:
@REM echo    cd backend
@REM echo    venv\Scripts\activate.bat
@REM echo    python main.py
@REM echo.
@REM echo 2. In a NEW terminal, start the frontend:
@REM echo    cd frontend
@REM echo    npm run dev
@REM echo.
@REM echo 3. (Optional) Run as Electron app:
@REM echo    cd electron
@REM echo    npm run dev
@REM echo.
@REM echo For detailed instructions, see README.md
@REM echo ========================================
@REM pause