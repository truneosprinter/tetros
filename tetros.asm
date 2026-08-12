; tetros.asm
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov ah, 0x02
    mov al, 4
    mov ch, 0
    mov cl, 2
    mov dh, 0

    mov bx, stage_2
    int 0x13

    jmp stage_2

times 510 - ($-$$) db 0
dw 0xAA55

stage_2:
    mov al, 0x13
    int 0x10
    push 0xA000
    pop es
    mov di, 109
    mov si, 210
    mov cx, 200
.draw_borders:
    mov byte [es:di], 15
    mov byte [es:si], 15
    add di, 320
    add si, 320
    loop .draw_borders
    call draw_score

main:
    mov cx, [block_x]
    mov dx, [block_y]
    mov al, [current_colour]
    call draw_shape
.game_loop:
    mov ah, 0x01
    int 0x16
    jnz .read_key
    mov ax, [0x046C]
    cmp ax, [last_tick]
    je .game_loop
    mov [last_tick], ax
    inc byte [gravity_delay]
    cmp byte [gravity_delay], 8
    jl .game_loop
    mov byte [gravity_delay], 0
    mov ah, 0x50
    jmp .do_move
.read_key:
    mov ah, 0x00
    int 0x16
.do_move:
    push ax
    mov cx, [block_x]
    mov dx, [block_y]
    mov al, 0
    call draw_shape
    pop ax
    cmp ah, 0x48
    je .rotate
    cmp ah, 0x4B
    je .move_left
    cmp ah, 0x4D
    je .move_right
    cmp ah, 0x50
    jne main
.move_down:
    add dx, 10
    jmp .test_move
.move_left:
    sub cx, 10
    jmp .test_move
.move_right:
    add cx, 10
.test_move:
    call check_collision
    jne .hit_something
    mov [block_x], cx
    mov [block_y], dx
    jmp main
.hit_something:
    cmp ah, 0x50
    jne main
.lock_block:
    mov cx, [block_x]
    mov dx, [block_y]
    mov al, [current_colour]
    call draw_shape
    call check_lines
    call draw_score
    mov word [block_x], 150
    mov word [block_y], 0
    mov ax, [0x046C]
    xor dx, dx
    mov cx, 7
    div cx
    mov al, dl
    add al, 9
    mov [current_colour], al
    shl dx, 2
    mov [current_shape_idx], dx
    mov bx, dx
    shl bx, 1
    add bx, shapes
    mov ax, [bx]
    mov [current_shape], ax
    mov cx, [block_x]
    mov dx, [block_y]
    call check_collision
    jne game_over_reset
    jmp main
.rotate:
    mov ax, [current_shape_idx]
    mov dx, ax
    inc dx
    and dx, 3
    and ax, 0xFFFC
    add ax, dx
    mov bx, ax
    shl bx, 1
    add bx, shapes
    mov bx, [bx]
    push word [current_shape]
    mov [current_shape], bx
    call check_collision
    jne .rotate_fail
    pop bx
    mov [current_shape_idx], ax
    jmp main
.rotate_fail:
    pop word [current_shape]
    jmp main

check_collision:
    pusha
    mov bx, [current_shape]
    mov si, dx
    mov bp, cx
    mov cx, 4
    xor dx, dx
.row_loop:
    push cx
    mov cx, 4
    mov di, bp
.col_loop:
    shl bx, 1
    jnc .skip_check
    cmp di, 110
    jl .hit
    cmp di, 200
    ja .hit
    cmp si, 190
    jg .hit
    push di
    mov ax, si
    imul ax, 320
    add di, ax
    cmp byte [es:di], 0
    pop di
    je .skip_check
.hit:
    inc dx
.skip_check:
    add di, 10
    loop .col_loop
    add si, 10
    pop cx
    loop .row_loop
    cmp dx, 0
    popa
    ret

draw_shape:
    pusha
    mov bx, [current_shape]
    mov si, dx
    mov bp, cx
    mov cx, 4
.row_loop:
    push cx
    mov cx, 4
    mov di, bp
.col_loop:
    shl bx, 1
    jnc .skip_square
    pusha
    mov cx, di
    mov dx, si
    call draw_square
    popa
.skip_square:
    add di, 10
    loop .col_loop
    add si, 10
    pop cx
    loop .row_loop
    popa
    ret

draw_square:
    pusha
    mov di, dx
    imul di, 320
    add di, cx
    mov dx, 10
.row:
    mov cx, 10
.col:
    mov [es:di], al
    inc di
    loop .col
    add di, 320 - 10
    dec dx
    jnz .row
    popa
    ret

block_x dw 150
block_y dw 0
current_shape dw 0x4E00
current_shape_idx dw 8
current_colour db 40
last_tick dw 0
gravity_delay db 0
score dw 0

check_lines:
    pusha
    mov si, 190
.row_loop:
    cmp si, 0
    jl .done
.check_row_start:
    mov di, 110
.col_loop:
    mov ax, si
    imul ax, 320
    add ax, di
    mov bx, ax
    cmp byte [es:bx], 0
    je .next_row
    add di, 10
    cmp di, 210
    jl .col_loop
    add word [score], 10
    mov dx, si
.shift_y:
    cmp dx, 0
    je .clear_top
    mov cx, 110
.shift_x:
    mov ax, dx
    sub ax, 10
    imul ax, 320
    add ax, cx
    mov bx, ax
    mov al, [es:bx]
    call draw_square
    add cx, 10
    cmp cx, 210
    jl .shift_x
    sub dx, 10
    jmp .shift_y
.clear_top:
    mov dx, 0
    mov cx, 110
.clear_loop:
    mov al, 0
    call draw_square
    add cx, 10
    cmp cx, 210
    jl .clear_loop
    jmp .check_row_start
.next_row:
    sub si, 10
    jmp .row_loop
.done:
    popa
    ret

game_over_reset:
    mov word [score], 0
    call draw_score
    mov di, 110
    mov dx, 200
.clear_row:
    mov cx, 100
    mov bx, di
.clear_col:
    mov byte [es:bx], 0
    inc bx
    loop .clear_col
    add di, 320
    dec dx
    jnz .clear_row
    jmp main

draw_score:
    pusha
    mov ah, 0x02
    mov bh, 0
    mov dh, 2
    mov dl, 3
    int 0x10
    mov ax, [score]
    mov cx, 4
    mov bx, 10
.get_digit:
    xor dx, dx
    div bx
    push dx
    loop .get_digit
    mov cx, 4
.print_digit:
    pop ax
    add al, '0'
    mov ah, 0x0E
    mov bx, 0x000F
    int 0x10
    loop .print_digit
    popa
    ret

shapes:
    dw 0x0F00, 0x2222, 0x0F00, 0x2222
    dw 0x6600, 0x6600, 0x6600, 0x6600
    dw 0x4E00, 0x4640, 0x0E40, 0x4C40
    dw 0x44C0, 0x8E00, 0xC880, 0x0E20
    dw 0x88C0, 0x0E80, 0xC440, 0x2E00
    dw 0x06C0, 0x8C40, 0x06C0, 0x8C40
    dw 0x0C60, 0x4C80, 0x0C60, 0x4C80

times 2560 - ($-$$) db 0
