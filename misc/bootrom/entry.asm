
.8086
.model TINY

extrn _cmain:near

.code
org 0h
main:
    jmp short start
    nop

start:
    cli
    mov ax,cs               ; Setup segment registers
    mov ds,ax               ; Make DS correct
    mov es,ax               ; Make ES correct
    mov ss,ax               ; Make SS correct
    mov bp,0ff00h
    mov sp,0ff00h           ; Setup a stack
    sti

    call _cmain
    ret

END main
