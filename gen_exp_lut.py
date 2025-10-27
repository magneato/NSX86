#!/usr/bin/env python3

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

import math, struct, os

# 256-entry exp lookup for softmax on non-positive values (after subtract max)
# index = min(255, (-x_q8_8) >> 2)  ; approx exp(x) for x<=0
def q88(x):
  v = int(round(x*256.0))
  if v<0: v=0
  if v>65535: v=65535
  return v & 0xFFFF

fn = "EXP256.LUT"
if os.path.exists(fn):
  exit(0)

with open(fn,"wb") as f:
  for i in range(256):
    x = - (i/64.0)    # from 0 to -3.984
    v = math.exp(x)
    f.write(struct.pack('<H', q88(v)))
print("EXP256.LUT generated")
