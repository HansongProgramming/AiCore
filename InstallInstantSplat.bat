@echo off
echo ========================================
echo  Installing InstantSplat Dependencies
echo ========================================
echo.

cd backend || (
    echo [ERROR] backend folder not found
    pause
    exit /b 1
)

echo Activating virtual environment...
call venv\Scripts\activate

cd InstantSplat || (
    echo [ERROR] InstantSplat folder not found
    echo Please run setup.bat first
    pause
    exit /b 1
)

echo.
echo ========================================
echo Installing InstantSplat requirements...
echo ========================================
pip install -r requirements.txt

echo.
echo ========================================
echo Installing CUDA submodules...
echo ========================================
echo.

echo Installing simple-knn...
pip install submodules/simple-knn

echo.
echo Installing diff-gaussian-rasterization...
pip install submodules/diff-gaussian-rasterization

echo.
echo ========================================
echo Verifying installation...
echo ========================================
echo.

python -c "import diff_gaussian_rasterization; print('✓ diff-gaussian-rasterization OK')" 2>nul || echo "✗ diff-gaussian-rasterization FAILED"
python -c "import simple_knn; print('✓ simple-knn OK')" 2>nul || echo "✗ simple-knn FAILED"

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo Now restart your backend:
echo   cd backend
echo   venv\Scripts\activate
echo   python main.py
echo.
pause