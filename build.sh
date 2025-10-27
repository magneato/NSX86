#!/usr/bin/env bash

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

# Build Script for Neural8086 v2.0 - 8-Layer Deep Learning on 8086
# "Building the future with technology from the past..."

set -euo pipefail

# ASCII art header with proper geometry/math visualization
cat << 'EOF'
═══════════════════════════════════════════════════════════════════════
  ◈ Neural8086 Build System v2.0
  
  Neural Architecture:         B-Spline Manifold:
  784 ─┐                       B₀(t) = (1-t)³/6
      128 ─┐                   B₁(t) = (3t³-6t²+4)/6
          64 ─┐                B₂(t) = (-3t³+3t²+3t+1)/6
             32 ─┐             B₃(t) = t³/6
                16 ─┐          
                   12 ─┐       ∇L = ∂L/∂w · ∂w/∂t
                      8 ─┐     
                        6 ─┐   Bresenham: Δw = sgn(∇L) when |Σ∇L| > θ
                          10   
═══════════════════════════════════════════════════════════════════════
EOF

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_msg() {
    echo -e "${2}${1}${NC}"
}

# Check for required tools
print_msg "[1/5] Checking dependencies..." "$YELLOW"

check_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_msg "ERROR: $1 not found. Install with: $2" "$RED"
        exit 1
    else
        print_msg "  ✓ $1 found" "$GREEN"
    fi
}

check_tool "nasm" "sudo apt install nasm"
check_tool "python3" "sudo apt install python3"
check_tool "dosbox" "sudo apt install dosbox (optional but recommended)"

# Check Python packages
if ! python3 -c "import numpy" 2>/dev/null; then
    print_msg "  Installing numpy..." "$YELLOW"
    pip3 install numpy --user
fi

# Generate lookup tables
print_msg "\n[2/5] Generating lookup tables..." "$YELLOW"

for script in gen_basis_lut.py gen_deriv_lut.py gen_exp_lut.py; do
    if [[ -f "$script" ]]; then
        print_msg "  Generating via $script..." "$GREEN"
        python3 "$script"
    else
        print_msg "  WARNING: $script not found" "$YELLOW"
    fi
done

# Verify LUT files exist
for lut in BASIS256.LUT DERIV256.LUT EXP256.LUT; do
    if [[ -f "$lut" ]]; then
        size=$(wc -c < "$lut")
        print_msg "  ✓ $lut ($size bytes)" "$GREEN"
    else
        print_msg "  ERROR: $lut missing!" "$RED"
        exit 1
    fi
done

# Check for MNIST data
print_msg "\n[3/5] Checking MNIST data..." "$YELLOW"

mnist_present=true
for file in TRAIN.IDX TRAINL.IDX TEST.IDX TESTL.IDX; do
    if [[ -f "$file" ]]; then
        print_msg "  ✓ $file present" "$GREEN"
    else
        print_msg "  ✗ $file missing" "$YELLOW"
        mnist_present=false
    fi
done

if [ "$mnist_present" = false ]; then
    print_msg "  Attempting to fetch MNIST..." "$YELLOW"
    if [[ -f "setup_mnist.sh" ]]; then
        bash setup_mnist.sh
    else
        print_msg "  Run setup_mnist.sh to download MNIST data" "$YELLOW"
    fi
fi

# Assemble the program
print_msg "\n[4/5] Assembling NSX86.COM..." "$YELLOW"

# Create listing file for debugging
nasm -f bin -o NSX86.COM -l NSX86.LST NSX86LNK.ASM -I.


if [ $? -eq 0 ]; then
    size=$(stat -c%s "NSX86.COM" 2>/dev/null || wc -c < NSX86.COM)
    print_msg "  ✓ NSX86.COM built successfully! ($size bytes)" "$GREEN"
    
    if [[ $size -ge 65536 ]]; then
        print_msg "  WARNING: .COM exceeds 64KB limit!" "$RED"
        print_msg "  DOS will not be able to load this file." "$RED"
    elif [[ $size -ge 61440 ]]; then
        print_msg "  WARNING: .COM approaching 64KB limit ($(($size)) bytes)" "$YELLOW"
    fi
else
    print_msg "  ERROR: Assembly failed! Check NSX86.LST for details." "$RED"
    exit 1
fi

# Calculate model size
model_params=$((128*2 + 64*2 + 32*2 + 16*2 + 12*2 + 8*2 + 6*2 + 10*2))
model_bytes=$((model_params * 2))
header_bytes=20
total_model=$((model_bytes + header_bytes))

print_msg "\n[5/5] Build Summary" "$YELLOW"
print_msg "═══════════════════════════════════════════════════════" "$GREEN"
print_msg "  Program size:     $size bytes" "$GREEN"
print_msg "  Model parameters: $model_params control points" "$GREEN"  
print_msg "  Model size:       $total_model bytes (with header)" "$GREEN"
print_msg "  Architecture:     8-layer deep (784→128→64→32→16→12→8→6→10)" "$GREEN"
print_msg "  Optimization:     Bresenham Gradient Descent with linear noise" "$GREEN"
print_msg "  Arithmetic:       Q8.8 fixed-point (16-bit)" "$GREEN"
print_msg "  Target CPU:       Intel 8086 (4.77 MHz)" "$GREEN"
print_msg "═══════════════════════════════════════════════════════" "$GREEN"

# Quick test commands
cat << EOF

Quick test commands (running at max host speed):

Training (10 epochs, batch 32, with seed and noise):
  dosbox -c "cycles max" -c "MOUNT C ." -c "C:" -c "NSX86 TRAIN 10 32 /SEED 1984 /NOISE on"

Inference on test data:
  dosbox -c "cycles max" -c "MOUNT C ." -c "C:" -c "NSX86 INFER *"

Interactive mode:
  dosbox -c "cycles max" -c "MOUNT C ." -c "C:" -c "NSX86 INFER /I"

EOF

print_msg "Build complete! 'Hasta la vista, baby!'" "$GREEN"
