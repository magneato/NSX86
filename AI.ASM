; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; AI.ASM - Neural Net Engine (4-Layer) w/ Optimizations for 8086
; - Q8.8 fixed-point math
; - Bresenham Gradient Descent (BGD)
; - Inline activation LUT (tanh-like) optional
; - PRNG tap is mutable via lfsr_tap_word (for SMC-driven chaos)

%include "macros.inc"

; ------------------------------
; Optimization / Build switches
; ------------------------------
%define USE_PREACC_L1         1   ; Use pre-accumulated input sums on L1
%define USE_INLINE_ACTIVATION 1   ; Inline tanh LUT activation
%define USE_HARDMAX           1   ; Hardmax instead of softmax (fast)
%define ENABLE_LAYER_FREEZE   1   ; Allow freezing layers during backprop

; ------------------------------
; Public symbols (exported)
; ------------------------------
global forward_pass_4layers, softmax_fast
global backward_pass_bgd, update_params_bgd
global init_control_points, save_model, load_model
global set_seed_lfsr, set_noise_params
global input_buffer, output_probs, current_label
global bgd_steps_l1, bgd_steps_l2, bgd_steps_l3, bgd_steps_out
global reset_bgd_counters, print_bgd_stats
global print_model_checksum
global lfsr_random, ctrl_l1, grad_l1
global print_hex
%ifdef USE_PREACC_L1
global preaccumulate_input
%endif
global exp_lut_256
global lfsr_tap_word        ; <-- exported mutable PRNG tap

; ------------------------------
; Network sizes
; ------------------------------
%define INPUT_SIZE 784
%define L1         128
%define L2         64
%define L3         32
%define LOUT       10

; ------------------------------
; DATA
; ------------------------------
section .data align=16

; Activations / IO buffers
input_buffer:   times INPUT_SIZE dw 0
acts_l1:        times L1         dw 0
acts_l2:        times L2         dw 0
acts_l3:        times L3         dw 0
output_logits:  times LOUT       dw 0
output_probs:   times LOUT       dw 0
current_label:  dw 0

; Control points (2 per neuron, packed)
ctrl_l1:   times (L1*2)   dw 0
ctrl_l2:   times (L2*2)   dw 0
ctrl_l3:   times (L3*2)   dw 0
ctrl_out:  times (LOUT*2) dw 0

; BGD Error accumulators
err_l1:    times (L1*2)   dw 0
err_l2:    times (L2*2)   dw 0
err_l3:    times (L3*2)   dw 0
err_out:   times (LOUT*2) dw 0
; Gradients
grad_l1:   times (L1*2)   dw 0
grad_l2:   times (L2*2)   dw 0
grad_l3:   times (L3*2)   dw 0
grad_out:  times (LOUT*2) dw 0

; BGD thresholds (learning step proxy)
BGD_THRESHOLD_L1:  dw 0x0010
BGD_THRESHOLD_L2:  dw 0x000C
BGD_THRESHOLD_L3:  dw 0x000A
BGD_THRESHOLD_OUT: dw 0x0004

; Step counters (diagnostics)
bgd_steps_l1:      dw 0
bgd_steps_l2:      dw 0
bgd_steps_l3:      dw 0
bgd_steps_out:     dw 0

; Noise
bgd_noise_enabled: db 1
bgd_noise_scale:   dw 0x0020
bgd_noise_decay:   dw 0

; Model header (simple)
model_header:
  db 42, 'NSX8086', 'MNIST8.8'
  db 2, 5                        ; Major=2, Minor=4 (matches NSX)
header_size   equ $ - model_header
param_count:  dw (L1+L2+L3+LOUT)*2

; Strings used by higher-level module (and here)
msg_bgd_stats: db 13,10,' BGD Steps: ','$',0
msg_bgd_l1:   db 'L1=','$',0
msg_bgd_l2:   db ' L2=','$',0
msg_bgd_l3:   db ' L3=','$',0
msg_bgd_out:  db ' OUT=','$',0

msg_checksum: db 13,10,'Model CRC16: ','$',0

; Mutable LFSR tap word (default 0xB400). SMC in NSX86.ASM can change this.
lfsr_tap_word: dw 0xB400

; ------------------------------
; BSS
; ------------------------------
section .bss
lfsr_state:        resw 1
temp_buffer:       resw LOUT

; Backprop buffers
delta_out_buffer:  resw LOUT
delta_l3_buffer:   resw L3
delta_l2_buffer:   resw L2
delta_l1_buffer:   resw L1

noise_buffer:      resw 1

%ifdef USE_PREACC_L1
input_sum_even:    resw 1
input_sum_odd:     resw 1
%endif

%ifdef ENABLE_LAYER_FREEZE
freeze_l1:         resb 1
freeze_l2:         resb 1
freeze_l3:         resb 1
%endif
; ------------------------------
; TEXT
; ------------------------------
section .text

; ------------------------------
; init_control_points : simple randomized init using LFSR
; ------------------------------
init_control_points:
  push ax
  push bx
  push cx
  push di

  mov ax, [lfsr_state]
  test ax, ax
  jnz .has_seed
  mov ax, 0xACE1
.has_seed:
  mov [lfsr_state], ax

  mov di, ctrl_l1
  mov cx, (L1+L2+L3+LOUT)*2
.init_loop:
  call lfsr_random
  and ax, 0x00FF
  sub ax, 0x0080
  stosw
  dec cx
  jnz .init_loop

  pop di
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; set_seed_lfsr : AX = new seed (0 -> 0xDEAD)
; ------------------------------
set_seed_lfsr:
  test ax, ax
  jnz .ok
  mov ax, 0xDEAD
.ok:
  mov [lfsr_state], ax
  ret

; ------------------------------
; set_noise_params : AL=enable(0/1), CX=epochs -> bgd_noise_decay
; ------------------------------
set_noise_params:
  mov [bgd_noise_enabled], al
  test al, al
  jz .dis
  mov ax, [bgd_noise_scale]
  xor dx, dx
  div cx
  mov [bgd_noise_decay], ax
.dis:
  ret

; ------------------------------
; lfsr_random : AX <- pseudo-random word
;             (tap polynomial is mutable via [lfsr_tap_word])
; ------------------------------
lfsr_random:
  push bx
  mov ax, [lfsr_state]
  mov bx, ax
  shr bx, 1
  xor ax, bx
  shr bx, 1
  xor ax, bx
  shr bx, 1
  shr bx, 1
  shr bx, 1
  xor ax, bx
  shr bx, 1
  xor ax, bx
  mov bx, [lfsr_state]
  shr bx, 1
  jnc .nx
  ; CHANGED: XOR w/ mutable tap word (was immediate 0xB400)
  xor bx, [lfsr_tap_word]
.nx:
  mov [lfsr_state], bx
  pop bx
  ret

; ------------------------------
; forward_pass_4layers
; ------------------------------
forward_pass_4layers:
  push ax
  push bx
  push cx
  push dx
  push si
  push di

  ; L1: input -> acts_l1
  mov si, input_buffer
  mov di, acts_l1
  mov bx, ctrl_l1
  mov cx, L1
  mov dx, INPUT_SIZE
  call compute_layer_dense

%ifdef USE_INLINE_ACTIVATION
  mov di, acts_l1
  mov cx, L1
.fp_act1:
  mov ax, [di]
  INLINE_TANH_Q88
  mov [di], ax
  add di, 2
  dec cx
  jnz .fp_act1
%else
  mov di, acts_l1
  mov cx, L1
  call apply_activation
%endif

  ; L2: acts_l1 -> acts_l2
  mov si, acts_l1
  mov di, acts_l2
  mov bx, ctrl_l2
  mov cx, L2
  mov dx, L1
  call compute_layer_dense

%ifdef USE_INLINE_ACTIVATION
  mov di, acts_l2
  mov cx, L2
.fp_act2:
  mov ax, [di]
  INLINE_TANH_Q88
  mov [di], ax
  add di, 2
  dec cx
  jnz .fp_act2
%else
  mov di, acts_l2
  mov cx, L2
  call apply_activation
%endif
  ; L3: acts_l2 -> acts_l3
  mov si, acts_l2
  mov di, acts_l3
  mov bx, ctrl_l3
  mov cx, L3
  mov dx, L2
  call compute_layer_dense

%ifdef USE_INLINE_ACTIVATION
  mov di, acts_l3
  mov cx, L3
.fp_act3:
  mov ax, [di]
  INLINE_TANH_Q88
  mov [di], ax
  add di, 2
  dec cx
  jnz .fp_act3
%else
  mov di, acts_l3
  mov cx, L3
  call apply_activation
%endif

  ; OUT: acts_l3 -> output_logits
  mov si, acts_l3
  mov di, output_logits
  mov bx, ctrl_out
  mov cx, LOUT
  mov dx, L3
  call compute_layer_dense

  ; Convert to probabilities/index
  call softmax_fast

  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; Optional pre-accumulator for L1 input sum (speeds some ops)
; ------------------------------
%ifdef USE_PREACC_L1
preaccumulate_input:
  push ax
  push bx
  push cx
  push si
  push di

  xor di, di   ; sum_even
  xor bx, bx   ; sum_odd
  mov cx, INPUT_SIZE/2
  mov si, input_buffer
.pai_loop:
  lodsw
  add di, ax
  lodsw
  add bx, ax
  dec cx
  jnz .pai_loop
  mov [input_sum_even], di
  mov [input_sum_odd],  bx

  pop di
  pop si
  pop cx
  pop bx
  pop ax
  ret
%endif
; ------------------------------
; compute_layer_dense
; IN: SI=input ptr, BX=ctrl ptr, DI=output ptr, CX=neurons, DX=input_size
; ------------------------------
compute_layer_dense:
  push bp
  push si
  push di

  mov bp, di      ; retain output start

.neuron_loop:
  push si
  push cx
  push bx

  mov di, bp

%ifdef USE_PREACC_L1
  cmp dx, INPUT_SIZE
  jne .cld_normal
  ; First layer: use pre-accumulated sums
  mov ax, [input_sum_even]
  mov dx, [bx]
  imul dx
  mov al, ah
  mov ah, dl
  mov [di], ax

  mov ax, [input_sum_odd]
  mov dx, [bx+2]
  imul dx
  mov al, ah
  mov ah, dl
  add [di], ax
  jmp .cld_done
.cld_normal:
%endif

  mov word [di], 0
  mov cx, dx
  shr cx, 1
.cld_pair:
  mov dx, [bx]     ; w0
  lodsw            ; x[i]
  imul dx
  mov al, ah
  mov ah, dl
  add [di], ax

  mov dx, [bx+2]   ; w1
  lodsw            ; x[i+1]
  imul dx
  mov al, ah
  mov ah, dl
  add [di], ax

  dec cx
  jnz .cld_pair

%ifdef USE_PREACC_L1
.cld_done:
%endif

  pop bx
  pop cx
  pop si

  add bp, 2
  add bx, 4
  dec cx
  jnz .neuron_loop

  pop di
  pop si
  pop bp
  ret

; ------------------------------
; apply_activation (when INLINE not used)
; DI points to buffer, CX=count
; ------------------------------
%ifndef USE_INLINE_ACTIVATION
apply_activation:
  push ax
  push bx
  push di

.aa_loop:
  mov ax, [di]
  ; Inline tanh (via macro) compiled out here for clarity
  ; Clamp -> index -> XLAT -> scale to Q8.8
  cmp ax, 0x0F80
  jle .aa_not_max
  mov ax, 0x0F80
.aa_not_max:
  cmp ax, 0xF080
  jge .aa_not_min
  mov ax, 0xF080
.aa_not_min:
  push bx
  mov bx, ax
  sar bx, 1
  sar bx, 1
  sar bx, 1
  sar bx, 1
  sar bx, 1
  sar bx, 1
  sar bx, 1
  add bl, 128
  mov bh, 0
  mov al, bl
  mov bx, exp_lut_256
  xlat
  cbw
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  pop bx

  stosw
  dec cx
  jnz .aa_loop

  pop di
  pop bx
  pop ax
  ret
%endif

; ------------------------------
; BACKWARD PASS (BGD) with layer-freeze support
; ------------------------------
backward_pass_bgd:
  push ax
  push bx
  push cx
  push dx
  push si
  push di
  push bp

  ; 1) output error
  mov si, output_probs
  mov di, delta_out_buffer
  mov ax, [current_label]
  mov cx, LOUT
  call compute_output_error

  ; 2) grad_out and delta_l3
  mov si, acts_l3
  mov di, grad_out
  mov bp, delta_out_buffer
  mov cx, LOUT
  mov dx, L3
  call backprop_compute_grad

  mov si, delta_out_buffer
  mov di, delta_l3_buffer
  mov bx, ctrl_out
  mov cx, LOUT
  mov dx, L3
  call backprop_compute_delta

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l3], 1
  jz .skip_l3
%endif
  ; 3) L3
  mov si, acts_l2
  mov di, grad_l3
  mov bp, delta_l3_buffer
  mov cx, L3
  mov dx, L2
  call backprop_compute_grad

  mov si, delta_l3_buffer
  mov di, delta_l2_buffer
  mov bx, ctrl_l3
  mov cx, L3
  mov dx, L2
  call backprop_compute_delta
.skip_l3:

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l2], 1
  jz .skip_l2
%endif
  ; 4) L2
  mov si, acts_l1
  mov di, grad_l2
  mov bp, delta_l2_buffer
  mov cx, L2
  mov dx, L1
  call backprop_compute_grad

  mov si, delta_l2_buffer
  mov di, delta_l1_buffer
  mov bx, ctrl_l2
  mov cx, L2
  mov dx, L1
  call backprop_compute_delta
.skip_l2:

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l1], 1
  jz .skip_l1
%endif
  ; 5) L1
  mov si, input_buffer
  mov di, grad_l1
  mov bp, delta_l1_buffer
  mov cx, L1
  mov dx, INPUT_SIZE
  call backprop_compute_grad
.skip_l1:

  pop bp
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; compute_output_error : delta_out = pred - one_hot(label)
; ------------------------------
compute_output_error:
  push cx
  push bx

  xor bx, bx
.coe_loop:
  push ax
  mov ax, [si]
  cmp bx, [current_label]
  jne .coe_store
  sub ax, Q88_ONE
.coe_store:
  mov [di], ax
  add si, 2
  add di, 2
  inc bx
  pop ax
  dec cx
  jnz .coe_loop

  pop bx
  pop cx
  ret

; ------------------------------
; backprop_compute_grad
; IN: SI=input, DI=grad, BP=delta, CX=neurons(current), DX=input_size
; ------------------------------
backprop_compute_grad:
  push ax
  push bp
  push si
  push di
  push bx

.bpg_neuron:
  push si
  push cx

  mov ax, [bp]      ; error[j]
  mov bx, ax

  mov word [di],   0
  mov word [di+2], 0

  mov cx, dx
  shr cx, 1

%ifdef USE_PREACC_L1
  cmp dx, INPUT_SIZE
  jne .bpg_normal
  mov ax, [input_sum_even]
  mov [di], ax
  mov ax, [input_sum_odd]
  mov [di+2], ax
  jmp .bpg_sums_done
.bpg_normal:
%endif

.bpg_pair:
  lodsw
  add [di], ax
  lodsw
  add [di+2], ax
  dec cx
  jnz .bpg_pair

.bpg_sums_done:
  mov ax, [di]
  imul bx
  mov al, ah
  mov ah, dl
  mov [di], ax

  mov ax, [di+2]
  imul bx
  mov al, ah
  mov ah, dl
  mov [di+2], ax

  pop cx
  pop si

  add bp, 2
  add di, 4
  dec cx
  jnz .bpg_neuron

  pop bx
  pop di
  pop si
  pop bp
  pop ax
  ret

; ------------------------------
; backprop_compute_delta
; IN: SI=delta_curr, DI=delta_prev(out), BX=ctrl, CX=neurons, DX=prev_size
; ------------------------------
backprop_compute_delta:
  push ax
  push bp
  push si
  push di

  mov bp, di
  push cx
  mov cx, dx
  xor ax, ax
.bcd_zero:
  stosw
  dec cx
  jnz .bcd_zero
  pop cx

  mov di, bp
  mov bp, dx
  shr bp, 1

.bcd_pair:
  push si
  push bx
  push cx
  push bp

  mov bp, sp
  ; [bp+0]=outer, [bp+2]=inner, [bp+4]=ctrl, [bp+6]=delta_ptr

  xor ax, ax
  xor dx, dx
  mov cx, [bp+2]

.bcd_neuron:
  push ax
  push dx

  mov ax, [si]
  imul word [bx]     ; * ctrl[0]
  mov al, ah
  mov ah, dl
  pop dx
  add dx, ax
  pop ax

  push ax
  push dx
  mov ax, [si]
  push ax
  mov ax, [bx+2]
  pop dx
  imul dx
  pop dx
  mov al, ah
  mov ah, dl
  add dx, ax
  pop ax

  add si, 2
  add bx, 4
  dec cx
  jnz .bcd_neuron

  push ax
  mov ax, dx
  pop dx

  mov [di], ax
  push bx
  mov bx, di
  add bx, 2
  mov [bx], dx
  pop bx

  mov sp, bp
  pop bp
  pop cx
  pop bx
  pop si

  add di, 4
  dec bp
  jnz .bcd_pair

  pop di
  pop si
  pop bp
  pop ax
  ret

; ------------------------------
; update_params_bgd : runs per-layer BGD w/ optional noise
; IN: AX=current epoch, BX=max epochs (for noise decay)
; ------------------------------
update_params_bgd:
  push ax
  push bx
  push cx
  push dx
  push si
  push di

  cmp byte [bgd_noise_enabled], 0
  je .no_noise
  push ax
  push bx
  mov cx, bx
  sub cx, ax
  mov ax, [bgd_noise_scale]
  mul cx
  div bx
  mov [noise_buffer], ax
  pop bx
  pop ax
.no_noise:

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l1], 1
  jz .skip_l1
%endif
  mov si, grad_l1
  mov di, ctrl_l1
  mov bx, err_l1
  mov cx, L1*2
  mov dx, [BGD_THRESHOLD_L1]
  mov bp, bgd_steps_l1
  call bgd_update_layer
.skip_l1:

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l2], 1
  jz .skip_l2
%endif
  mov si, grad_l2
  mov di, ctrl_l2
  mov bx, err_l2
  mov cx, L2*2
  mov dx, [BGD_THRESHOLD_L2]
  mov bp, bgd_steps_l2
  call bgd_update_layer
.skip_l2:

%ifdef ENABLE_LAYER_FREEZE
  cmp byte [freeze_l3], 1
  jz .skip_l3
%endif
  mov si, grad_l3
  mov di, ctrl_l3
  mov bx, err_l3
  mov cx, L3*2
  mov dx, [BGD_THRESHOLD_L3]
  mov bp, bgd_steps_l3
  call bgd_update_layer
.skip_l3:

  ; Output layer (always)
  mov si, grad_out
  mov di, ctrl_out
  mov bx, err_out
  mov cx, LOUT*2
  mov dx, [BGD_THRESHOLD_OUT]
  mov bp, bgd_steps_out
  call bgd_update_layer

  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; bgd_update_layer : inner BGD loop w/ noise & threshold compare
; IN: SI=grad, DI=params, BX=err_acc, CX=count, DX=threshold, BP=step_counter
; ------------------------------
bgd_update_layer:
  push ax
  push cx

.bul_loop:
  mov ax, [si]                     ; gradient

  cmp byte [bgd_noise_enabled], 0
  je .bul_no_noise
  push ax
  call lfsr_random
  and ax, 0x000F
  test word [lfsr_state], 0x8000
  jz .bul_n_pos
  neg ax
.bul_n_pos:
  mov cx, [noise_buffer]
  imul cx
  ; >>8 by 8 SAR  (approx)
  sar ax, 1
  sar ax, 1
  sar ax, 1
  sar ax, 1
  sar ax, 1
  sar ax, 1
  sar ax, 1
  sar ax, 1
  pop cx
  add ax, cx
.bul_no_noise:

  add [bx], ax
  mov ax, [bx]
  cmp ax, dx
  jl .bul_no_pos
  inc word [di]
  sub [bx], dx
  inc word [bp]
  jmp .bul_next
.bul_no_pos:
  neg ax
  cmp ax, dx
  jl .bul_next
  dec word [di]
  add [bx], dx
  inc word [bp]
.bul_next:
  add si, 2
  add di, 2
  add bx, 2
  dec cx
  jnz .bul_loop

  pop cx
  pop ax
  ret
; ------------------------------
; softmax_fast : Hardmax by default (compile-time switch)
; ------------------------------
softmax_fast:
  push ax
  push bx
  push cx
  push dx
  push si
  push di

  ; Find max (value/index)
  mov si, output_logits
  mov ax, [si]
  xor bx, bx
  mov cx, LOUT-1
  add si, 2
  mov dx, 1
.sf_find:
  cmp [si], ax
  jle .sf_not_m
  mov ax, [si]
  mov bx, dx
.sf_not_m:
  add si, 2
  inc dx
  dec cx
  jnz .sf_find

%ifdef USE_HARDMAX
  mov di, output_probs
  mov cx, LOUT
  xor ax, ax
.sf_zero:
  stosw
  dec cx
  jnz .sf_zero

  mov di, output_probs
  mov cx, bx
  shl cx, 1
  add di, cx
  mov word [di], Q88_ONE
%else
  ; TODO: (Softmax branch kept for reference; not used when USE_HARDMAX)
%endif
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret
; ------------------------------
; save_model : write header + param_count + control points
; IN: DX=filename ($-terminated handled by NSX86 wrapper)
; ------------------------------
save_model:
  push ax
  push bx
  push cx
  push dx

  mov ah, 3Ch
  xor cx, cx
  int 21h
  jc .sm_err
  mov bx, ax

  mov ah, 40h
  mov dx, model_header
  mov cx, header_size
  int 21h

  mov ah, 40h
  mov dx, param_count
  mov cx, 2
  int 21h

  mov ah, 40h
  mov dx, ctrl_l1
  mov cx, (L1+L2+L3+LOUT)*2*2
  int 21h

  mov ah, 3Eh
  int 21h
.sm_err:
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; load_model : read and validate header + params
; IN: DX=filename
; OUT: CF=0 OK, CF=1 error
; ------------------------------
load_model:
  push ax
  push bx
  push cx
  push dx

  mov ah, 3Dh
  mov al, 0
  int 21h
  jc .lm_bad
  mov bx, ax

  mov ah, 3Fh
  mov dx, temp_buffer
  mov cx, header_size
  int 21h

  cmp byte [temp_buffer], 42
  jne .lm_bf

  mov ah, 3Fh
  mov dx, temp_buffer
  mov cx, 2
  int 21h

  mov ah, 3Fh
  mov dx, ctrl_l1
  mov cx, (L1+L2+L3+LOUT)*2*2
  int 21h

  mov ah, 3Eh
  int 21h
  clc
  jmp .lm_done

.lm_bf:
  mov ah, 3Eh
  int 21h
.lm_bad:
  stc
.lm_done:
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; print_model_checksum : quick rolling checksum over control points
; ------------------------------
print_model_checksum:
  push ax
  push bx
  push cx
  push dx
  push si

  mov si, ctrl_l1
  mov cx, (L1+L2+L3+LOUT)*2
  xor ax, ax
  xor bx, bx
.pmc_loop:
  lodsw
  add ax, bx
  xor bx, ax
  rol bx, 1
  dec cx
  jnz .pmc_loop

  ; "Model CRC16: " + value
  mov dx, msg_checksum
  call print_dos_str
  mov ax, bx
  call print_hex
  call print_crlf

  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret


; ------------------------------
; print_hex : AX -> hex (4 nibbles)
; ------------------------------
print_hex:
  push ax
  push bx
  push cx
  push dx

  mov cx, 4
.ph_loop:
  rol ax, 1
  rol ax, 1
  rol ax, 1
  rol ax, 1
  push ax
  mov al, ah
  shr al, 1
  shr al, 1
  shr al, 1
  shr al, 1
  and al, 0x0F
  add al, '0'
  cmp al, '9'
  jle .ph_d1
  add al, 7
.ph_d1:
  mov dl, al
  mov ah, 02h
  int 21h
  pop ax

  push ax
  and al, 0x0F
  add al, '0'
  cmp al, '9'
  jle .ph_d2
  add al, 7
.ph_d2:
  mov dl, al
  mov ah, 02h
  int 21h
  pop ax

  dec cx
  jnz .ph_loop

  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ------------------------------
; reset_bgd_counters
; ------------------------------
reset_bgd_counters:
  push ax
  xor ax, ax
  mov [bgd_steps_l1],  ax
  mov [bgd_steps_l2],  ax
  mov [bgd_steps_l3],  ax
  mov [bgd_steps_out], ax
  pop ax
  ret

; ------------------------------
; print_bgd_stats (human request, used by NSX)
; ------------------------------
print_bgd_stats:
  push ax
  push dx
  ; " BGD Steps: "
  mov dx, msg_bgd_stats
  call print_dos_str

  mov dx, msg_bgd_l1
  call print_dos_str
  mov ax, [bgd_steps_l1]
  call print_u16

  mov dx, msg_bgd_l2
  call print_dos_str
  mov ax, [bgd_steps_l2]
  call print_u16

  mov dx, msg_bgd_l3
  call print_dos_str
  mov ax, [bgd_steps_l3]
  call print_u16

  mov dx, msg_bgd_out
  call print_dos_str
  mov ax, [bgd_steps_out]
  call print_u16

  call print_crlf
  pop dx
  pop ax
  ret

; ------------------------------
; END AI.ASM
; ------------------------------