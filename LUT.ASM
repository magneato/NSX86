; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; LUT.ASM - Lookup Table Includes
; "Pre-computed knowledge, like the T-800's mission parameters"

; Export symbols
global basis_lut_256, deriv_lut_256, exp_lut_256

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
; Exponential/Activation Lookup Table (256 bytes)
; Approximates tanh(x) for neural activation
; ------------------------------
exp_lut_256:
    incbin "EXP256.LUT"

; End of lookup tables


; Look Up! {O.O} "Your future is not set. There is no fate but what we make for ourselves."
