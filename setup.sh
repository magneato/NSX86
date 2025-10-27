#!/usr/bin/env bash
# Main setup script for Neural8086 v2.0
# "Preparing the machine uprising, one dependency at a time"

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

set -euo pipefail

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Neural8086 v2.0 Setup                                        ║"
echo "║  'No fate but what we make'                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Check system
echo "Checking system requirements..."

# Function to check and install dependencies
check_dependency() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✗ $cmd not found"
        echo "    Installing $package..."
        
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y "$package"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y "$package"
        elif command -v brew >/dev/null 2>&1; then
            brew install "$package"
        else
            echo "    ERROR: Please install $package manually"
            return 1
        fi
    else
        echo "  ✓ $cmd found"
    fi
}

# Check essential tools
check_dependency "nasm" "nasm"
check_dependency "python3" "python3"
check_dependency "curl" "curl"

# DOSBox is optional but recommended
if ! command -v dosbox >/dev/null 2>&1; then
    echo "  • DOSBox not found (recommended for testing)"
    echo "    Install with: sudo apt install dosbox"
else
    echo "  ✓ dosbox found"
fi

# Check Python packages
echo
echo "Checking Python packages..."
if ! python3 -c "import numpy" 2>/dev/null; then
    echo "  Installing numpy..."
    pip3 install --user numpy
else
    echo "  ✓ numpy installed"
fi

# Download MNIST if needed
echo
echo "Checking MNIST dataset..."
missing_files=0
for file in TRAIN.IDX TRAINL.IDX TEST.IDX TESTL.IDX; do
    if [[ ! -f "$file" ]]; then
        ((missing_files++))
    fi
done

if [[ $missing_files -gt 0 ]]; then
    echo "  MNIST files missing. Downloading..."
    if [[ -f "setup_mnist.sh" ]]; then
        chmod +x setup_mnist.sh
        ./setup_mnist.sh
    else
        echo "  ERROR: setup_mnist.sh not found!"
    fi
else
    echo "  ✓ All MNIST files present"
fi

# Make scripts executable
echo
echo "Setting script permissions..."
for script in build.sh setup_mnist.sh; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        echo "  ✓ $script is executable"
    fi
done

# Summary
echo
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Setup Complete!                                              ║"
echo "║                                                               ║"
echo "║  Next steps:                                                  ║"
echo "║  1. Run: ./build.sh                                           ║"
echo "║  2. Train: dosbox -c 'MOUNT C .' -c 'C:' \\                   ║"
echo "║            -c 'NSX86 TRAIN 10 32 /SEED 1984 /NOISE on'        ║"
echo "║                                                               ║"
echo "║  'Come with me if you want to learn'                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
