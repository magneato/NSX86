; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; LUT.ASM - Lookup Table Includes
; "Pre-computed knowledge, like the T-800's mission parameters"

; Export symbols
global basis_lut_256, deriv_lut_256, exp_lut_256, tanh_lut_256

section .data align=16

; ------------------------------
; B-Spline Basis Functions (4×256 bytes)
; B₀(t) = (1-t)³ / 6
; B₁(t) = (3t³ - 6t² + 4) / 6
; B₂(t) = (-3t³ + 3t² + 3t + 1) / 6
; B₃(t) = t³ / 6
; ------------------------------
basis_lut_256:
    incbin "BASIS256.LUT"

; ------------------------------
; Derivative Lookup Table (256 bytes)
; For computing gradients during backpropagation
; ------------------------------
deriv_lut_256:
    incbin "DERIV256.LUT"

; ------------------------------
; Exponential Lookup Table (512 bytes, 16-bit words)
; For softmax: exp(-x) where x in [0, 4]
; ------------------------------
exp_lut_256:
    incbin "EXP256.LUT"

; ------------------------------
; Tanh Activation Lookup Table (256 bytes, signed 8-bit)
; Proper signed tanh for INLINE_TANH_Q88 macro
; Index 128 = tanh(0) = 0, range [-127, +127]
; ------------------------------
tanh_lut_256:
    incbin "TANH256.LUT"

; End of lookup tables


; Look Up! {O.O} "Your future is not set. There is no fate but what we make for ourselves."
