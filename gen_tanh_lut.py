#!/usr/bin/env python3

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)
#
# Generate proper signed tanh lookup table for INLINE_TANH_Q88 macro.
#
# The macro maps Q8.8 input to index 0-255 via: index = (x >> 7) + 128
# So index 0 corresponds to x = -128 (Q8.8 = -0.5 approx)
#    index 128 corresponds to x = 0
#    index 255 corresponds to x = +127 (Q8.8 = +0.5 approx)
#
# Output is 8-bit signed (-128 to +127), which gets sign-extended
# and shifted left 8 to produce Q8.8 output.

import math
import struct
import os

fn = "TANH256.LUT"

# Don't overwrite existing
if os.path.exists(fn):
    print(f"{fn} already exists, skipping")
    exit(0)

with open(fn, "wb") as f:
    for i in range(256):
        # Map index to input value
        # Index 128 = input 0, scale factor chosen so edges saturate
        x = (i - 128) / 32.0  # Range: -4 to +4 (saturates tanh)

        # Compute tanh (range -1 to +1)
        t = math.tanh(x)

        # Convert to signed 8-bit (-128 to +127)
        # tanh output [-1, +1] maps to [-127, +127]
        v = int(round(t * 127))
        v = max(-128, min(127, v))

        # Pack as signed byte
        f.write(struct.pack('b', v))

print(f"{fn} generated (256 bytes, signed tanh)")
