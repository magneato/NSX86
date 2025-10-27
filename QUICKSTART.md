# QUICKSTART — Neural8086 v3.1

## 1️⃣ Dependencies (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y nasm python3 python3-pip dosbox
pip3 install numpy
```

## 2️⃣ Get MNIST Data (automatic)
```bash
chmod +x setup_mnist.sh
./setup_mnist.sh
```

## 3️⃣ Build
```bash
chmod +x build.sh
./build.sh
```

## 4️⃣ Train (with enhanced BGD + linear noise)
```bash
# Quick test: 5 epochs, batch 16, seed for reproducibility
dosbox -c "MOUNT C ." -c "C:" -c "NSX86 TRAIN 5 16 /SEED 1984 /NOISE on"

# Full training: 50 epochs, batch 32
dosbox -c "MOUNT C ." -c "C:" -c "NSX86 TRAIN 50 32 /SEED 2029 /NOISE on"
```

## 5️⃣ Inference
```bash
# Test on MNIST test set
dosbox -c "MOUNT C ." -c "C:" -c "NSX86 INFER *"

# Interactive mode (draw digits)
dosbox -c "MOUNT C ." -c "C:" -c "NSX86 INFER /I"

## 🧪 Test Suite
```bash
# Run the built‑in test suite over 100 samples from the test set
dosbox -c "MOUNT C ." -c "C:" -c "NSX86 TEST"
```

The test suite opens the MNIST test dataset, runs inference on 100 examples, prints the number of correct predictions, and displays the accuracy percentage.  It also reports Bresenham Gradient Descent step statistics for each layer after training.
```

## 📊 Architecture Summary
- **Core layers**: 784 → 128 → 64 → 32 → 16 → 12 → 8 → 6 → 10  
  plus optional convolution and LSTM preprocessing stages.
- **Parameters**: approx 200 bytes total (plus 9‑byte header)  
  (includes conv, LSTM and spline control points).
- **Q8.8** 16‑bit fixed‑point arithmetic everywhere.
- **Bresenham Gradient Descent** with quantum annealing and noise decay.
- **Neural splines** implement each neuron using a handful of control values.

## 🎯 Expected Performance
- Training: ≈7 minutes on a 4.77 MHz 8086 (10 epochs).
- Accuracy: ~94% on MNIST (≈93–94% depending on random seed).
- Inference: 100+ fps.

“The future is not set. Make it with 29000 termi... I mean transistors.”
