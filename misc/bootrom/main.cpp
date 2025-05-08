typedef unsigned char   uint8_t;
typedef unsigned short  uint16_t;
typedef unsigned long   uint32_t;
typedef char            bool;

#define true            0x1
#define false           0x0

#define FD_HEADS     2
#define FD_SECTORS   18
#define FD_CYLINDERS 80


static void read_sector(uint16_t lba, uint8_t __far *dest) {
    __asm {
        out 0dfh, ax
    };
}

extern "C" void __cdecl sd_init()
{
}

extern "C" uint8_t __cdecl sd_read(
    uint16_t ax,
    uint16_t cx,
    uint16_t dx,
    uint8_t __far * dest
    ) {

  uint8_t to_read = ax & 0xff;
  const uint8_t cyl  = (cx >> 8);
  const uint8_t sec  = (cx & 0xff) - 1;
  const uint8_t head = dx >> 8;

  uint16_t lba = (cyl * FD_HEADS + head) * FD_SECTORS + sec;

  //while (to_read--) {
  //
  //  //read_sector(lba, dest);
  //
  //  dest += 512;
  //  ++lba;
  //}

  return 0;
}
