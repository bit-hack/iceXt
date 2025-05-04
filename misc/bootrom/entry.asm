;     _          _  ________
;    (_)_______ | |/ /_  __/
;   / / ___/ _ \|   / / /
;  / / /__/  __/   | / /
; /_/\___/\___/_/|_|/_/
;
.8086
.model TINY

extrn _cmain:near

.code
org 0h

main:
    DB 055h, 0AAh           ; signature
    DB 004h                 ; 512 * 4

    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push ds
    push es

    push ds

    out 0FEh, ax  ; invoke callback

    ; install int 13h handler
    mov ax, 0
    mov ds, ax
    mov ds:[04Eh], cs
    mov ax, int13_handler
    mov ds:[04Ch], ax

    pop ds

    pop es
    pop ds
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    retf


int13_handler:
    cli

    out 0FFh, ax  ; invoke callback

    sti
    iret

END main
