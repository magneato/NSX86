; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)
;
; UI.ASM - Interactive Mode Module for NSX86
; Pure "nom nom" text-mode neural canvas with Gaussian brushes
; Modular design for separation of UI from core neural computation

CPU 8086
BITS 16

; ═══════════════════════════════════════════════════════════════════════
; Public Exports - Functions available to other modules
; ═══════════════════════════════════════════════════════════════════════
global interactive_mode
global clear_canvas
global canvas_to_input
global init_ui

; ═══════════════════════════════════════════════════════════════════════
; External Imports - Functions and data from other modules
; ═══════════════════════════════════════════════════════════════════════
extern print_dos_str
extern print_crlf
extern print_u16
extern forward_pass_4layers
extern find_best_prediction
extern input_buffer
extern exit_program

; ═══════════════════════════════════════════════════════════════════════
; Data Section - UI-specific data structures and messages
; ═══════════════════════════════════════════════════════════════════════
section .data

; Interactive mode messages
msg_interactive: db 13,10,'╔═══════════════════════════════════════════════════════╗', 13,10
                 db '║  NEURAL CANVAS - Draw a digit (0-9)                                        ║', 13,10
                 db '║  Arrows: Move  Space: Draw  X: Erase  C: Clear                             ║', 13,10
                 db '║  1-4: Brush size  Enter: Classify  ESC: Exit                               ║', 13,10
                 db '╚═══════════════════════════════════════════════════════╝', 13,10,'$'

msg_canvas_border_top: db '┌────────────────────────────────────────────────────────┐', 13,10,'$'
msg_canvas_border_bot: db '└────────────────────────────────────────────────────────┘', 13,10,'$'

msg_status_brush: db 13,10,'Brush: ','$'
msg_status_pos: db '  Position: ','$'
msg_status_help: db '  [Space=Draw X=Erase C=Clear Enter=Classify]','$'

msg_classify_result: db 13,10,13,10,'>>> Neural Spline says: ','$'
msg_conf_pfx: db ' Confidence: ','$'
msg_pct: db '%','$'
msg_press_key: db 13,10,'Press any key to continue...','$'

; Canvas data - 28x28 pixels
canvas_data: times 784 db 0

; Cursor and brush state
cursor_x: dw 14
cursor_y: dw 14
brush_size: db 2

; Temporary variables for brush calculations
temp_x: dw 0
temp_y: dw 0

; ═══════════════════════════════════════════════════════════════════════
; Code Section - Interactive UI Implementation
; ═══════════════════════════════════════════════════════════════════════
section .text

; ───────────────────────────────────────────────────────────────────────
; init_ui - Initialize UI module
; Called once at program start if interactive mode is selected
; ───────────────────────────────────────────────────────────────────────
init_ui:
  push ax
  
  ; Initialize cursor to center
  mov word [cursor_x], 14
  mov word [cursor_y], 14
  
  ; Default brush size
  mov byte [brush_size], 2
  
  ; Clear the canvas
  call clear_canvas
  
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; interactive_mode - Main entry point for interactive drawing mode
; This is the primary interface for human-neural interaction
; ───────────────────────────────────────────────────────────────────────
interactive_mode:
  mov dx, msg_interactive
  call print_dos_str
  
  ; Initialize canvas and cursor
  call clear_canvas
  mov word [cursor_x], 14
  mov word [cursor_y], 14
  mov byte [brush_size], 2
  
.draw_loop:
  call display_text_canvas
  call display_status_line
  
  ; Get keyboard input
  mov ah, 00h
  int 16h
  
  ; Parse commands
  cmp al, 13              ; ENTER - classify
  je .classify
  cmp al, 27              ; ESC - exit
  je .done
  cmp al, 'c'             ; Clear canvas
  je .clear
  cmp al, 'C'
  je .clear
  
  ; Brush size controls
  cmp al, '1'
  je .brush_small
  cmp al, '2'
  je .brush_medium
  cmp al, '3'
  je .brush_large
  cmp al, '4'
  je .brush_xlarge
  
  ; Drawing
  cmp al, ' '             ; SPACE - draw
  je .draw_pixel
  cmp al, 'x'             ; Erase
  je .erase_pixel
  cmp al, 'X'
  je .erase_pixel
  
  ; Arrow keys (scan codes in AH)
  cmp ah, 72              ; Up
  je .move_up
  cmp ah, 80              ; Down
  je .move_down
  cmp ah, 75              ; Left
  je .move_left
  cmp ah, 77              ; Right
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
  
.brush_small:
  mov byte [brush_size], 1
  jmp .draw_loop
  
.brush_medium:
  mov byte [brush_size], 2
  jmp .draw_loop
  
.brush_large:
  mov byte [brush_size], 3
  jmp .draw_loop
  
.brush_xlarge:
  mov byte [brush_size], 4
  jmp .draw_loop
  
.draw_pixel:
  call apply_gaussian_brush
  jmp .draw_loop
  
.erase_pixel:
  call erase_brush
  jmp .draw_loop
  
.clear:
  call clear_canvas
  jmp .draw_loop
  
.classify:
  call canvas_to_input
  call forward_pass_4layers
  call find_best_prediction
  
  ; Display result with proper register handling
  push ax                  ; Save digit
  push bx                  ; Save confidence
  
  mov dx, msg_classify_result
  call print_dos_str
  
  pop bx                   ; Restore confidence
  pop ax                   ; Restore digit
  push bx                  ; Save confidence again
  
  ; Print digit
  call print_u16
  
  mov dx, msg_conf_pfx
  call print_dos_str
  
  pop ax                   ; Get confidence into AX
  call print_u16
  
  mov dx, msg_pct
  call print_dos_str
  
  ; Wait for key
  mov dx, msg_press_key
  call print_dos_str
  mov ah, 00h
  int 16h
  
  jmp .draw_loop
  
.done:
  jmp exit_program

; ───────────────────────────────────────────────────────────────────────
; display_text_canvas - Render the 28x28 canvas as ASCII art
; Uses different characters to represent intensity levels
; # = full, + = heavy, - = medium, . = light, space = empty
; ───────────────────────────────────────────────────────────────────────
display_text_canvas:
  push ax
  push bx
  push cx
  push dx
  push si
  
  ; Clear screen
  mov ax, 0003h           ; Text mode 80x25
  int 10h
  
  ; Top border
  mov dx, msg_canvas_border_top
  call print_dos_str
  
  ; Display each row
  mov si, canvas_data
  xor cx, cx              ; Row counter
  
.row_loop:
  push cx
  
  ; Left border
  mov ah, 02h
  mov dl, '│'
  int 21h
  mov dl, ' '
  int 21h
  
  ; Display 28 pixels as ASCII
  mov cx, 28
.pixel_loop:
  push cx
  
  ; Get pixel value and convert to ASCII
  lodsb
  call pixel_to_ascii
  
  ; Check if cursor is here
  mov bx, si
  sub bx, canvas_data + 1  ; Current position
  push ax
  push cx
  mov ax, [cursor_y]
  mov cx, 28
  push dx
  mul cx
  pop dx
  add ax, [cursor_x]
  pop cx
  cmp bx, ax
  pop ax
  jne .not_cursor
  
  ; Highlight cursor position with brackets
  push ax
  mov dl, '['
  mov ah, 02h
  int 21h
  pop ax
  mov dl, al              ; The character
  int 21h
  mov dl, ']'
  int 21h
  jmp .next_pixel
  
.not_cursor:
  mov dl, al
  mov ah, 02h
  int 21h
  mov dl, ' '              ; Space between pixels
  int 21h
  
.next_pixel:
  pop cx
  loop .pixel_loop
  
  ; Right border and newline
  mov dl, ' '
  int 21h
  mov dl, '│'
  int 21h
  call print_crlf
  
  pop cx
  inc cx
  cmp cx, 28
  jb .row_loop
  
  ; Bottom border
  mov dx, msg_canvas_border_bot
  call print_dos_str
  
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; pixel_to_ascii - Convert pixel intensity to ASCII character
; Input: AL = pixel value (0-255)
; Output: AL = ASCII character representing intensity
; ───────────────────────────────────────────────────────────────────────
pixel_to_ascii:
  cmp al, 0
  je .empty
  cmp al, 64
  jb .light
  cmp al, 128
  jb .medium
  cmp al, 192
  jb .heavy
  
  ; Full intensity
  mov al, '#'
  ret
  
.heavy:
  mov al, '+'
  ret
  
.medium:
  mov al, '-'
  ret
  
.light:
  mov al, '.'
  ret
  
.empty:
  mov al, ' '
  ret

; ───────────────────────────────────────────────────────────────────────
; display_status_line - Show brush size, cursor position, and help
; ───────────────────────────────────────────────────────────────────────
display_status_line:
  push ax
  push dx
  
  mov dx, msg_status_brush
  call print_dos_str
  
  mov al, [brush_size]
  add al, '0'
  mov dl, al
  mov ah, 02h
  int 21h
  
  mov dx, msg_status_pos
  call print_dos_str
  
  mov ax, [cursor_x]
  call print_u16
  mov dl, ','
  mov ah, 02h
  int 21h
  mov ax, [cursor_y]
  call print_u16
  
  mov dx, msg_status_help
  call print_dos_str
  
  pop dx
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; apply_gaussian_brush - Paint with Gaussian intensity distribution
; Creates natural-looking strokes with smooth falloff
; Intensity = 255 * e^(-(distance²/σ²))
; ───────────────────────────────────────────────────────────────────────
apply_gaussian_brush:
  push ax
  push bx
  push cx
  push dx
  push si
  
  ; Get brush parameters
  mov cl, [brush_size]
  xor ch, ch
  
  ; Calculate brush bounds
  mov ax, [cursor_y]
  sub ax, cx
  jns .y_ok
  xor ax, ax
.y_ok:
  mov [temp_y], ax
  
.brush_row:
  mov ax, [cursor_x]
  sub ax, cx
  jns .x_ok
  xor ax, ax
.x_ok:
  mov [temp_x], ax
  
.brush_col:
  ; Calculate distance from center
  mov ax, [temp_x]
  sub ax, [cursor_x]
  push ax
  imul ax                  ; dx²
  mov bx, ax
  pop ax
  
  mov ax, [temp_y]
  sub ax, [cursor_y]
  push ax
  imul ax                  ; dy²
  add ax, bx               ; distance²
  pop ax
  
  ; Check if within brush radius
  mov bx, cx               ; Brush size
  push ax
  mov ax, bx
  imul ax
  mov bx, ax
  pop ax
  cmp ax, bx
  ja .skip_pixel
  
  ; Calculate Gaussian intensity
  ; Simplified: intensity = 255 - (distance² * scale_factor)
  push cx
  mov cl, 3
  shr ax, cl               ; Divide by 8 for scaling
  pop cx
  mov bx, 255
  sub bx, ax
  cmp bx, 0
  jg .intensity_ok
  xor bx, bx
.intensity_ok:
  
  ; Apply to canvas
  mov ax, [temp_y]
  cmp ax, 27
  ja .skip_pixel
  push cx
  mov cx, 28
  mul cx
  pop cx
  add ax, [temp_x]
  cmp ax, 783
  ja .skip_pixel
  
  mov si, canvas_data
  add si, ax
  
  ; Additive blending
  mov al, [si]
  add ax, bx
  cmp ax, 255
  jbe .no_overflow
  mov ax, 255
.no_overflow:
  mov [si], al
  
.skip_pixel:
  inc word [temp_x]
  mov ax, [cursor_x]
  add ax, cx
  cmp [temp_x], ax
  jbe .brush_col
  
  inc word [temp_y]
  mov ax, [cursor_y]
  add ax, cx
  cmp [temp_y], ax
  jbe .brush_row
  
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; erase_brush - Erase with current brush size
; ───────────────────────────────────────────────────────────────────────
erase_brush:
  push ax
  push bx
  push cx
  push dx
  push si
  
  mov cl, [brush_size]
  xor ch, ch
  
  ; Calculate erase area
  mov ax, [cursor_y]
  sub ax, cx
  jns .y_start_ok
  xor ax, ax
.y_start_ok:
  mov dx, ax               ; Start Y
  
  mov ax, [cursor_y]
  add ax, cx
  cmp ax, 27
  jbe .y_end_ok
  mov ax, 27
.y_end_ok:
  mov bx, ax               ; End Y
  
.erase_row:
  push dx
  
  mov ax, [cursor_x]
  sub ax, cx
  jns .x_start_ok
  xor ax, ax
.x_start_ok:
  mov si, ax               ; Start X
  
  mov ax, [cursor_x]
  add ax, cx
  cmp ax, 27
  jbe .x_end_ok
  mov ax, 27
.x_end_ok:
  mov di, ax               ; End X
  
.erase_col:
  ; Calculate position
  mov ax, dx
  push cx
  mov cx, 28
  mul cx
  pop cx
  add ax, si
  
  ; Clear pixel
  push si
  mov si, canvas_data
  add si, ax
  mov byte [si], 0
  pop si
  
  inc si
  cmp si, di
  jbe .erase_col
  
  pop dx
  inc dx
  cmp dx, bx
  jbe .erase_row
  
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; clear_canvas - Clear entire 28x28 canvas
; ───────────────────────────────────────────────────────────────────────
clear_canvas:
  push ax
  push cx
  push di
  
  mov di, canvas_data
  xor ax, ax
  mov cx, 784
  rep stosb
  
  ; Reset cursor to center
  mov word [cursor_x], 14
  mov word [cursor_y], 14
  
  pop di
  pop cx
  pop ax
  ret

; ───────────────────────────────────────────────────────────────────────
; canvas_to_input - Convert canvas to neural network input format
; Transforms 28x28 byte array to 784 Q8.8 fixed-point values
; ───────────────────────────────────────────────────────────────────────
canvas_to_input:
  push si
  push di
  push cx
  push ax
  
  mov si, canvas_data
  mov di, input_buffer
  mov cx, 784
  
.convert_loop:
  lodsb                    ; Get pixel (0-255)
  
  ; Convert to Q8.8 fixed point
  ; Neural network expects normalized values
  ; Simple approach: value << 8 (approximately 0-1 range)
  mov ah, al               ; Value in high byte
  xor al, al               ; Clear low byte
  stosw                    ; Store Q8.8 value
  
  loop .convert_loop
  
  pop ax
  pop cx
  pop di
  pop si
  ret

; ═══════════════════════════════════════════════════════════════════════
; End of UI.ASM
; ═══════════════════════════════════════════════════════════════════════
