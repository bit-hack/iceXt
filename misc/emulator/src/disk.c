#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#include "disk.h"
#include "cpu.h"

#ifdef USE_SERIAL_SD
#include "serial.h"
#endif  // USE_SERIAL_SD


static FILE* disk;
static uint64_t disk_size = 0;

#define USE_HDD 1

#if USE_HDD
static uint32_t disk_heads     = 16;
static uint32_t disk_sectors   = 63;
static uint32_t disk_cylinders = 0;
#else
static uint32_t disk_heads     = 2;
static uint32_t disk_sectors   = 18;
static uint32_t disk_cylinders = 80;
#endif

static int spi_cs = 1;
static int sd_idle = 1;

static uint64_t shift_in  = ~0llu;
static uint64_t shift_out = ~0llu;

static uint32_t sector;
static uint32_t read_count  = 0;
static uint32_t write_count = 0;
static bool wait_for_start = false;

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

static void set_stack_cf() {
  uint32_t sp = cpu_get_address(cpu_get_SS(), cpu_get_SP());
  memory[sp+4] |= 1;
}

static void clr_stack_cf() {
  uint32_t sp = cpu_get_address(cpu_get_SS(), cpu_get_SP());
  memory[sp+4] &= 0xfe;
}

bool disk_load(const char* path) {
  disk = fopen(path, "rb+");
  if (!disk) {
    return false;
  }

  fseek(disk, 0, SEEK_END);
  disk_size = ftell(disk);
  fseek(disk, 0, SEEK_SET);

  if (!disk_cylinders) {
    disk_cylinders = disk_size / (disk_heads * disk_sectors * 512);
  }

  printf("sectors  : %u\n", disk_sectors);
  printf("heads    : %u\n", disk_heads);
  printf("cylinders: %u\n", disk_cylinders);

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

  if (write_count) {
    if (wait_for_start) {
      if ((shift_in & 0xff) == 0xfe) {
        wait_for_start = false;
      }
    }
    else {
      uint8_t out = shift_in & 0xff;
      fwrite(&out, 1, 1, disk);
      if (0 == --write_count) {
        //            ..--..--..--..--
        shift_out = 0xffAAAA05ffff00ffllu;

        // clear input so data cant be mistaken for a
        // command
        shift_in  = 0xffffffffffffffffllu;
      }
    }
  }

  if (read_count) {
    uint8_t out = 0;
    fread(&out, 1, 1, disk);
    shift_out |= out;
    read_count -= 1;
  }
  else {
    shift_out |= 0xff;
  }

  if (read_count || write_count) {
    return;
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
  case (0x40 | 14): // CMD14
    //            ..--..--..--..--
    shift_out = 0xfffffffffffffffflu;
    sector = shift_in >> 16;
    shift_in = ~0llu;
    shift_out = 0xffff00fffffffffflu;
    fseek(disk, 512 * sector, SEEK_SET);
    write_count = 512;
    wait_for_start = true;
    printf("write sector:%u\n", sector);
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

static bool disk_int13_00(void) {
  return true;
}

static bool disk_int13_02(void) {

  const uint32_t CYLINDERS = disk_cylinders;
  const uint32_t SECTORS   = disk_sectors;
  const uint32_t HEADS     = disk_heads;

  const uint8_t count    = cpu_get_AL();
  const uint8_t cylinder = cpu_get_CH();
  const uint8_t sector   = cpu_get_CL() - 1;
  const uint8_t head     = cpu_get_DH();
  const uint8_t drive    = cpu_get_DL();

  const uint32_t es   = cpu_get_ES();
  const uint32_t bx   = cpu_get_BX();
  const uint32_t dest = cpu_get_address(es, bx);

  const uint32_t lba = (cylinder * HEADS + head) * SECTORS + sector;

  printf("sector: %x dest: %x\n", lba, dest);

  fseek(disk, lba * 512, SEEK_SET);
  fread(&memory[dest], 1, 512 * count, disk);

  cpu_set_AL(count);
  clr_stack_cf();
  return true;
}

static bool disk_int13_08(void) {

  uint32_t cyl = (disk_cylinders-1);

  cpu_set_AH(0);
  cpu_set_CH(cyl);  // cylinders - 1
  cpu_set_CL((disk_sectors & 0x3f) | ((cyl >> 6) & 0x3));      // sectors
  cpu_set_DH(disk_heads-1);      // heads - 1
  cpu_set_DL(1);                 // number of drives
  cpu_set_BX(0);

  // todo: pointer to drive parameter table?

  // note: this cant be zero or causes a hang
  //cpu_set_ES(0x0000);
  //cpu_set_DI(0x0000);
  return true;
}

static bool disk_int13_15(void) {
  return true;
}

void disk_int13(void) {

  const uint8_t func  = cpu_get_AH();
  const uint8_t drive = cpu_get_DL();

//  cpu_dump_state();
//  cpu_debug = 1;

  printf("INT13h func:%02x drive:%02x\n", func, drive);

#if USE_HDD
  if (drive != 0x80) {
#else
  if (drive != 0x00) {
#endif
    cpu_set_AH(1);
    set_stack_cf();
    return;
  }

  bool ok = true;

  switch (func) {
  case 0x0:
    ok = disk_int13_00();
    break;
  case 0x2:
    ok = disk_int13_02();
    break;
  case 0x8:
    ok = disk_int13_08();
    break;
  case 0x15:
    ok = disk_int13_15();
    break;
  }

  if (ok) {
    cpu_set_AH(0);  // success
    clr_stack_cf();
  }
  else {
    cpu_set_AH(1);  // failure
    set_stack_cf();
  }
}
