@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo  AiCore(scan) - Full Setup Script
echo ============================================
echo.
echo  Run this from: x64 Native Tools Command Prompt for VS 2022
echo  This will take 20-40 minutes depending on your internet.
echo.
pause

:: ─── CONFIG ───────────────────────────────────
set PROJECT_DIR=D:\Projekts\Cre8TiveSync\AiCore(scan)
set CONDA_ENV=aicorescan
set PYTHON_VERSION=3.10.13
set PYTORCH_VERSION=2.1.2
set CUDA_VERSION=12.1
set MAST3R_WEIGHTS_URL=https://download.europe.naverlabs.com/ComputerVision/MASt3R/MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth

:: ─── CHECKS ───────────────────────────────────
echo [1/8] Checking prerequisites...

where conda >nul 2>&1
if errorlevel 1 (
    echo ERROR: conda not found. Please install Miniconda first.
    echo Download: https://docs.conda.io/en/latest/miniconda.html
    pause & exit /b 1
)

where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not found. Please install Node.js LTS first.
    echo Download: https://nodejs.org
    pause & exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git not found. Please install Git first.
    echo Download: https://git-scm.com
    pause & exit /b 1
)

where cl >nul 2>&1
if errorlevel 1 (
    echo ERROR: MSVC compiler (cl) not found.
    echo Please run this from x64 Native Tools Command Prompt for VS 2022.
    pause & exit /b 1
)

where nvcc >nul 2>&1
if errorlevel 1 (
    echo ERROR: nvcc not found. Please install CUDA Toolkit 12.1.
    echo Download: https://developer.nvidia.com/cuda-12-1-0-download-archive
    pause & exit /b 1
)

echo    conda  - OK
echo    node   - OK
echo    git    - OK
echo    cl     - OK
echo    nvcc   - OK

:: ─── PROJECT FOLDER ───────────────────────────
echo.
echo [2/8] Creating project folder structure...

mkdir "%PROJECT_DIR%" 2>nul
mkdir "%PROJECT_DIR%\backend" 2>nul
mkdir "%PROJECT_DIR%\backend\api" 2>nul
mkdir "%PROJECT_DIR%\backend\pipeline" 2>nul
mkdir "%PROJECT_DIR%\backend\weights" 2>nul
mkdir "%PROJECT_DIR%\frontend" 2>nul
mkdir "%PROJECT_DIR%\frontend\src" 2>nul
mkdir "%PROJECT_DIR%\frontend\src\viewer" 2>nul
mkdir "%PROJECT_DIR%\frontend\src\tools" 2>nul
mkdir "%PROJECT_DIR%\electron" 2>nul
mkdir "%PROJECT_DIR%\outputs" 2>nul

echo    Done.

:: ─── CONDA ENV ────────────────────────────────
echo.
echo [3/8] Creating fresh conda environment: %CONDA_ENV%...

call conda env remove -n %CONDA_ENV% -y 2>nul

call conda create -n %CONDA_ENV% python=%PYTHON_VERSION% cmake=3.14.0 -y
if errorlevel 1 (
    echo ERROR: Failed to create conda environment.
    pause & exit /b 1
)

call conda activate %CONDA_ENV%

:: Set all required env vars for CUDA compilation
set DISTUTILS_USE_SDK=1
set CUDA_HOME=%CONDA_PREFIX%
set CUDA_PATH=%CONDA_PREFIX%
set TORCH_CUDA_ARCH_LIST=7.5;8.6
set PATH=%CONDA_PREFIX%\Library\bin;%PATH%

echo    Installing PyTorch %PYTORCH_VERSION% with CUDA %CUDA_VERSION%...
call conda install pytorch==%PYTORCH_VERSION% torchvision pytorch-cuda=%CUDA_VERSION% -c pytorch -c nvidia -y
if errorlevel 1 (
    echo ERROR: Failed to install PyTorch.
    pause & exit /b 1
)

call pip install --no-cache-dir "numpy<2" "opencv-python<4.12"
call pip install -U pip setuptools wheel

echo    PyTorch installed.

:: ─── GSPLAT ───────────────────────────────────
echo.
echo [4/8] Installing gsplat...
echo    (gsplat compiles CUDA kernels on first run - this may take 10-15 mins)

call pip install gsplat
if errorlevel 1 (
    echo ERROR: gsplat installation failed.
    pause & exit /b 1
)

echo    gsplat installed.

:: ─── MAST3R ───────────────────────────────────
echo.
echo [5/8] Setting up MASt3R...

cd /d "%PROJECT_DIR%\backend"

if not exist "mast3r" (
    echo    Cloning MASt3R...
    git clone https://github.com/naver/mast3r.git
    if errorlevel 1 (
        echo ERROR: Failed to clone MASt3R.
        pause & exit /b 1
    )
)

cd mast3r

echo    Initializing submodules...
git submodule update --init --recursive
if errorlevel 1 (
    echo ERROR: Failed to init MASt3R submodules.
    pause & exit /b 1
)

echo    Installing MASt3R...
call pip install -e ".[dust3r]"
if errorlevel 1 (
    echo ERROR: MASt3R pip install failed.
    pause & exit /b 1
)

echo    Downloading MASt3R weights (~1.5GB)...
if not exist "%PROJECT_DIR%\backend\weights\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth" (
    powershell -Command "& { Invoke-WebRequest -Uri '%MAST3R_WEIGHTS_URL%' -OutFile '%PROJECT_DIR%\backend\weights\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth' -UseBasicParsing }"
    if errorlevel 1 (
        echo WARNING: Weight download failed. Download manually from:
        echo %MAST3R_WEIGHTS_URL%
        echo Save to: %PROJECT_DIR%\backend\weights\
    ) else (
        echo    Weights downloaded.
    )
) else (
    echo    Weights already exist, skipping.
)

cd /d "%PROJECT_DIR%\backend"

:: ─── SUGAR ────────────────────────────────────
echo.
echo [6/8] Setting up SuGaR...

if not exist "sugar" (
    echo    Cloning SuGaR...
    git clone https://github.com/Anttwo/SuGaR.git sugar
    if errorlevel 1 (
        echo ERROR: Failed to clone SuGaR.
        pause & exit /b 1
    )
)

cd sugar

echo    Installing SuGaR base dependencies...
call pip install open3d PyMCubes trimesh plyfile roma einops
call pip install -e .

:: Build SuGaR CUDA submodules with all env vars set
echo    Building SuGaR CUDA extensions...

if exist "gaussian_splatting\submodules\diff-gaussian-rasterization" (
    cd gaussian_splatting\submodules\diff-gaussian-rasterization
    call pip install -v --no-build-isolation .
    if errorlevel 1 (
        echo WARNING: diff-gaussian-rasterization failed.
        echo You may need to build this manually later.
    ) else (
        echo    diff-gaussian-rasterization OK.
    )
    cd /d "%PROJECT_DIR%\backend\sugar"
)

if exist "gaussian_splatting\submodules\simple-knn" (
    cd gaussian_splatting\submodules\simple-knn
    call pip install -v --no-build-isolation .
    if errorlevel 1 (
        echo WARNING: simple-knn failed.
        echo You may need to build this manually later.
    ) else (
        echo    simple-knn OK.
    )
    cd /d "%PROJECT_DIR%\backend\sugar"
)

cd /d "%PROJECT_DIR%"

:: ─── FASTAPI ──────────────────────────────────
echo    Installing FastAPI...
call pip install fastapi uvicorn python-multipart aiofiles

:: ─── FRONTEND ─────────────────────────────────
echo.
echo [7/8] Setting up Electron + React frontend...

cd /d "%PROJECT_DIR%\frontend"

(
echo {
echo   "name": "aicorescan-frontend",
echo   "version": "1.0.0",
echo   "private": true,
echo   "scripts": {
echo     "dev": "vite",
echo     "build": "vite build"
echo   },
echo   "dependencies": {
echo     "react": "^18.2.0",
echo     "react-dom": "^18.2.0",
echo     "three": "^0.160.0",
echo     "@react-three/fiber": "^8.15.0",
echo     "@react-three/drei": "^9.92.0"
echo   },
echo   "devDependencies": {
echo     "vite": "^5.0.0",
echo     "@vitejs/plugin-react": "^4.2.0"
echo   }
echo }
) > package.json

call npm install
if errorlevel 1 (
    echo ERROR: Frontend npm install failed.
    pause & exit /b 1
)

echo    Frontend deps installed.

cd /d "%PROJECT_DIR%\electron"

(
echo {
echo   "name": "aicorescan",
echo   "version": "1.0.0",
echo   "main": "main.js",
echo   "scripts": {
echo     "start": "electron ."
echo   },
echo   "dependencies": {
echo     "electron": "^28.0.0"
echo   }
echo }
) > package.json

call npm install
if errorlevel 1 (
    echo ERROR: Electron npm install failed.
    pause & exit /b 1
)

echo    Electron installed.

cd /d "%PROJECT_DIR%"

:: ─── START-DEV HELPER ─────────────────────────
echo.
echo [8/8] Creating start-dev.bat helper...

(
echo @echo off
echo echo ============================================
echo echo  AiCore^(scan^) Dev Environment
echo echo ============================================
echo call C:\Users\%USERNAME%\miniconda3\Scripts\activate.bat
echo call conda activate %CONDA_ENV%
echo set DISTUTILS_USE_SDK=1
echo set CUDA_HOME=%%CONDA_PREFIX%%
echo set CUDA_PATH=%%CONDA_PREFIX%%
echo set TORCH_CUDA_ARCH_LIST=7.5;8.6
echo set WEIGHTS_PATH=%PROJECT_DIR%\backend\weights\MASt3R_ViTLarge_BaseDecoder_512_catmlpdpt_metric.pth
echo cd /d "%PROJECT_DIR%"
echo echo.
echo echo  Environment ready^^!
echo echo  Commands:
echo echo    Backend  : uvicorn backend.api.main:app --reload
echo echo    Frontend : cd frontend ^&^& npm run dev
echo echo    Electron : cd electron ^&^& npm start
echo echo.
echo cmd /k
) > "%PROJECT_DIR%\start-dev.bat"

:: ─── DONE ─────────────────────────────────────
echo.
echo ============================================
echo  Setup Complete!
echo ============================================
echo.
echo  Project  : %PROJECT_DIR%
echo  Env      : %CONDA_ENV%
echo  Weights  : %PROJECT_DIR%\backend\weights\
echo.
echo  To start: run %PROJECT_DIR%\start-dev.bat
echo  (from x64 Native Tools Command Prompt)
echo.
echo  NOTE: gsplat compiles on first use - first pipeline run will be slow.
echo.
pause
