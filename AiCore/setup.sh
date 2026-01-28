#!/bin/bash

echo "🚀 AiCore - Quick Setup Script"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Python is installed
if ! command -v python &> /dev/null; then
    echo -e "${RED}❌ Python not found. Please install Python 3.9 or 3.10${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Python found: $(python --version)${NC}"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js 18.x or higher${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"

# Check CUDA
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✅ NVIDIA GPU detected${NC}"
else
    echo -e "${YELLOW}⚠️  No NVIDIA GPU detected. Will run on CPU (slower)${NC}"
fi

echo ""
echo "📦 Setting up Backend..."
cd backend

# Clone Splatt3R if not exists
if [ ! -d "splatt3r" ]; then
    echo "Cloning Splatt3R repository..."
    git clone https://github.com/btsmart/splatt3r.git
else
    echo "Splatt3R already cloned"
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install PyTorch
echo "Installing PyTorch..."
pip install torch==2.0.1 torchvision==0.15.2 --index-url https://download.pytorch.org/whl/cu118 --quiet

# Install Splatt3R dependencies
echo "Installing Splatt3R dependencies..."
cd splatt3r
pip install git+https://github.com/dcharatan/diff-gaussian-rasterization-modified --quiet
cd ..

# Install FastAPI requirements
echo "Installing FastAPI requirements..."
pip install -r requirements.txt --quiet

echo -e "${GREEN}✅ Backend setup complete!${NC}"

# Setup Frontend
cd ../frontend
echo ""
echo "📦 Setting up Frontend..."

if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm install --silent
else
    echo "npm dependencies already installed"
fi

echo -e "${GREEN}✅ Frontend setup complete!${NC}"

# Setup Electron
cd ../electron
echo ""
echo "📦 Setting up Electron..."

if [ ! -d "node_modules" ]; then
    echo "Installing Electron dependencies..."
    npm install --silent
else
    echo "Electron dependencies already installed"
fi

echo -e "${GREEN}✅ Electron setup complete!${NC}"

cd ..

echo ""
echo "==========================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Start the backend:"
echo "   cd backend"
echo "   source venv/bin/activate"
echo "   python main.py"
echo ""
echo "2. In a new terminal, start the frontend:"
echo "   cd frontend"
echo "   npm run dev"
echo ""
echo "3. (Optional) Run as Electron app:"
echo "   cd electron"
echo "   npm run dev"
echo ""
echo "📖 For detailed instructions, see README.md"
echo "==========================================="