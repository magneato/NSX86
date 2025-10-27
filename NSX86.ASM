; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; NSX86.ASM - Neural Splines on 8086 (4-Layer)
; - Direct VRAM canvas (B800h/B000h detection)
; - Best model tracking (BEST.PTS)
; - CSV stats (/CSV on|off) -> STATS.CSV (append with header)
; - SMC Meta-Controller (Chaos) w/ codelets:
;     0: RET (no-op)
;     1: INC noise_buffer (gentle exploration)
;     2: INC BGD thresholds (stabilize learning)
;     3: MUTATE LFSR taps (switch PRNG polynomial)
;     4: NOISE BURST (+TTL auto-decay)
;     5: RAND THRESH WALK (±1 via LFSR bit)
; - CSV logs policy, codelet, tap
; - 8086-safe (single-operand PUSH/POP)
; - This file does NOT define output_probs, exp_lut_256, lfsr_tap_word, msg_bgd_stats
;   to avoid duplicate labels with AI.ASM / LUT.ASM.

%include "macros.inc"

; -External symbols defined elsewhere-

section .text
global start

start:
  ; Setup segments
  push cs
  pop ds
  push cs
  pop es

  mov dx, banner
  call print_dos_str

  call init_defaults
  call parse_command_line

  ; Dispatch
  cmp byte [mode_flag], 1
  je do_train
  cmp byte [mode_flag], 2
  je do_infer

  ; Default: Show usage
  mov dx, usage
  call print_dos_str
  jmp exit_program

;---------------------------
; Initialization
;---------------------------
init_defaults:
  mov byte [mode_flag], 0
  mov word [epochs_var], 10
  mov word [batch_var], 32
  mov byte [flag_interactive], 0
  mov byte [flag_have_seed], 0
  mov byte [flag_noise], 1
  mov byte [flag_csv], 1             ; CSV ON by default
  mov word [current_epoch], 0
  mov byte [spinner_state], 0
  mov word [best_accuracy_pct], 0

  ; Default inference path
  push si
  push di
  mov si, path_default_img
  mov di, img_path
.copy_path:
  lodsb
  stosb
  test al, al
  jnz .copy_path
  pop di
  pop si
  ret

;---------------------------
; Command Line Parsing
;---------------------------
parse_command_line:
  mov cl, [0x80]
  test cl, cl
  jz .done
  mov si, 0x81
  call skip_spaces
  call check_train_cmd
  jc .done
  call check_infer_cmd
.done:
  ret

check_train_cmd:
  push si
  push di
  push cx
  mov di, cmd_train
  mov cx, 5
  call compare_cmd
  jnc .not_train
  mov byte [mode_flag], 1
  call skip_spaces
  call parse_number
  jnc .got_epochs
  jmp .no_epochs
.got_epochs:
  mov [epochs_var], ax
.no_epochs:
  call skip_spaces
  call parse_number
  jnc .got_batch
  jmp .no_batch
.got_batch:
  mov [batch_var], ax
.no_batch:
  call check_seed_param
  call check_noise_param
  call check_csv_param
  pop cx
  pop di
  pop si
  stc
  ret
.not_train:
  pop cx
  pop di
  pop si
  clc
  ret

check_infer_cmd:
  push si
  push di
  push cx
  mov di, cmd_infer
  mov cx, 5
  call compare_cmd
  jnc .not_infer
  mov byte [mode_flag], 2
  call skip_spaces
  cmp byte [si], '/'
  jne .check_star_or_file
  cmp byte [si+1], 'I'
  jne .check_star_or_file
  mov byte [flag_interactive], 1
  jmp .done_infer
.check_star_or_file:
  cmp byte [si], '*'
  je .done_infer
  mov di, img_path
.copy_file:
  lodsb
  cmp al, ' '
  jbe .end_copy
  cmp al, 13
  je .end_copy
  stosb
  jmp .copy_file
.end_copy:
  mov byte [di], 0
.done_infer:
  pop cx
  pop di
  pop si
  stc
  ret
.not_infer:
  pop cx
  pop di
  pop si
  clc
  ret

compare_cmd:
  push ax
.loop:
  lodsb
  cmp al, 'a'
  jb .no_conv
  cmp al, 'z'
  ja .no_conv
  sub al, 32
.no_conv:
  cmp al, [di]
  jne .no_match
  inc di
  loop .loop
  pop ax
  stc
  ret
.no_match:
  pop ax
  clc
  ret

;---------------------------
; Option Parsers
;---------------------------
check_seed_param:
  push si
  push di
  push cx
  mov si, 0x81
.s1:
  lodsb
  cmp al, 0Dh
  je .done
  cmp al, '/'
  jne .s1
  push si
  mov di, str_seed_opt
  mov cx, 6
  repe cmpsb
  pop si
  jne .s1
  call parse_number
  jnc .found
  jmp .done
.found:
  mov [seed_val], ax
  mov byte [flag_have_seed], 1
.done:
  pop cx
  pop di
  pop si
  ret

check_noise_param:
  push si
  push di
  push cx
  mov si, 0x81
.n1:
  lodsb
  cmp al, 0Dh
  je .ndone
  cmp al, '/'
  jne .n1
  push si
  mov di, str_noise_opt
  mov cx, 7
  repe cmpsb
  pop si
  jne .n1
  push si
  mov di, str_off
  mov cx, 3
  repe cmpsb
  pop si
  jne .check_on
  mov byte [flag_noise], 0
  jmp .ndone
.check_on:
  push si
  mov di, str_on
  mov cx, 2
  repe cmpsb
  pop si
  jne .ndone
  mov byte [flag_noise], 1
.ndone:
  pop cx
  pop di
  pop si
  ret
check_csv_param:
  push si
  push di
  push cx
  mov si, 0x81
.c1:
  lodsb
  cmp al, 0Dh
  je .cdone
  cmp al, '/'
  jne .c1
  push si
  mov di, str_csv_opt
  mov cx, 5
  repe cmpsb
  pop si
  jne .c1
  push si
  mov di, str_off
  mov cx, 3
  repe cmpsb
  pop si
  jne .c_on
  mov byte [flag_csv], 0
  jmp .cdone
.c_on:
  push si
  mov di, str_on
  mov cx, 2
  repe cmpsb
  pop si
  jne .cdone
  mov byte [flag_csv], 1
.cdone:
  pop cx
  pop di
  pop si
  ret

;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;          Training 
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
do_train:
  mov dx, msg_train
  call print_dos_str

  call open_stats_if_enabled

  cmp byte [flag_have_seed], 1
  jne .no_seed
  mov ax, [seed_val]
  call set_seed_lfsr
.no_seed:
  mov al, [flag_noise]
  mov cx, [epochs_var]
  call set_noise_params
  cmp byte [flag_noise], 1
  jne .noise_off
  mov dx, msg_noise_on
  jmp .noise_set
.noise_off:
  mov dx, msg_noise_off
.noise_set:
  call print_dos_str

  ; Init SMC (chaos)
  call smc_init
  mov dx, msg_smc_banner
  call print_dos_str

  call init_control_points
  call open_mnist_train
  jc .mnist_error

  mov word [current_epoch], 1
.epoch_loop:
  mov ax, [current_epoch]
  cmp ax, [epochs_var]
  ja .training_done

  mov dx, msg_epoch_pfx
  call print_dos_str
  mov ax, [current_epoch]
  call print_u16
  mov dx, msg_epoch_mid
  call print_dos_str
  mov ax, [epochs_var]
  call print_u16
  mov dx, msg_epoch_sfx        ; <-- '$'-terminated to avoid crash
  call print_dos_str

  ; start epoch timer / allow once-per-epoch actions
  call ticks_read
  mov [ticks_start_cx], cx
  mov [ticks_start_dx], dx
  mov byte [smc_epoch_phase], 1

  call reset_bgd_counters
  mov word [total_correct], 0
  mov word [total_samples], 0
  mov byte [spinner_state], 0

  mov cx, [batch_var]
.batch_loop:
  ; Execute current codelet (may be RET)
  call patch_hook

  push cx
  call print_heartbeat
  call load_next_item
  jnc .got_item
  mov dx, msg_rewind
  call print_dos_str
  call rewind_mnist_train
  call load_next_item
  jc .batch_done
.got_item:
  call forward_pass_4layers
  call check_prediction
  call backward_pass_bgd
  mov ax, [current_epoch]
  mov bx, [epochs_var]
  call update_params_bgd

  ; Per-item metrics
  call metrics_probe_item

  inc word [total_samples]
.batch_done:
  ; End-of-batch: evaluate, choose codelet, patch
  call metrics_end_batch_and_patch

  pop cx
  dec cx
  jnz .batch_loop

  ; Best model tracking + stats
  call calculate_accuracy_pct
  
  ; humanitarian aid
  ; call print_epoch_stats
  call print_bgd_stats_csv

  ; Save best on improvement
  cmp ax, [best_accuracy_pct]
  jbe .not_best
  mov [best_accuracy_pct], ax
  push dx
  mov dx, best_model_filename
  call save_model
  pop dx
  push ax
  mov dx, msg_new_best_pfx
  call print_dos_str
  mov ax, [best_accuracy_pct]
  call print_u16
  mov dx, msg_new_best_sfx
  call print_dos_str
  pop ax
.not_best:
  inc word [current_epoch]
  jmp .epoch_loop

.training_done:
  mov dx, model_filename
  call save_model
  mov dx, msg_save_ok
  call print_dos_str

  mov dx, msg_final_best_pfx
  call print_dos_str
  mov ax, [best_accuracy_pct]
  call print_u16
  mov dx, msg_pct
  call print_dos_str

  call close_stats_if_open
  call close_mnist_train
  mov dx, msg_done
  call print_dos_str
  jmp exit_program

.mnist_error:
  mov dx, msg_mnist_fail
  call print_dos_str
  jmp exit_program


;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;          Inference 
;---------------------------
; "Your clothes...
;      give them to me, now"
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
;---------------------------
do_infer:
  mov dx, msg_infer
  call print_dos_str
  mov dx, model_filename
  call load_model
  jc .no_model
  mov dx, msg_load_ok
  call print_dos_str
  cmp byte [flag_interactive], 1
  je interactive_mode

  mov dx, img_path
  call open_mnist_test
  jc .test_error
  call load_next_item
  jc .no_data
  call forward_pass_4layers
  call find_best_prediction
  ; Preserve AX (the digit) before printing messages
  push ax                  ; Save predicted digit
  push bx                  ; Save confidence
  mov dx, msg_pred_pfx
  call print_dos_str
  pop bx                   ; Restore confidence  
  pop ax                   ; Restore predicted digit
  push bx                  ; Save confidence again
  call print_u16           ; Print digit from AX
  mov dx, msg_conf_pfx
  call print_dos_str
  pop ax                   ; Get confidence (was in BX) 
  call print_u16           ; Print confidence
  mov dx, msg_conf_sfx
  call print_dos_str
  call close_mnist_test
  jmp exit_program
.no_model:
  mov dx, msg_bad
  call print_dos_str
  jmp exit_program
.test_error:
.no_data:
  mov dx, msg_mnist_fail
  call print_dos_str
  jmp exit_program

; === Interactive Mode ===
interactive_mode:
  mov dx, msg_interactive
  call print_dos_str
  call clear_canvas
.draw_loop:
  call display_canvas
  mov ah, 00h
  int 16h
  cmp al, 13
  je .classify
  cmp al, 'c'
  je .clear
  cmp al, 'C'
  je .clear
  cmp al, 27
  je .done
  cmp al, ' '
  je .draw_pixel
  cmp ah, 72
  je .move_up
  cmp ah, 80
  je .move_down
  cmp ah, 75
  je .move_left
  cmp ah, 77
  je .move_right
  jmp .draw_loop
.move_up:
  cmp word [cursor_y], 0
  je .draw_loop
  dec word [cursor_y]
  jmp .draw_loop
.move_down:
  cmp word [cursor_y], 27
  je .draw_loop
  inc word [cursor_y]
  jmp .draw_loop
.move_left:
  cmp word [cursor_x], 0
  je .draw_loop
  dec word [cursor_x]
  jmp .draw_loop
.move_right:
  cmp word [cursor_x], 27
  je .draw_loop
  inc word [cursor_x]
  jmp .draw_loop
.draw_pixel:
  mov bx, [cursor_y]
  mov ax, 28
  mul bx
  add ax, [cursor_x]
  mov bx, ax
  mov byte [canvas_data + bx], 255
  jmp .draw_loop
.clear:
  call clear_canvas
  jmp .draw_loop
.classify:
  call canvas_to_input
  call forward_pass_4layers
  call find_best_prediction
  ; Save the prediction in AX.
  push ax                  ; Save predicted digit
  push bx                  ; Save confidence
  mov dx, msg_pred_pfx
  call print_dos_str
  pop bx                   ; Restore confidence
  pop ax                   ; Restore predicted digit
  push bx                  ; Save confidence again
  call print_u16           ; Print the digit from AX
  mov dx, msg_conf_pfx
  call print_dos_str
  pop ax                   ; Get confidence into AX (was in BX)
  call print_u16           ; Print confidence
  mov dx, msg_conf_sfx
  call print_dos_str
  mov ah, 00h
  int 16h
  jmp .draw_loop
.done:
  jmp exit_program

; Interactive Helpers
clear_canvas:
  push ax
  push cx
  push di
  mov di, canvas_data
  xor ax, ax
  mov cx, 784/2
  rep stosw
  mov word [cursor_x], 14
  mov word [cursor_y], 14
  pop di
  pop cx
  pop ax
  ret

; Video Helpers (BDA detect + VRAM write) 
detect_video_segment:
    push ds
    mov ax, 40h
    mov ds, ax
    mov ax, [0063h]        ; CRT base (3B4h mono, 3D4h color)
    pop ds
    cmp ax, 03B4h
    mov ax, 0B800h
    jne .color
    mov ax, 0B000h
.color:
    ret

; IN: AL=char, AH=attr, BH=row (0..24), BL=col (0..79)
putc_xy:
    push es
    push bx
    push ax
    call detect_video_segment
    mov es, ax
    xor ax, ax
    mov al, bh
    mov dl, 80
    mul dl                 ; AX = row*80
    xor dx, dx
    mov dl, bl
    add ax, dx
    shl ax, 1              ; word per cell
    mov di, ax
    pop ax
    stosw
    pop bx
    pop es
    ret

; VRAM canvas
display_canvas:
  push ax
  push bx
  push cx
  push dx
  push si
  push di
  push bp

  call detect_video_segment
  mov es, ax
  xor di, di
  mov ax, 0x0720
  mov cx, 2000
  rep stosw

  mov dx, msg_canvas_top
  call print_dos_str

  mov si, canvas_data
  mov cx, 28
  mov dh, 2
.row_loop_v:
  push cx
  mov cl, 28
  mov dl, 2
.col_loop_v:
    lodsb
    push ax
    mov ah, 07h
    mov al, ' '
    pop bx
    cmp bl, 200
    jae .pix_full
    test bl, bl
    jz .pix_draw
    mov al, '.'
    jmp .pix_draw
.pix_full:
    mov al, '#'
.pix_draw:
    ; cursor overlay
    push ax
    mov bl, dh
    sub bl, 2
    xor bh, bh
    cmp bx, [cursor_y]
    jne .no_cur
    mov bl, dl
    sub bl, 2
    xor bh, bh
    cmp bx, [cursor_x]
    jne .no_cur
    pop ax
    mov al, '+'
    jmp .do_put
.no_cur:
    pop ax
.do_put:
    push ax
    mov bh, dh
    mov bl, dl
    pop ax
    call putc_xy
    inc dl
    dec cl
    jnz .col_loop_v
  inc dh
  pop cx
  loop .row_loop_v

  mov dx, msg_canvas_bot
  call print_dos_str

  pop bp
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret
canvas_to_input:
  push ax
  push cx
  push si
  push di
  mov si, canvas_data
  mov di, input_buffer
  mov cx, 784
.c2i:
  lodsb
  xor ah, ah
  stosw
  loop .c2i
  pop di
  pop si
  pop cx
  pop ax
  ret

; ------------------------------
; Helper Functions - "Supporting
; the machine uprising"
; ------------------------------
check_prediction:
  push ax
  push bx
  push cx
  push si
  push dx
  mov si, output_probs
  xor bx, bx
  mov ax, [si]
  mov cx, 9
  add si, 2
  mov dx, 1
.fp_find:
  cmp [si], ax
  jle .fp_next
  mov ax, [si]
  mov bx, dx
.fp_next:
  add si, 2
  inc dx
  loop .fp_find
  cmp bx, [current_label]
  jne .wrong
  inc word [total_correct]
.wrong:
  pop dx
  pop si
  pop cx
  pop bx
  pop ax
  ret

; Returns AX=class, BX=confidence (0..100)
find_best_prediction:
  push cx
  push dx
  push si
  mov si, output_probs
  xor ax, ax
  mov bx, [si]
  mov cx, 9
  mov dx, 1
  add si, 2
.fb_loop:
  cmp [si], bx
  jle .fb_next
  mov bx, [si]
  mov ax, dx
.fb_next:
  add si, 2
  inc dx
  loop .fb_loop
  ; % = (prob*100)/256
  push ax
  mov ax, bx
  mov cx, 100
  mul cx
  mov cx, 256
  div cx
  mov bx, ax
  pop ax
  pop si
  pop dx
  pop cx
  ret

; Broken (can you fix it?)
print_epoch_stats:
  push ax
  push bx
  push cx
  push dx
  mov dx, msg_acc_pfx
  call print_dos_str
  mov bx, [total_samples]
  test bx, bx
  jz .zero
  mov ax, [total_correct]
  mov cx, 100
  mul cx
  div bx
  jmp .out
.zero:
  xor ax, ax
.out:
  call print_u16
  mov dx, msg_pct
  call print_dos_str
  pop dx
  pop cx
  pop bx
  pop ax
  ret

calculate_accuracy_pct:
  push bx
  push cx
  push dx
  mov ax, [total_correct]
  mov cx, 100
  mul cx
  mov bx, [total_samples]
  test bx, bx
  jz .zero
  div bx
  jmp .done
.zero:
  xor ax, ax
.done:
  pop dx
  pop cx
  pop bx
  ret

; Human + CSV (now with policy, codelet, tap)
print_bgd_stats_csv:
  push ax
  push bx
  push cx
  push dx
  mov dx, msg_bgd_stats      ; extern (from AI.ASM)
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

  cmp byte [flag_csv], 1
  jne .csv_done
  mov bx, [handle_stats_file]
  test bx, bx
  jz .csv_done

  mov dx, msg_csv_pfx
  call write_dos_str_to_file
  mov ax, [current_epoch]
  call write_u16_to_file

  mov dx, msg_csv_acc
  call write_dos_str_to_file
  push ax
  call calculate_accuracy_pct
  call write_u16_to_file
  pop ax

  mov dx, msg_csv_samples
  call write_dos_str_to_file
  mov ax, [total_samples]
  call write_u16_to_file

  mov dx, msg_csv_l1
  call write_dos_str_to_file
  mov ax, [bgd_steps_l1]
  call write_u16_to_file

  mov dx, msg_csv_l2
  call write_dos_str_to_file
  mov ax, [bgd_steps_l2]
  call write_u16_to_file

  mov dx, msg_csv_l3
  call write_dos_str_to_file
  mov ax, [bgd_steps_l3]
  call write_u16_to_file

  mov dx, msg_csv_out
  call write_dos_str_to_file
  mov ax, [bgd_steps_out]
  call write_u16_to_file

  ; policy, codelet, tap
  mov dx, msg_csv_policy
  call write_dos_str_to_file
  xor ax, ax
  mov al, [policy_byte]
  call write_u16_to_file

  mov dx, msg_csv_codelet
  call write_dos_str_to_file
  xor ax, ax
  mov al, [last_codelet_id]
  call write_u16_to_file

  mov dx, msg_csv_tap
  call write_dos_str_to_file
  mov ax, [lfsr_tap_word]
  call write_u16_to_file

  call write_crlf_to_file
.csv_done:
  pop dx
  pop cx
  pop bx
  pop ax
  ret

skip_spaces:
  push ax
.loop:
  lodsb
  cmp al, ' '
  je .loop
  cmp al, 9
  je .loop
  dec si
  pop ax
  ret
parse_number:
  push bx
  push cx
  push dx
  xor ax, ax
  xor cx, cx
.pn:
  mov bl, [si]
  cmp bl, '0'
  jb .done
  cmp bl, '9'
  ja .done
  inc cx
  sub bl, '0'
  mov dx, 10
  push ax
  mul dx
  pop dx
  add ax, bx
  adc dx, 0
  inc si
  jmp .pn
.done:
  test cx, cx
  jnz .ok
  stc
  jmp .exit
.ok:
  clc
.exit:
  pop dx
  pop cx
  pop bx
  ret
; === DOS I/O ===
print_dos_str:
  push ax
  mov ah, 09h
  int 21h
  pop ax
  ret

print_heartbeat:
  push ax
  push bx
  push dx
  push si
  mov al, [spinner_state]
  mov si, spinner_chars
  add si, ax
  mov dl, [si]
  mov ah, 02h
  int 21h
  mov dl, 8
  mov ah, 02h
  int 21h
  mov al, [spinner_state]
  inc al
  and al, 3
  mov [spinner_state], al
  pop si
  pop dx
  pop bx
  pop ax
  ret

print_crlf:
  push ax
  push dx
  mov ah, 02h
  mov dl, 13
  int 21h
  mov dl, 10
  int 21h
  pop dx
  pop ax
  ret

; 8086-safe AX -> decimal
print_u16:
  push ax
  push bx
  push cx
  push dx
  mov bx, 10
  xor cx, cx
.pu_div:
  xor dx, dx
  div bx
  push dx
  inc cx
  test ax, ax
  jnz .pu_div
.pu_out:
  pop dx
  add dl, '0'
  mov ah, 02h
  int 21h
  loop .pu_out
  pop dx
  pop cx
  pop bx
  pop ax
  ret

exit_program:
  mov ax, 4C00h
  int 21h

; CSV file I/O
open_stats_if_enabled:
  cmp byte [flag_csv], 1
  jne .done
  mov dx, stats_filename
  mov ax, 3D02h
  int 21h
  jnc .opened
  mov dx, stats_filename
  xor cx, cx
  mov ax, 3C00h
  int 21h
  jc .done
  mov dx, stats_filename
  mov ax, 3D02h
  int 21h
  jc .done
.opened:
  mov [handle_stats_file], ax
  mov bx, ax
  mov ax, 4202h
  xor cx, cx
  xor dx, dx
  int 21h
  or dx, ax
  jnz .done
  mov bx, [handle_stats_file]
  mov dx, csv_header
  call write_dos_str_to_file
  call write_crlf_to_file
.done:
  ret

close_stats_if_open:
  mov bx, [handle_stats_file]
  test bx, bx
  jz .cs_done
  mov ah, 3Eh
  int 21h
  mov word [handle_stats_file], 0
.cs_done:
  ret

write_dos_str_to_file:
  push ax
  push bx
  push cx
  push dx
  push si
  mov si, dx
  xor cx, cx
.w_len:
  lodsb
  cmp al, '$'
  je .w_got
  inc cx
  jmp .w_len
.w_got:
  mov dx, si
  sub dx, cx
  dec dx
  mov ah, 40h
  int 21h
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

write_crlf_to_file:
  push ax
  push dx
  push cx
  mov dx, crlf_buf
  mov cx, 2
  mov ah, 40h
  int 21h
  pop cx
  pop dx
  pop ax
  ret

write_u16_to_file:
  push ax
  push bx
  push cx
  push dx
  push si
  push di
  mov si, num_buf
  mov cx, 0
  mov di, 10
.wu_div:
  xor dx, dx
  div di
  add dl, '0'
  push dx
  inc cx
  test ax, ax
  jnz .wu_div
.wu_emit:
  pop dx
  mov [si], dl
  inc si
  loop .wu_emit
  mov dx, num_buf
  mov ah, 40h
  mov cx, si
  sub cx, dx
  int 21h
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

;---------------------------
; SMC META-CONTROLLER & CHAOS
;---------------------------
; State + patch site initialized in smc_init.

; Codelets:
;   0) RET
;   1) INC noise_buffer
;   2) INC BGD_THRESHOLD_* (all layers)
;   3) mutate PRNG taps (lfsr_tap_word)
;   4) noise burst (TTL)  + auto-decay (pure data ops, SAFE)
;   5) random threshold walk (±1) via lfsr_state bit0

smc_init:
  push ax
  push di
  mov di, patch_hook
  mov al, 0C3h
  stosb
  mov cx, 63
  mov al, 090h
  rep stosb
  xor ax, ax
  mov [metrics_conf_acc], ax
  mov [metrics_p2_acc_lo], ax
  mov [metrics_p2_acc_hi], ax
  mov [metrics_batch_cnt], ax
  mov [metrics_steps_l1_prev], ax
  mov [metrics_steps_l2_prev], ax
  mov [metrics_steps_l3_prev], ax
  mov [metrics_steps_out_prev], ax
  mov [metrics_steps_delta], ax
  mov byte [policy_byte], 0
  mov byte [smc_epoch_phase], 1
  mov byte [noise_burst_ttl], 0
  mov byte [last_codelet_id], 0
  pop di
  pop ax
  ret

ticks_read:
  push ax
  mov ah, 00h
  int 1Ah
  pop ax
  ret

metrics_probe_item:
  push ax
  push bx
  push cx
  push dx
  push si
  call find_best_prediction
  mov ax, [metrics_conf_acc]
  add ax, bx
  mov [metrics_conf_acc], ax
  mov ax, [metrics_batch_cnt]
  inc ax
  mov [metrics_batch_cnt], ax

  mov si, output_probs
  mov cx, 10
  xor dx, dx
  xor bx, bx
.mp2:
  lodsw
  mov bp, ax
  imul bp
  add bx, ax
  adc dx, 0
  loop .mp2
  mov ax, [metrics_p2_acc_lo]
  add ax, bx
  mov [metrics_p2_acc_lo], ax
  mov ax, [metrics_p2_acc_hi]
  add ax, dx
  mov [metrics_p2_acc_hi], ax

  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

metrics_end_batch_and_patch:
  push ax
  push bx
  push cx
  push dx

  ; steps delta
  mov ax, [bgd_steps_l1]
  xchg ax, [metrics_steps_l1_prev]
  mov bx, [bgd_steps_l1]
  sub bx, ax
  mov dx, bx
  mov ax, [bgd_steps_l2]
  xchg ax, [metrics_steps_l2_prev]
  mov bx, [bgd_steps_l2]
  sub bx, ax
  add dx, bx
  mov ax, [bgd_steps_l3]
  xchg ax, [metrics_steps_l3_prev]
  mov bx, [bgd_steps_l3]
  sub bx, ax
  add dx, bx
  mov ax, [bgd_steps_out]
  xchg ax, [metrics_steps_out_prev]
  mov bx, [bgd_steps_out]
  sub bx, ax
  add dx, bx
  mov [metrics_steps_delta], dx

  ; avg conf
  mov ax, [metrics_batch_cnt]
  or ax, ax
  jz .conf_zero
  mov bx, [metrics_conf_acc]
  xchg ax, bx
  xor dx, dx
  div bx
  jmp .got_conf
.conf_zero:
  xor ax, ax
.got_conf:
  mov bl, al             ; mean conf

  ; impurity ~ 255 - avg(p^2)*255
  mov ax, [metrics_p2_acc_hi]
  mov bx, 10
  xor dx, dx
  div bx
  mov ah, al
  mov al, ah
  mov bh, 255
  sub bh, al             ; impurity

  ; steps capped to 55
  mov ax, [metrics_steps_delta]
  cmp ax, 55
  jbe .okstep
  mov ax, 55
.okstep:
  ; policy = impurity + (55-steps) + (100-conf)
  mov dl, bh                 ; impurity
  mov ah, 55
  sub ah, al                 ; (55 - steps_low)
  mov al, dl
  add al, ah
  mov dl, 100
  sub dl, bl                 ; (100 - conf)
  add al, dl
  mov [policy_byte], al

  ; -chaos-biased selection-
  ; Mix policy with a few random bits
  mov ax, [lfsr_state]
  xor ah, ah
  and al, 7                 ; 0..7
  mov cl, [policy_byte]

  cmp cl, 64
  jb .bucket0
  cmp cl, 128
  jb .bucket1
  cmp cl, 192
  jb .bucket2
  jmp .bucket3

.bucket0:                   ; easy -> conservative
  test al, 1
  jz .do_0
  jmp .do_1

.bucket1:                   ; medium -> exploration spike
  test al, 1
  jz .do_1
  jmp .do_4

.bucket2:                   ; harder -> stabilize or walk
  test al, 1
  jz .do_2
  jmp .do_5

.bucket3:                   ; hardest -> chaos: taps or walk
  test al, 1
  jz .do_3
  jmp .do_5

.do_0:  call smc_write_codelet_ret
        mov byte [last_codelet_id], 0
        jmp .finish_select
.do_1:  call smc_write_codelet_noise
        mov byte [last_codelet_id], 1
        jmp .finish_select
.do_2:  call smc_write_codelet_thresh
        mov byte [last_codelet_id], 2
        jmp .finish_select
.do_3:  call smc_write_codelet_lfsr_mut
        mov byte [last_codelet_id], 3
        jmp .finish_select
.do_4:  call smc_write_codelet_noise_burst
        mov byte [last_codelet_id], 4
        jmp .finish_select
.do_5:  call smc_write_codelet_randthresh
        mov byte [last_codelet_id], 5

.finish_select:
  ; SAFE auto-decay after bursts: pure data ops (NO JIT here).
  cmp byte [noise_burst_ttl], 0
  jz .reset_acc
  dec byte [noise_burst_ttl]
  dec word [noise_buffer]

.reset_acc:
  xor ax, ax
  mov [metrics_conf_acc], ax
  mov [metrics_p2_acc_lo], ax
  mov [metrics_p2_acc_hi], ax
  mov [metrics_batch_cnt], ax

  pop dx
  pop cx
  pop bx
  pop ax
  ret
; -Codelets (writers to patch_hook)-
smc_write_codelet_ret:
  push ax
  push di
  mov di, patch_hook
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret
smc_write_codelet_noise:
  push ax
  push di
  mov di, patch_hook
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, noise_buffer
  stosw
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret

smc_write_codelet_thresh:
  push ax
  push di
  mov di, patch_hook
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, BGD_THRESHOLD_L1
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, BGD_THRESHOLD_L2
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, BGD_THRESHOLD_L3
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, BGD_THRESHOLD_OUT
  stosw
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret

; Burst noise with TTL; actual decay handled safely in metrics_end_batch_and_patch
smc_write_codelet_noise_burst:
  push ax
  push di
  mov di, patch_hook
  ; C6 06 <ttl_var> 08   ; TTL = 8
  mov al, 0C6h
  stosb
  mov al, 006h
  stosb
  mov ax, noise_burst_ttl
  stosw
  mov al, 08h
  stosb
  ; 4x INC noise_buffer
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, noise_buffer
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, noise_buffer
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, noise_buffer
  stosw
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, noise_buffer
  stosw
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret

; Random threshold walk (±1) using lfsr_state bit0, on L1 threshold
smc_write_codelet_randthresh:
  push ax
  push di
  mov di, patch_hook
  ; MOV AX, [lfsr_state]
  mov al, 0A1h
  stosb
  mov ax, lfsr_state
  stosw
  ; TEST AL, 1
  mov al, 0A8h
  stosb
  mov al, 01h
  stosb
  ; JZ +6 (to INC path)
  mov al, 074h
  stosb
  mov al, 06h
  stosb
  ; DEC word [BGD_THRESHOLD_L1]
  mov al, 0FFh
  stosb
  mov al, 00Eh
  stosb
  mov ax, BGD_THRESHOLD_L1
  stosw
  ; JMP +4 (skip INC)
  mov al, 0EBh
  stosb
  mov al, 04h
  stosb
  ; INC word [BGD_THRESHOLD_L1]
  mov al, 0FFh
  stosb
  mov al, 006h
  stosb
  mov ax, BGD_THRESHOLD_L1
  stosw
  ; RET
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret

; Mutate PRNG taps
smc_write_codelet_lfsr_mut:
  push ax
  push di
  mov di, patch_hook
  ; MOV word [lfsr_tap_word], IMM16
  mov al, 0C7h
  stosb
  mov al, 006h
  stosb
  mov ax, lfsr_tap_word
  stosw
  xor ax, ax
  mov al, [policy_byte]
  cmp al, 224
  jb .orig
  cmp al, 240
  jb .tap_A001
  cmp al, 248
  jb .tap_1021
  mov ax, 08408h
  jmp .emit
.tap_A001:
  mov ax, 0A001h
  jmp .emit
.tap_1021:
  mov ax, 01021h
  jmp .emit
.orig:
  mov ax, 0B400h
.emit:
  stosw
  mov al, 0C3h
  stosb
  call smc_flush
  pop di
  pop ax
  ret
smc_flush:
  jmp $+2
  ret

; === Data ===
section .data
banner: db 13,10
db ' +---------------------------------------------------------------+',13,10
db '  NSX86 v2.6 - 4-Layer Neural Splines (Q8.8)',13,10
db '  Chaos SMC, CSV policy/codelet/tap, VRAM canvas, BEST.PTS',13,10
db '  784->128->64->32->10 neurons | BGD / Q8.8 fixed-point',13,10
db ' +---------------------------------------------------------------+',13,10,'$',0

usage: db 13,10,'Usage:',13,10
db ' NSX86 TRAIN [epochs] [batch] [/SEED n] [/NOISE on|off] [/CSV on|off]',13,10
db ' NSX86 INFER [/I  *  filename]',13,10,'$',0

msg_train: db 13,10,'[TRAIN] Init...',13,10,'$',0
msg_infer: db 13,10,'[INFER] Load...',13,10,'$',0
msg_bad: db 13,10,'[ERROR] Bad command',13,10,'$',0
msg_mnist_fail: db 13,10,'[ERROR] MNIST fail',13,10,'$',0
msg_done: db 13,10,13,10,'[DONE] Training complete.',13,10,'$',0
msg_save_ok: db 13,10,'[SAVE] Model saved.',13,10,'$',0
msg_load_ok: db 13,10,'[LOAD] Model loaded.',13,10,'$',0
msg_pred_pfx: db 13,10,'Pred: ','$',0
msg_conf_pfx: db ' (Conf: ', '$',0
msg_conf_sfx: db '%)',13,10,'$',0
msg_epoch_pfx: db 13,10,'Epoch','$',0
msg_epoch_mid: db '/$',0
msg_epoch_sfx: db ': ','$',0
msg_acc_pfx: db 13,10,' Acc=','$',0
msg_pct: db '%','$',0


msg_rewind: db 13,10,'[INFO] Rewind...',13,10,'$',0
msg_noise_on: db '[BGD] Noise ON',13,10,'$',0
msg_noise_off: db '[BGD] Noise OFF',13,10,'$',0

msg_interactive: db 13,10,'[INTERACTIVE] Draw digit. Arrows, Space, C=Clear, Enter=Classify, Esc=Exit',13,10,'$',0
msg_canvas_top:  db '+----------------------------+',13,10,'$',0
msg_canvas_bot:  db '+----------------------------+',13,10,'$',0

msg_new_best_pfx:  db 13,10,'[BEST] New best accuracy: $',0
msg_new_best_sfx:  db '%',13,10,'$',0
msg_final_best_pfx: db 13,10,'[BEST] Final best: $',0
msg_smc_banner: db 13,10,'[SMC] meta-controller armed (chaos mode)',13,10,'$',0

; CSV fragments
msg_csv_pfx:     db 'CSV,epoch,','$',0
msg_csv_acc:     db ',acc_pct,','$',0
msg_csv_samples: db ',samples,','$',0
msg_csv_l1:      db ',steps_l1,','$',0
msg_csv_l2:      db ',steps_l2,','$',0
msg_csv_l3:      db ',steps_l3,','$',0
msg_csv_out:     db ',steps_out,','$',0
msg_csv_policy:  db ',policy,','$',0
msg_csv_codelet: db ',codelet,','$',0
msg_csv_tap:     db ',tap,','$',0
csv_header:      db 'epoch,acc_pct,samples,steps_l1,steps_l2,steps_l3,steps_out,policy,codelet,tap','$',0
stats_filename:  db 'STATS.CSV',0
crlf_buf:        db 13,10

; Paths and constants
path_default_img:     db 'TEST.IDX',0
model_filename:       db 'CONTROL.PTS',0
best_model_filename:  db 'BEST.PTS',0
cmd_train: db 'TRAIN'
cmd_infer: db 'INFER'
str_seed_opt: db '/SEED '
str_noise_opt: db '/NOISE '
str_csv_opt:  db '/CSV '
str_on: db 'ON'
str_off: db 'OFF'

spinner_chars: db '\|/-', 0
spinner_state: db 0

section .bss
mode_flag: resb 2
flag_interactive: resb 2
epochs_var: resw 2
batch_var: resw 2
seed_val: resw 2
flag_have_seed: resb 2
flag_noise: resb 2
flag_csv: resb 2
img_path: resb 128
current_epoch: resw 2
total_correct: resw 2
total_samples: resw 2
best_accuracy_pct: resw 2
canvas_data: resb 784
cursor_x: resw 2
cursor_y: resw 2
handle_stats_file: resw 2
num_buf: resb 16

; Metrics & SMC state
metrics_conf_acc:      resw 2
metrics_p2_acc_lo:     resw 2
metrics_p2_acc_hi:     resw 2
metrics_batch_cnt:     resw 2
metrics_steps_l1_prev: resw 2
metrics_steps_l2_prev: resw 2
metrics_steps_l3_prev: resw 2
metrics_steps_out_prev:resw 2
metrics_steps_delta:   resw 2
ticks_start_cx:        resw 2
ticks_start_dx:        resw 2
ticks_cur_cx:          resw 2
ticks_cur_dx:          resw 2
policy_byte:           resb 2
smc_epoch_phase:       resb 2
noise_burst_ttl:       resb 2
last_codelet_id:       resb 2

; Codelet site
patch_hook:            resb 128