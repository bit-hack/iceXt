[BITS 16]
CPU 8086
ORG 0XF000

xor ax, ax
start:
    inc ax
    out 42, ax
    jmp start

TIMES 4080 - ($ - $$) db 0x90

    jmp 0:0

TIMES 4096 - ($ - $$) db 0x90
