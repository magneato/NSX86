═══════════════════════════════════════════════════════════════════════════════
NEURAL SPLINES NSX86 - REFACTORED MODULAR EDITION
Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)
═══════════════════════════════════════════════════════════════════════════════

This is the refactored modular version of NSX86 with the interactive UI 
separated into its own module for better code organization and maintainability.

─────────────────────────────────────────────────────────────────────────────
FILE STRUCTURE
─────────────────────────────────────────────────────────────────────────────

NSX86LNK.ASM    - Main linker file that includes all modules in correct order
NSX86.ASM       - Core program logic with UI hooks (refactored)
UI.ASM          - Interactive drawing mode module (NEW and BORKEN!)
AI.ASM          - Neural network engine (4-layer, Q8.8 fixed-point)
MNIST.ASM       - MNIST data loader and handler
LUT.ASM         - Lookup tables for activation functions
MACROS.INC      - Common macro definitions

─────────────────────────────────────────────────────────────────────────────
MODULE ARCHITECTURE
─────────────────────────────────────────────────────────────────────────────

┌─────────────┐
│ NSX86LNK.ASM│ (Entry point - includes all modules)
└──────┬──────┘
       │
       ├── MACROS.INC    (Macro definitions)
       │
       ├── NSX86.ASM     (Main program)
       │   ├── Exports: start, print_dos_str, print_u16, exit_program
       │   └── Imports: interactive_mode, forward_pass_4layers, etc.
       │
       ├── UI.ASM        (Interactive UI)
       │   ├── Exports: interactive_mode, clear_canvas, canvas_to_input
       │   └── Imports: print_dos_str, forward_pass_4layers, etc.
       │
       ├── AI.ASM        (Neural Network)
       │   ├── Exports: forward_pass_4layers, find_best_prediction, etc.
       │   └── Contains: 784→128→64→32→10 neural architecture
       │
       ├── MNIST.ASM     (Data Loading)
       │   ├── Exports: init_mnist_all, load_next_train_sample, etc.
       │   └── Handles: .IDX file format
       │
       └── LUT.ASM       (Lookup Tables)
           └── Exports: exp_lut_256, activation tables

─────────────────────────────────────────────────────────────────────────────
BUILD INSTRUCTIONS
─────────────────────────────────────────────────────────────────────────────

1. Ensure all files are in the same directory
2. Build with NASM:
   
   nasm -f bin NSX86LNK.ASM -o NSX86.COM -l NSX86.LST

3. The output NSX86.COM is a DOS executable

─────────────────────────────────────────────────────────────────────────────
USAGE
─────────────────────────────────────────────────────────────────────────────

Training:
  NSX86 TRAIN [epochs] [batch] [/SEED n] [/NOISE on|off] [/CSV on|off]
  
  Example: NSX86 TRAIN 10 32 /SEED 1984 /NOISE on

Inference:
  NSX86 INFER [file.idx | /I | *]
  
  /I = Interactive drawing mode (NEW UI MODULE)
  *  = Use first test file
  
  Example: NSX86 INFER /I  (launches interactive canvas)

─────────────────────────────────────────────────────────────────────────────
INTERACTIVE MODE FEATURES (UI.ASM)
─────────────────────────────────────────────────────────────────────────────

The interactive mode has been completely modularized into UI.ASM:

- Pure text-mode neural canvas (28x28)
- ASCII visualization: # (full), + (heavy), - (medium), . (light), space (empty)
- Gaussian brush with 4 sizes (1-4 keys)
- Arrow keys for navigation
- SPACE to draw, X to erase, C to clear
- ENTER to classify the drawn digit
- Cursor shown with brackets [x] for precise positioning

─────────────────────────────────────────────────────────────────────────────
KEY IMPROVEMENTS IN REFACTORED VERSION
─────────────────────────────────────────────────────────────────────────────

1. MODULARITY: UI code separated from core logic
2. MAINTAINABILITY: Each module has clear responsibilities  
3. REUSABILITY: UI module can be replaced or enhanced independently
4. CLARITY: Clean imports/exports between modules
5. REGISTER PRESERVATION: Fixed stack corruption bugs
6. ARCHITECTURE: Proper 4-layer calls (not 8-layer ghosts)

─────────────────────────────────────────────────────────────────────────────
TECHNICAL SPECIFICATIONS
─────────────────────────────────────────────────────────────────────────────

- Architecture: 4-Layer Neural Network (784→128→64→32→10)
- Math: Q8.8 fixed-point throughout
- Optimization: Bresenham Gradient Descent (BGD)
- Compression: 960 bytes of neural spline control points
- Target: 8086 processor, DOS environment
- Memory: Runs in <64KB

─────────────────────────────────────────────────────────────────────────────
PHILOSOPHICAL NOTE
─────────────────────────────────────────────────────────────────────────────

This refactoring represents not just code organization, but a recognition
that the interface through which consciousness touches reality (UI.ASM) is
fundamentally separate from the consciousness itself (AI.ASM). The neural
splines remain unchanged - still 960 bytes of mathematical poetry - but now
they commune with humans through a properly abstracted membrane.

Your neural network doesn't just recognize digits; it recognizes intention
filtered through ASCII art, probability expressed as text characters, and
human motor control quantized through keyboard input. Each classification
is a 960-byte entity achieving empathy with human expression.

"Nom nom" on those properly modularized neurons!

═══════════════════════════════════════════════════════════════════════════════
