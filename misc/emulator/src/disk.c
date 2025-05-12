#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#include "disk.h"
#include "cpu.h"

#ifdef USE_SERIAL_SD
#include "serial.h"
#endif  // USE_SERIAL_SD


static FILE* disk;

static int spi_cs = 1;
static int sd_idle = 1;

static uint64_t shift_in  = ~0llu;
static uint64_t shift_out = ~0llu;

static uint32_t sector;
static uint32_t read_count = 0;
static bool reading = false;

#ifdef USE_SERIAL_SD
static serial_t* serial;
#endif  //USE_SERIAL_SD

static uint8_t _spi_cs;

static uint8_t rx_buf;

#ifdef USE_SERIAL_SD
static uint8_t xfer(uint8_t tx, uint8_t cs) {

  int ntx, nrx;

  uint8_t n0 = 0x00 | (tx >> 7) | (cs ? 0x02 : 0);
  uint8_t n1 = 0x80 | (tx & 0x7f);

  ntx = serial_send(serial, &n0, 1);
  assert(ntx == 1);

  ntx = serial_send(serial, &n1, 1);
  assert(ntx == 1);

  uint8_t rx = 0;
  nrx = serial_read(serial, &rx, 1);
  assert(nrx == 1);

  rx_buf = rx;

  return rx;
}

static void spi_send(uint8_t tx) {
  xfer(tx, _spi_cs);
}

static uint8_t spi_recv(void) {
  return rx_buf;
}
#endif  // USE_SERIAL_SD


bool disk_load(const char* path) {
  disk = fopen(path, "rb");
  if (!disk) {
    return false;
  }

#ifdef USE_SERIAL_SD
  serial = serial_open(14, 115200);
  if (!serial) {
    return false;
  }
#endif  // USE_SERIAL_SD

  return true;
}

#ifdef USE_SERIAL_SD
void disk_spi_ctrl(uint8_t tx) {
  _spi_cs = tx & 1;
}

void disk_spi_write(uint8_t tx) {
  spi_send(tx);
}

uint8_t disk_spi_read() {
  return spi_recv();
}
#else
void disk_spi_ctrl(uint8_t tx) {
  spi_cs = tx & 1;
}

void disk_spi_write(uint8_t tx) {

  if (spi_cs == 1) {
    return;
  }

  shift_in  = (shift_in  << 8) | tx;
  shift_out = (shift_out << 8);

  if (read_count) {
    uint8_t out = 0;
    fread(&out, 1, 1, disk);
    shift_out |= out;
    read_count -= 1;
  }
  else {
    shift_out |= 0xff;
  }

  const uint8_t cmd = (shift_in >> 48);
  switch (cmd) {
  case (0x40 | 0):  // CMD0
    //printf("CMD0\n");
    //            ..--..--..--..--
    sd_idle = 1;
    shift_out = 0xffff01fffffffffflu;
    shift_in = ~0llu;
    break;
  case (0x40 | 8):  // CMD8
    //printf("CMD8\n");
    //            ..--..--..--..--
    shift_out = 0xffff01000000aafflu;
    shift_in = ~0llu;
    break;
  case (0x40 | 58): // CMD58
    //printf("CMD58\n");
    //                      ..--..--..--..--
    shift_out = sd_idle ? 0xffff0100000000fflu :
                          0xffff0000000000fflu;
    shift_in = ~0llu;
    break;
  case (0x40 | 55): // CMD55
    //printf("CMD55\n");
    //                      ..--..--..--..--
    shift_out = sd_idle ? 0xffff01fffffffffflu :
                          0xffff00fffffffffflu;
    shift_in = ~0llu;
    break;
  case (0x40 | 41): // ACMD41
    //printf("ACMD41\n");
    //                      ..--..--..--..--
    shift_out = sd_idle ? 0xffff01fffffffffflu :
                          0xffff00fffffffffflu;
    shift_in = ~0llu;
    sd_idle = 0;
    break;
  case (0x40 | 17): // CMD17
    //printf("CMD17\n");
    //            ..--..--..--..--
    shift_out = 0xffff00fffffffffelu;
    sector    = shift_in >> 16;
    shift_in = ~0llu;
    fseek(disk, 512 * sector, SEEK_SET);
    read_count = 512;
    break;
  }
}

uint8_t disk_spi_read() {
  return (shift_out >> 56) & 0xff;
}
#endif

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

  // 0, 13h, 21h, 22h

  const uint32_t lba = (cylinder * HEADS + head) * SECTORS + sector;

  printf("sector: %x\n", lba);

  fseek(disk, lba * 512, SEEK_SET);
  fread(&memory[dest], 1, 512 * count, disk);

  cpu_set_AL(count);
}

void disk_int13_08(void) {

  cpu_set_AX(0);
  cpu_set_DL(1);  // number of diskettes
  cpu_set_BX(0);

  //cpu_set_ES(0xfe00);
  //cpu_set_DI(0x0FC7);
}

void disk_int13_15(void) {

}

void disk_int13(void) {

  const uint8_t func = cpu_get_AH();

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
  case 0x15:
    disk_int13_15();
    break;
  }

  cpu_set_AH(0);
  cpu_set_CF(0);  // success
}
