@echo off
echo ========================================
echo  Checking Build Requirements
echo ========================================
echo.

echo [1] Checking Python...
python --version || (
    echo [ERROR] Python not found
    pause
    exit /b 1
)
echo.

echo [2] Checking NVIDIA GPU and CUDA...
nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [WARNING] nvidia-smi not found
    echo You need an NVIDIA GPU with CUDA support
    echo.
) else (
    echo [OK] NVIDIA GPU detected:
    nvidia-smi --query-gpu=name --format=csv,noheader
    echo.
)

echo [3] Checking for Visual Studio C++ Compiler...
where cl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Microsoft Visual C++ Compiler not found
    echo.
    echo You need Visual Studio Build Tools to compile CUDA modules
    echo.
    echo Option 1: Install Visual Studio 2019/2022 Community
    echo   Download: https://visualstudio.microsoft.com/downloads/
    echo   Select: "Desktop development with C++"
    echo.
    echo Option 2: Install Build Tools for Visual Studio
    echo   Download: https://visualstudio.microsoft.com/visual-cpp-build-tools/
    echo   Select: "Desktop development with C++"
    echo.
    pause
    exit /b 1
) else (
    echo [OK] Visual C++ Compiler found:
    cl 2>&1 | findstr "Version"
    echo.
)

echo [4] Checking CUDA Toolkit...
where nvcc >nul 2>&1
if errorlevel 1 (
    echo [WARNING] CUDA Toolkit (nvcc) not found in PATH
    echo.
    echo The CUDA modules might not compile properly.
    echo.
    echo Install CUDA Toolkit 11.8:
    echo https://developer.nvidia.com/cuda-11-8-0-download-archive
    echo.
    echo After installation, add to PATH:
    echo   C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8\bin
    echo.
) else (
    echo [OK] CUDA Toolkit found:
    nvcc --version | findstr "release"
    echo.
)

echo.
echo ========================================
echo Summary
echo ========================================
echo.
echo If all checks passed, you can install CUDA modules.
echo If any checks failed, install the missing components first.
echo.
pause