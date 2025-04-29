[BITS 16]
CPU 8086
ORG 0X000

xor ax, ax

start:
    nop             ; why is this nop needed????
    inc ax
    out 42, ax
    jmp start

TIMES 4096 - ($ - $$) db 0x90
