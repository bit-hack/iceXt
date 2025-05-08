;     _          _  ________
;    (_)_______ | |/ /_  __/
;   / / ___/ _ \|   / / /
;  / / /__/  __/   | / /
; /_/\___/\___/_/|_|/_/
;
.8086
.model TINY

extrn _sd_init:near
extrn _sd_read:near

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

    ; install int 13h handler
    mov ax, 0
    mov ds, ax
    mov ds:[04Eh], cs
    mov ax, int13
    mov ds:[04Ch], ax

    ; initialize the SD card
    call _sd_init

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

;----------------------------------------------------
; ah - func
int13:
;----------------------------------------------------
    cli

    ; cmp ah, 8
    ; je int13_08
    ; cmp ah, 2
    ; je int13_02
    ; cmp ah, 0
    ; je int13_00

    out 0FEh, ax  ; invoke callback

    sti
    iret


;------------------------------------------------------------
; Reset Disk System
;   dl    - drive
int13_00:
;------------------------------------------------------------
    mov ah, 0
    clc             ; CF = 0
    sti
    iret

;------------------------------------------------------------
; Read Sectors From Drive
; input:
;   al    - sectors to read
;   ch    - cylinder
;   cl    - sector
;   dh    - head
;   dl    - drive
;   es:bx - buffer
int13_02:
;------------------------------------------------------------

    ; todo: check drive is floppy

    push si
    push di

    push es
    push bx
    push dx
    push cx
    push ax
    call _sd_read
    pop ax
    pop cx
    pop dx
    pop bx
    pop es

    pop di
    pop si

    out 0FFh, ax  ; invoke callback

    mov ah, 0
    clc             ; CF = 0

    sti
    iret

;------------------------------------------------------------
; Read Drive Parameters
; input:
;   dl    - drive
; output:
;   dl    - number of hard disk drives
;   dh    - logical last index of heads
;   cx    - 
;   bl    - drive type
;   es:di - pointer to drive parameter table
int13_08:
;------------------------------------------------------------

    ; todo: set all of the return values correctly

    cmp dl, 0h
    je _is_floppy
    mov ah, 0aah
    stc             ; CF = 1
    jmp _finish
    
    sti
    iret            ; error

_is_floppy:
    mov ah, 0
    clc             ; CF = 0
    jmp _finish

_finish:
    sti
    iret            ; success

END main
