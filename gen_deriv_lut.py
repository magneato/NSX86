#!/usr/bin/env python3

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

import math, struct, os

# Derivatives of cubic B-splines at 256 points, Q8.8
def dB0(t): return -0.5*(1-t)**2
def dB1(t): return 0.5*(3*t*t - 4*t)
def dB2(t): return 0.5*(-3*t*t + 2*t + 1)
def dB3(t): return 0.5*(t*t)

def q88(x):
  v = int(round(x*256.0))
  if v< -32768: v=-32768
  if v>  32767: v= 32767
  return v & 0xFFFF

fn = "DERIV256.LUT"
if os.path.exists(fn):
  exit(0)

with open(fn,"wb") as f:
  for i in range(256):
    t = i/255.0
    for b in (dB0(t),dB1(t),dB2(t),dB3(t)):
      f.write(struct.pack('<H', q88(b)))
print("DERIV256.LUT generated")
