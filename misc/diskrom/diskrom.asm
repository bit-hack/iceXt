;     _          _  ________
;    (_)_______ | |/ /_  __/
;   / / ___/ _ \|   / / /
;  / / /__/  __/   | / /
; /_/\___/\___/_/|_|/_/
;
cpu 8086
org 0
[BITS 16]


%define PORT_DEBUG    0xb0
%define PORT_SPI_DATA 0xb8
%define PORT_SPI_CTRL 0xb9
%define PORT_CLICK    0xba

%define SD_DUMMY_CLOCKS 10
%define SD_SEND_DELAY   20
%define SD_RESP_WAIT    16

%define ERR_SUCCESS     0x00
%define ERR_NOT_READY   0xaa
%define ERR_INVALID_CMD 0x01

%macro SD_SEND 1
  push ax
  mov al, %1
  call sd_send
  pop ax
%endmacro

%macro SD_SEND_CMD 6
  SD_SEND (0x40|%1)
  SD_SEND %2
  SD_SEND %3
  SD_SEND %4
  SD_SEND %5
  SD_SEND (0x01|%6)
%endmacro

%macro SD_DUMMY_BYTE 0
  push ax
  mov al, 0xff
  call sd_send
  pop ax
%endmacro

%macro SD_RECV 0
  call sd_recv
%endmacro

%macro SD_CS 1
  push ax
  mov al, %1
  call sd_set_cs
  pop ax
%endmacro

%macro DEBUG 1
  push ax
  mov ax, %1
  out PORT_DEBUG, al
  pop ax
%endmacro

;------------------------------------------------------------------------------
signature:
  db 0x55, 0xAA
  db 0x4

;------------------------------------------------------------------------------
rom_entry:
  push ax
  push bx
  push cx
  push dx
  push di
  push si
  push ds
  call sd_init
  test al, al
  jz .rom_entry_fail
  call install_int13
.rom_entry_fail:
  pop ds
  pop si
  pop di
  pop dx
  pop cx
  pop bx
  pop ax
  retf

;------------------------------------------------------------------------------
install_int13:
  mov ax, 0
  mov ds, ax
  mov ds:[0x4e], cs
  mov ax, int13
  mov ds:[0x4c], ax
  ret

;------------------------------------------------------------------------------
sd_send:
  out PORT_SPI_DATA, al
  push cx
  mov cx, SD_SEND_DELAY
.delay:
  nop
  loop .delay
  pop cx
  ret

;------------------------------------------------------------------------------
sd_recv:
  mov al, 0xff
  call sd_send
  in al, PORT_SPI_DATA
  ret

;------------------------------------------------------------------------------
sd_set_cs:
  out PORT_SPI_CTRL, al
  ret

;------------------------------------------------------------------------------
sd_init:

  ;
  ; deassert SD card
  ;
  SD_CS 1

  ;
  ; send dummy clocks
  ;
  mov cx, SD_DUMMY_CLOCKS
.dummy_clocks:
  SD_DUMMY_BYTE
  loop .dummy_clocks

  ;
  ; assert SD card
  ;
  SD_CS 0

  ;
  ; send CMD0 (go idle)
  ;
.step_1:
  SD_SEND_CMD 0, 0, 0, 0, 0, 0x95

  mov cx, SD_RESP_WAIT
.step_1_response:
  SD_RECV
  cmp al, 0x01
  je .step_1_done
  loop .step_1_response
  jmp .sd_init_fail
.step_1_done:

  SD_DUMMY_BYTE
  SD_DUMMY_BYTE

  ;
  ; send CMD8
  ;
.step_2:
  SD_SEND_CMD 8, 0, 0, 1, 0xaa, 0x86

  mov cx, SD_RESP_WAIT
.step_2_response:
  SD_RECV
  cmp al, 0x01
  je .step_2_done
  loop .step_2_response
  jmp .sd_init_fail
.step_2_done:
  SD_RECV
  SD_RECV
  SD_RECV
  SD_RECV
  cmp al, 0xaa
  jne .sd_init_fail

  ;
  ; send CMD58
  ;
.step_3:
  SD_SEND_CMD 58, 0, 0, 0, 0, 0xcc

  mov cx, SD_RESP_WAIT
.step_3_response:
  SD_RECV
  cmp al, 0x01
  je .step_3_done
  loop .step_3_response
  jmp .sd_init_fail
.step_3_done:
  SD_RECV
  SD_RECV
  SD_RECV
  SD_RECV

  ;
  ; send CMD55
  ;
  mov cx, 0xffff
.step_4:
  SD_SEND_CMD 55, 0, 0, 0, 0, 0xcc
  mov dx, cx
  mov cx, SD_RESP_WAIT
.step_4_response:
  SD_RECV
  test al, 0xfe
  jz .step_4_done
  loop .step_4_response
  jmp .sd_init_fail
.step_4_done:

  ;
  ; send ACMD41
  ;
.step_5:
  SD_SEND_CMD 41, 0x40, 0, 0, 0, 0xcc
  mov cx, SD_RESP_WAIT
.step_5_response:
  SD_RECV
  test al, 0xfe
  jz .step_5_done
  loop .step_5_response
  jmp .sd_init_fail 
.step_5_done:

  ; if R1 response is not IDLE, issue ACMD41 again
  test al, al
  jz .step_6  
  mov cx, dx
  loop .step_4

  ;
  ; send CMD58
  ;
.step_6:
  SD_SEND_CMD 58, 0, 0, 0, 0, 0xcc

  mov cx, SD_RESP_WAIT
.step_6_response:
  SD_RECV
  test al, al
  jz .step_6_done
  loop .step_6_response
  jmp .sd_init_fail
.step_6_done:
  SD_RECV   ; if &0xc0 then is SDHC
  SD_RECV
  SD_RECV
  SD_RECV

.sd_init_success:
  mov al, 1
  ret

.sd_init_fail:
  mov al, 0
  ret

;------------------------------------------------------------------------------
; ax    = sector
; es:bx = dest
sd_read_sector:

  ;
  ; click generator
  ;
  out PORT_CLICK, al

  ;
  ; send CMD17
  ;
  SD_SEND (0x40|17)
  SD_SEND 0
  SD_SEND 0
  SD_SEND ah
  SD_SEND al
  SD_SEND (0x01|0xcc)

  push cx
  mov cx, 8
.cmd_17_response:
  SD_RECV
  test al, al
  jz .cmd_17_done
  loop .cmd_17_response
  jmp .fail
.cmd_17_done:

  ; wait for start of block byte
  mov cx, 0xff
.wait_start:
  SD_RECV
  cmp al, 0xfe
  je .recv_start
  loop .wait_start
  jmp .fail
.recv_start:

  ; read a 512byte block
  mov cx, 512
.recv_sector:
  SD_RECV
  mov es:[bx], al
  inc bx
  loop .recv_sector

.success:
  pop cx
  mov al, 1
  ret

.fail:
  pop cx
  mov al, 0
  ret

;------------------------------------------------------------------------------
;  const uint32_t lba = (cylinder * HEADS + head) * SECTORS + sector;
;   ch    - cylinder  (80)
;   cl    - sector    (18)
;   dh    - head      (2)
chs_to_lba:
  push bx
  push dx
  push cx
  xor ax, ax
  mov al, ch
  add ax, ax    ; acum = cylinder * 2
  xor ch, ch    ; ch is no longer needed
  mov dl, dh
  xor dh, dh    ; dx  = head
  add ax, dx    ; accum += head
  shl ax, 1
  mov bx, ax    ; bx = accum * 2
  shl ax, 1
  shl ax, 1
  shl ax, 1
  add ax, bx    ; accum *= 18
  dec cx
  add ax, cx    ; accum += (sector - 1)
  pop cx
  pop dx
  pop bx
  ret

;------------------------------------------------------------------------------
int13:
  cli

  push dx
  push cx
  push bx
  push ax

  ; dispatch to specific handler
  cmp ah, 0x02
  je int13_02
  cmp ah, 0x00
  je int13_00
  cmp ah, 0x08
  je int13_08
  cmp ah, 0x15
  je int13_15

  mov ah, ERR_SUCCESS
  clc             ; CF = 0
  jmp int13_exit

;------------------------------------------------------------------------------
int13_00:
  mov ah, ERR_SUCCESS
  clc             ; CF = 0
  jmp int13_exit

;------------------------------------------------------------------------------
; Read Sectors From Drive
;   al    - sectors to read
;   ch    - cylinder
;   cl    - sector
;   dh    - head
;   dl    - drive
;   es:bx - buffer
int13_02:
  push ax
  call chs_to_lba
  pop cx
  xor ch, ch
  push cx

.int13_02_read_sector:
  push ax                 ; preserve sector number
  call sd_read_sector
  test al, al
  jz .int13_02_fail
  pop ax                  ; restore sector number
  inc ax                  ; advance to the next sector
  loop .int13_02_read_sector

  pop ax                  ; al = sectors read
  mov ah, ERR_SUCCESS
  clc                     ; CF = 0
  jmp int13_exit

.int13_02_fail:
  pop cx                  ; cx was left on the stack so pop it
  mov ah, ERR_NOT_READY
  stc
  jmp int13_exit

;------------------------------------------------------------------------------
disk_base_table:
	db	11001111b
	db	2
	db	25h
	db	2           ; 2 - 512 bytes
	db	17          ; sectors per track (last sector number)
	db	2Ah
	db	0FFh
	db	50h
	db	0F6h
	db	19h
	db	4

;------------------------------------------------------------------------------
int13_08:
  mov ax, cs
  mov es, ax
  mov di, disk_base_table
  pop ax
  pop bx
  pop cx
  pop dx
  mov bl, 4       ; 1.44Mb disk
  mov ch, 80      ; cylinders
  mov cl, 18      ; sectors
  mov dh, 1       ; sides (zero based)
  mov dl, 1       ; number of drives attached
  mov ah, ERR_SUCCESS
  clc             ; CF = 0
  sti
  iret

;------------------------------------------------------------------------------
int13_15:
  pop ax
  pop bx
  pop cx
  pop dx
  mov ah, 1       ; diskette no change detection present
  clc             ; CF = 0
  sti
  iret

;------------------------------------------------------------------------------
int13_exit:

  ; fix return code as some functions need to return values
  ;
  ; 02 need to return in AL
  ; AH has status code
  ; can we move the value to the stack before it gets popd?

  mov bh, ah
  pop ax
  mov ah, bh
  pop bx
  pop cx
  pop dx
  sti
  iret
