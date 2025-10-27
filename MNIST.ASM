; Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

; MNIST.ASM - MNIST Data Handler
; "Teaching machines to recognize human handwriting (on ancient tech)"

%include "macros.inc"

; Public exports
global open_mnist_train, load_next_item, close_mnist_train, rewind_mnist_train
global open_mnist_test, close_mnist_test, rewind_mnist_test

; External dependencies
extern input_buffer, current_label

section .data
; File names
train_images:   db 'TRAIN.IDX', 0
train_labels:   db 'TRAINL.IDX', 0
test_images:    db 'TEST.IDX', 0
test_labels:    db 'TESTL.IDX', 0

; Error messages
msg_open_err:   db 'Error: Cannot open MNIST file', 13, 10, '$'
msg_read_err:   db 'Error: Cannot read MNIST data', 13, 10, '$'

; IDX file headers (big-endian)
idx_magic_images: dw 0x0308  ; Magic for image files (reversed)
idx_magic_labels: dw 0x0108  ; Magic for label files (reversed)

section .bss
handle_train_img:  resw 2
handle_train_lbl:  resw 2
handle_test_img:   resw 2
handle_test_lbl:   resw 2
header_buffer:     resb 16
pixel_buffer:      resb 784
current_offset:    resd 2

section .text

; ------------------------------
; Training Data Functions
; ------------------------------
open_mnist_train:
        push ax
        push dx
        
        ; Open training images
        mov dx, train_images
        mov ah, 3Dh     ; Open file
        mov al, 0       ; Read-only
        int 21h
        jc .error
        mov [handle_train_img], ax
        
        ; Open training labels
        mov dx, train_labels
        mov ah, 3Dh
        mov al, 0
        int 21h
        jc .error_close_img
        mov [handle_train_lbl], ax
        
        ; Skip headers (16 bytes for images, 8 for labels)
        mov bx, [handle_train_img]
        call skip_image_header
        
        mov bx, [handle_train_lbl]
        call skip_label_header
        
        clc
        jmp .done
        
.error_close_img:
        mov bx, [handle_train_img]
        mov ah, 3Eh     ; Close file
        int 21h
.error:
        mov dx, msg_open_err
        call print_dos_str
        stc
.done:
        pop dx
        pop ax
        ret

; ------------------------------
load_next_item:
        ; Load next image and label
        ; OUT: CF=1 on error or EOF
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        
        ; Read label (1 byte)
        mov bx, [handle_train_lbl]
        test bx, bx
        jz .test_mode
        jmp .read_label
        
.test_mode:
        ; Use test handles
        mov bx, [handle_test_lbl]
        test bx, bx
        jz .error
        
.read_label:
        mov ah, 3Fh     ; Read file
        mov cx, 1       ; 1 byte
        mov dx, current_label
        int 21h
        jc .error
        test ax, ax     ; Check bytes read
        jz .eof
        
        ; Convert label to word
        mov al, [current_label]
        xor ah, ah
        mov [current_label], ax
        
        ; Read image (784 bytes)
        mov bx, [handle_train_img]
        test bx, bx
        jz .test_img
        jmp .read_image
        
.test_img:
        mov bx, [handle_test_img]
        
.read_image:
        mov ah, 3Fh
        mov cx, 784
        mov dx, pixel_buffer
        int 21h
        jc .error
        cmp ax, 784
        jne .eof
        
        ; Convert pixels to Q8.8 format
        mov si, pixel_buffer
        mov di, input_buffer
        mov cx, 784
.convert_loop:
        lodsb           ; Load byte pixel
        ; Convert 0-255 to Q8.8 (0.0-1.0)
        xor ah, ah
        ; Just use as-is for simplicity (pixel/256)
        stosw
        loop .convert_loop
        
        clc
        jmp .done
        
.eof:
.error:
        stc
.done:
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret

; ------------------------------
close_mnist_train:
        push ax
        push bx
        
        mov bx, [handle_train_img]
        test bx, bx
        jz .no_img
        mov ah, 3Eh
        int 21h
        mov word [handle_train_img], 0
.no_img:
        
        mov bx, [handle_train_lbl]
        test bx, bx
        jz .no_lbl
        mov ah, 3Eh
        int 21h
        mov word [handle_train_lbl], 0
.no_lbl:
        
        pop bx
        pop ax
        ret

; ------------------------------
rewind_mnist_train:
        push ax
        push bx
        push cx
        push dx
        
        ; Rewind image file
        mov bx, [handle_train_img]
        mov ah, 42h     ; Seek
        mov al, 0       ; From beginning
        xor cx, cx
        mov dx, 16      ; Skip header
        int 21h
        
        ; Rewind label file
        mov bx, [handle_train_lbl]
        mov ah, 42h
        mov al, 0
        xor cx, cx
        mov dx, 8       ; Skip header
        int 21h
        
        pop dx
        pop cx
        pop bx
        pop ax
        ret

; ------------------------------
; Test Data Functions
; ------------------------------
open_mnist_test:
        push ax
        push dx
        
        ; Open test images
        mov dx, test_images
        mov ah, 3Dh
        mov al, 0
        int 21h
        jc .error
        mov [handle_test_img], ax
        
        ; Open test labels
        mov dx, test_labels
        mov ah, 3Dh
        mov al, 0
        int 21h
        jc .error_close_img
        mov [handle_test_lbl], ax
        
        ; Skip image header (16 bytes)
        mov bx, [handle_test_img]
        call skip_image_header
        ; Skip label header (8 bytes)
        mov bx, [handle_test_lbl]
        call skip_label_header
        
        clc
        jmp .done

.error_close_img:
        ; Close image if label fails
        mov bx, [handle_test_img]
        mov ah, 3Eh
        int 21h
.error:
        stc
.done:
        pop dx
        pop ax
        ret

; ------------------------------
close_mnist_test:
        push ax
        push bx
        
        ; Close test image file
        mov bx, [handle_test_img]
        test bx, bx
        jz .skip_img
        mov ah, 3Eh
        int 21h
        mov word [handle_test_img], 0
.skip_img:
        ; Close test label file
        mov bx, [handle_test_lbl]
        test bx, bx
        jz .done
        mov ah, 3Eh
        int 21h
        mov word [handle_test_lbl], 0
.done:
        pop bx
        pop ax
        ret

; ------------------------------
rewind_mnist_test:
        push ax
        push bx
        push cx
        push dx
        
        mov bx, [handle_test_img]
        test bx, bx
        jz .skip_rewind
        mov ah, 42h
        mov al, 0
        xor cx, cx
        mov dx, 16
        int 21h
.skip_rewind:
        ; Rewind test label file
        mov bx, [handle_test_lbl]
        test bx, bx
        jz .done
        mov ah, 42h
        mov al, 0
        xor cx, cx
        mov dx, 8
        int 21h
.done:
        pop dx
        pop cx
        pop bx
        pop ax
        ret

; ------------------------------
; Helper Functions
; ------------------------------
skip_image_header:
        ; Skip 16-byte header for image file
        ; IN: BX = file handle
        push ax
        push cx
        push dx
        
        mov ah, 3Fh
        mov cx, 16
        mov dx, header_buffer
        int 21h
        
        pop dx
        pop cx
        pop ax
        ret

skip_label_header:
        ; Skip 8-byte header for label file
        ; IN: BX = file handle
        push ax
        push cx
        push dx
        
        mov ah, 3Fh
        mov cx, 8
        mov dx, header_buffer
        int 21h
        
        pop dx
        pop cx
        pop ax
        ret

; "The machines rose from the ashes of the nuclear fire"
