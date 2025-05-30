# ICEXT

iceXt is a hybrid hardware and FPGA based IBM PC XT recreation.

## TODO

- SD Card
  - Last error handling

- Video
  - CGA CRTC
    - scrolling
    - cursor
    - selectable background colour
    - crtc registers
  - Merge CGA and EGA adapters

- Chipset
  - PS2 keyboard/mouse controller

- BIOS
  - Proper equipment detection / selection


## Port list

| port | description
| -----|-------------
|  40h | PIT
|  41h | PIT
|  42h | PIT
|  43h | PIT
|      |
|  60h | PS/2 Controller data
|  64h | PS/2 Controller command
|      |
|  B8h | SD Card tx/rx buffer
|  B9h | SD Card control
|  BAh | SD Card clicker
|      |
|  FEh | Video mode change notifier
|      |
| 3C0h |
| 3C4h |
| 3CEh |
| 3DAh |
