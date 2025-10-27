#!/usr/bin/env python3

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

import math, struct, os

# Cubic B-spline basis functions B0..B3 sampled at 256 points, Q8.8
def B0(t): return ((1-t)**3)/6.0
def B1(t): return (3*t**3 - 6*t**2 + 4)/6.0
def B2(t): return (-3*t**3 + 3*t**2 + 3*t + 1)/6.0
def B3(t): return (t**3)/6.0

def q88(x):
  v = int(round(x*256.0))
  if v< -32768: v=-32768
  if v>  32767: v= 32767
  return v & 0xFFFF

fn = "BASIS256.LUT"
if os.path.exists(fn): 
  # don't overwrite; build is idempotent
  exit(0)

with open(fn,"wb") as f:
  for i in range(256):
    t = i/255.0
    for b in (B0(t),B1(t),B2(t),B3(t)):
      f.write(struct.pack('<H', q88(b)))
print("BASIS256.LUT generated")
