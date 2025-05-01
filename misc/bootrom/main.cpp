typedef unsigned char   uint8_t;
typedef unsigned short  uint16_t;
typedef unsigned long   uint32_t;
typedef char            bool;

#define true            0x1
#define false           0x0

void port_out(uint8_t data) {
    uint8_t d = data;
    __asm
    {
        mov al, d
        out 0x2a, al
    }
}

extern "C" void cmain()
{
  uint8_t __far * ram    = (uint8_t __far *)0x10000000;  // 1000:0000
  uint8_t __far * screen = (uint8_t __far *)0xb0000000;  // B000:0000

  int i = 0;
  for (;; ++i) {

    ram[0] = 'R';
    ram[1] = 'A';
    ram[2] = 'M';
    ram[3] = 'O';
    ram[4] = 'K';

    {
      uint16_t x = 0xffff;
      while (--x);
    }

    screen[0] = ram[0];
    screen[1] = ram[1];
    screen[2] = ram[2];
    screen[3] = ram[3];
    screen[4] = ram[4];
    screen[5] = '0' + i % 10;

    {
      uint16_t x = 0xffff;
      while (--x);
    }
  }
}
