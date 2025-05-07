#include <stdio.h>
#include <stdint.h>

#include "disk.h"
#include "cpu.h"


static FILE* disk;

bool disk_load(const char* path) {
  disk = fopen(path, "rb");
  return NULL != disk;
}

void disk_int13_00(void) {
}

void disk_int13_02(void) {

  const uint32_t CYLINDERS = 80;
  const uint32_t SECTORS   = 18;
  const uint32_t HEADS     = 2;

  const uint8_t count    = cpu_get_AL();
  const uint8_t cylinder = cpu_get_CH();
  const uint8_t sector   = cpu_get_CL() - 1;
  const uint8_t head     = cpu_get_DH();
  const uint8_t drive    = cpu_get_DL();

  const uint32_t es   = cpu_get_ES();
  const uint32_t bx   = cpu_get_BX();
  const uint32_t dest = cpu_get_address(es, bx);

  const uint32_t lba = (cylinder * HEADS + head) * SECTORS + sector;

  fseek(disk, lba * 512, SEEK_SET);
  fread(&memory[dest], 1, 512 * count, disk);

  cpu_set_AL(count);
}

void disk_int13_08(void) {

  cpu_set_AX(0);
  cpu_set_DL(1);  // number of diskettes
  cpu_set_BX(0);

  cpu_set_ES(0xfe00);
  cpu_set_DI(0x0FC7);
}

void disk_int13(void) {

  const uint8_t func = cpu_get_AH();

  printf("int 13h -> AH:%02x\n", func);

  switch (func) {
  case 0x0:
    disk_int13_00();
    break;
  case 0x2:
    disk_int13_02();
    break;
  case 0x8:
    disk_int13_08();
    break;
  }

  cpu_set_AH(0);
  cpu_set_CF(0);  // success
}

void disk_read_sector(void) {

  uint32_t sp = cpu_get_address(cpu_get_SS(), cpu_get_SP());
  uint32_t bp = cpu_get_address(cpu_get_SS(), cpu_get_BP());

  uint8_t* psp = memory + sp;
  uint8_t* pbp = memory + bp;

  uint16_t lba    = *(uint16_t*)(pbp + 8);  // 0     13h  21h
  uint16_t dstoff = *(uint16_t*)(pbp + 6);  // 7c00h 500h 700h
  uint16_t dstseg = *(uint16_t*)(pbp + 4);  // 0     0    0

  __debugbreak();

  uint32_t dest = cpu_get_address(dstseg, dstoff);
  //fseek(disk, lba * 512, SEEK_SET);
  //fread(&memory[dest], 1, 512, disk);
}
