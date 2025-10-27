; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; macros.inc - 8086-safe Macro Definitions

%ifndef __MACROS_INC__
%define __MACROS_INC__

; ------------------------------
; Stack Ops
; ------------------------------
%macro PUSH_ALL 0
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
%endmacro

%macro POP_ALL 0
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
%endmacro

; ------------------------------
; Q8.8 Fixed-Point
; ------------------------------
%define Q88_ONE     0x0100
%define Q88_HALF    0x0080
%define Q88_MAX     0x7FFF
%define Q88_MIN     0x8000

; ------------------------------
; Memory Ops
; ------------------------------
%macro CLEAR_BUFFER 2 ; %1=addr, %2=word_count
    push di
    push cx
    push ax
    mov di, %1
    mov cx, %2
    xor ax, ax
    rep stosw
    pop ax
    pop cx
    pop di
%endmacro

; ------------------------------
; BGD
; ------------------------------
%macro BGD_STEP 3 ; %1=err_ptr, %2=threshold, %3=param_ptr
    mov ax, [%1]
    cmp ax, %2
    jl %%no_pos
    inc word [%3]
    sub [%1], %2
    jmp %%done
%%no_pos:
    neg ax
    cmp ax, %2
    jl %%done
    dec word [%3]
    add [%1], %2
%%done:
%endmacro

; ------------------------------
; String Ops
; ------------------------------
%macro PRINT_STRING 1 ; %1=string_ptr
    push dx
    push ax
    mov dx, %1
    mov ah, 09h
    int 21h
    pop ax
    pop dx
%endmacro

; ------------------------------
; File I/O
; ------------------------------
; (Macros for OPEN, CREATE, CLOSE, READ, WRITE removed for brevity, assumed defined elsewhere if needed)

; ------------------------------
; Constants
; ------------------------------
%define DOS_EXIT        0x4C00
%define DOS_PRINT_STR   0x09
%define DOS_PRINT_CHAR  0x02

; ------------------------------
; Optimization: Inline Activation Macro
; ------------------------------
%macro INLINE_TANH_Q88 0 ; Input AX, Output AX
    ; Clamp
    cmp ax, 0x0F80
    jle %%not_max     ; Use %% for macro-local labels
    mov ax, 0x0F80
%%not_max:
    cmp ax, 0xF080
    jge %%not_min     ; Use %% for macro-local labels
    mov ax, 0xF080
%%not_min:
    ; Index = (val >> 7) + 128 (Unrolled)
    push bx         ; Preserve BX
    mov bx, ax      ; Use BX for index calculation
    sar bx, 1
    sar bx, 1
    sar bx, 1
    sar bx, 1
    sar bx, 1
    sar bx, 1
    sar bx, 1
    add bl, 128     ; Add offset
    mov bh, 0       ; Clear high byte -> bx = index (0-255)

    ; *** XLAT FIX ***
    mov al, bl      ; Move index (0-255) into AL for XLAT
    mov bx, exp_lut_256 ; Load table base address into BX
    xlat            ; AL = DS:[BX+AL] (Standard XLAT instruction)
    ; *** END XLAT FIX ***

    cbw             ; AL -> AX (Sign extend result)
    ; Scale back to Q8.8 (Unrolled)
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    pop bx          ; Restore BX
%endmacro


%endif ; __MACROS_INC__

