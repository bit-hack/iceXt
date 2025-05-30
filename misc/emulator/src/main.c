#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>

#define _SDL_main_h
#include <SDL.h>

#include "cpu.h"
#include "disk.h"
#include "display.h"
#include "keyboard.h"
#include "serial.h"


uint8_t memory[1024 * 1024];


void int_notify(uint8_t num) {

  if (num == 0x13) {

    uint8_t ah = cpu_get_AH();
    switch (ah) {
    case 2:
      break;
    default:
      break;
      //printf("13h\n", ah);
      //cpu_dump_state();
    }
  }

  if (num == 0x10) {
    if (cpu_get_AH() == 0) {
      // video change mode
      uint8_t mode = cpu_get_AL();
      display_set_mode(mode);
    }
  }
}

uint8_t port_read(uint32_t port) {
  port &= 0xfff;

  if (port == 0xb8) {
    return disk_spi_read();
  }

  if (port == 0xb9) {
    return 0;  // SPI not busy
  }

  uint8_t out = 0;

  if (serial_io_read(port, &out)) {
    return out;
  }
  if (keyboard_io_read(port, &out)) {
    return out;
  }
  if (display_cga_io_read(port, &out)) {
    return out;
  }
  if (display_ega_io_read(port, &out)) {
    return out;
  }
  return 0;
}

void port_write(uint32_t port, uint8_t value) {
  port &= 0xfff;

  if (port == 0xb0) {
    printf("----------------------------------------------------\n");
    cpu_debug = 1;
  }
  if (port == 0xb2) {
    cpu_debug = 0;
  }
  if (port == 0xb8) {
    disk_spi_write(value);
  }
  if (port == 0xb9) {
    disk_spi_ctrl(value);
  }
  if (port == 0xbc) {
    // legacy
    //disk_int13();
  }
  if (port == 0xbe) {
    //cpu_dump_state();
    //dump_sector();
  }

  serial_io_write     (port, value);
  keyboard_io_write   (port, value);
  display_cga_io_write(port, value);
  display_ega_io_write(port, value);
}

uint8_t mem_read(uint32_t addr) {
  addr &= 0xfffff;

  if (addr >= 0xA0000 && addr < 0xA4000) {
    return display_ega_mem_read(addr & 0x3fff);
  }
  if ((addr & 0xF8000) == 0xB8000) {
    return display_cga_mem_read(addr & 0x3fff);
  }

  return memory[addr];
}

void mem_write(uint32_t addr, uint8_t data) {
  addr &= 0xfffff;
  memory[addr] = data;

  if (addr >= 0xA0000 && addr < 0xA4000) {
    display_ega_mem_write(addr & 0x3fff, data);
  }
  if ((addr & 0xF8000) == 0xB8000) {
    display_cga_mem_write(addr & 0x3fff, data);
  }
}

static bool load_hex(uint8_t *dst, uint32_t addr, const char* path, uint32_t max) {

  FILE* fd = fopen(path, "r");
  if (!fd) {
    return false;
  }

  const uint32_t start = addr;

  while (!feof(fd)) {

    uint32_t value = 0;
    if (!fscanf(fd, "%02x ", &value)) {
      break;
    }

    dst[addr] = value & 0xff;
    addr += 1;

    if (0 == --max) {
      break;
    }
  }

  printf("'%s' loaded (%05xh..%05xh)\n", path, start, addr);

  fclose(fd);
  return true;
}

static bool load_bin(uint8_t* dst, uint32_t addr, const char* path, uint32_t max) {

  const uint32_t top = 0x100000;

  assert(addr < top);

  FILE* fd = fopen(path, "rb");
  if (!fd) {
    return false;
  }

  fseek(fd, 0, SEEK_END);
  const uint32_t size = ftell(fd);
  fseek(fd, 0, SEEK_SET);

  uint32_t end = addr + size;
  if (end > top) {
    end = top;
  }
  uint32_t todo = end - addr;
  if (todo > max) todo = max;

  fread(dst + addr, 1, todo, fd);

  printf("'%s' loaded (%05xh..%05xh)\n", path, addr, end);

  fclose(fd);
  return true;
}

int main(int argc, char** args) {

  SDL_Init(SDL_INIT_VIDEO);

#if 0
  for (uint32_t i = 0; i < 1024 * 1024; ++i) {
    memory[i] = 0x90;
  }
#endif

  cpu_init();

  const char* biosPath = argc >= 2 ? args[1] : "C:\\riscv\\iceXt\\misc\\BIOS\\pcxtbios.bin";
  const char* romPath  = argc >= 3 ? args[2] : "C:\\riscv\\iceXt\\misc\\diskrom\\bin\\diskrom.hex";
  const char* diskPath = argc >= 4 ? args[3] : "C:\\riscv\\iceXt\\misc\\dos-boot-2.img";

  if (!load_hex(memory, 0xfe000, biosPath, 1024 * 8)) {
    fprintf(stderr, "Unable to load BIOS!\n");
    return 1;
  }

  if (!load_hex(memory, 0xc8000, romPath, 1024 * 4)) {
    fprintf(stderr, "Unable to load ROM!\n");
    return 1;
  }

  if (!disk_load(diskPath)) {
    fprintf(stderr, "Unable to load disk!\n");
    return 1;
  }

  memory[0x410] = 0b00101100;
  memory[0x410] = 0b00000000;

  const uint32_t steps = 100000;
  uint32_t irq0 = 0;

  SDL_Surface* screen = SDL_SetVideoMode(640, 400, 32, 0);
  if (!screen) {
    return 1;
  }

  bool active = true;
  while (active) {

    SDL_Event event = { 0 };
    while (SDL_PollEvent(&event)) {
      if (event.type == SDL_QUIT) {
        active = false;
      }
      if (event.type == SDL_KEYDOWN) {
        keyboard_key_event(&event);
      }
      if (event.type == SDL_KEYUP) {
        keyboard_key_event(&event);
      }
    }
  
    cpu_debug = false;

    for (uint32_t i = 0; i < steps; ++i) {

      cpu_step();

      if (irq0++ >= 100000) {
        cpu_interrupt(0);
        irq0 = 0;
      }
    }

    display_draw(screen);
    SDL_Flip(screen);
  }

  SDL_Quit();
  return 0;
}
