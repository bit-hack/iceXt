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


uint8_t memory[1024 * 1024];

uint8_t p60;  // port 60h

static uint8_t keyScanCode(int in);


void int_notify(uint8_t num) {

  if (num == 0x13) {

    uint8_t ah = cpu_get_AH();
    switch (ah) {
    case 2:
      break;
    default:
      printf("13h\n", ah);
      cpu_dump_state();
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

  if (port == 0xb8) {
    return disk_spi_read();
  }

  if (port == 0xb9) {
    return 0;  // SPI not busy
  }

  if (port == 0x60) {
    return p60;
  }

  uint8_t out = 0;

  if (display_cga_io_read(port, &out)) {
    return out;
  }

  if (display_ega_io_read(port, &out)) {
    return out;
  }

  return 0;
}

void dump_sector() {
  uint8_t* src = memory + 0x7c00;
  for (uint32_t i = 0; i < 512; ++i) {
    if (i && (!(i & 0xf))) {
      printf("\n");
    }
    printf("%02x ", src[i]);
  }
}

void port_write(uint32_t port, uint8_t value) {
//  printf("PORT WRITE: %03x <= %02x\n", port, value);

  if (port == 0x60) {
    p60 = value;
  }

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

  if (port == 0x20 || port == 0x21) {
    if (port == 0x20 && value == 0x20) {
      // EOI
    }
    else {
      //printf("PIC %02x <- %02x\n", port, value);
    }
  }

  if ((port & ~0x03) == 0x40) {
    //printf("PIT %02x <- %02x\n", port, value);
  }

  if (port == 0xfe) {
    //printf("video mode change %x\n", value);
  }

  display_cga_io_write(port & 0xfff, value);
  display_ega_io_write(port & 0xfff, value);
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

static bool load_bin(uint32_t addr, const char* path) {

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
  const uint32_t todo = end - addr;

  fread(memory + addr, 1, todo, fd);

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
        port_write(0x60, 0x00 | keyScanCode(event.key.keysym.sym));
        cpu_interrupt(1);
      }
      if (event.type == SDL_KEYUP) {
        port_write(0x60, 0x80 | keyScanCode(event.key.keysym.sym));
        cpu_interrupt(1);
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

static uint8_t keyScanCode(int in) {
  switch (in) {
  case SDLK_ESCAPE:          return 0x01;
  case SDLK_1:               return 0x02;
  case SDLK_2:               return 0x03;
  case SDLK_3:               return 0x04;
  case SDLK_4:               return 0x05;
  case SDLK_5:               return 0x06;
  case SDLK_6:               return 0x07;
  case SDLK_7:               return 0x08;
  case SDLK_8:               return 0x09;
  case SDLK_9:               return 0x0A;
  case SDLK_0:               return 0x0B;
  case SDLK_MINUS:           return 0x0C;
  case SDLK_EQUALS:          return 0x0D;
  case SDLK_BACKSPACE:       return 0x0E;
  case SDLK_TAB:             return 0x0F;
  case SDLK_q:               return 0x10;
  case SDLK_w:               return 0x11;
  case SDLK_e:               return 0x12;
  case SDLK_r:               return 0x13;
  case SDLK_t:               return 0x14;
  case SDLK_y:               return 0x15;
  case SDLK_u:               return 0x16;
  case SDLK_i:               return 0x17;
  case SDLK_o:               return 0x18;
  case SDLK_p:               return 0x19;
  case SDLK_LEFTBRACKET:     return 0x1A;
  case SDLK_RIGHTBRACKET:    return 0x1B;
  case SDLK_RETURN:          return 0x1C;
  case SDLK_LCTRL:           return 0x1D;
  case SDLK_a:               return 0x1E;
  case SDLK_s:               return 0x1F;
  case SDLK_d:               return 0x20;
  case SDLK_f:               return 0x21;
  case SDLK_g:               return 0x22;
  case SDLK_h:               return 0x23;
  case SDLK_j:               return 0x24;
  case SDLK_k:               return 0x25;
  case SDLK_l:               return 0x26;
  case SDLK_SEMICOLON:       return 0x27;
  case SDLK_AT:              return 0x28;
  case SDLK_HASH:            return 0x29;
  case SDLK_LSHIFT:          return 0x2A;
  case SDLK_BACKSLASH:       return 0x2B;
  case SDLK_z:               return 0x2C;
  case SDLK_x:               return 0x2D;
  case SDLK_c:               return 0x2E;
  case SDLK_v:               return 0x2F;
  case SDLK_b:               return 0x30;
  case SDLK_n:               return 0x31;
  case SDLK_m:               return 0x32;
  case SDLK_COMMA:           return 0x33;
  case SDLK_PERIOD:          return 0x34;
  case SDLK_SLASH:           return 0x35;
  case SDLK_RSHIFT:          return 0x36;
  case SDLK_KP_MULTIPLY:     return 0x37;
  case SDLK_LALT:            return 0x38;
  case SDLK_SPACE:           return 0x39;
  case SDLK_CAPSLOCK:        return 0x3A;
  case SDLK_F1:              return 0x3B;
  case SDLK_F2:              return 0x3C;
  case SDLK_F3:              return 0x3D;
  case SDLK_F4:              return 0x3E;
  case SDLK_F5:              return 0x3F;
  case SDLK_F6:              return 0x40;
  case SDLK_F7:              return 0x41;
  case SDLK_F8:              return 0x42;
  case SDLK_F9:              return 0x43;
  case SDLK_F10:             return 0x44;
  case SDLK_NUMLOCK:         return 0x45;
  case SDLK_SCROLLOCK:       return 0x46;
  case SDLK_KP7:             return 0x47;
  case SDLK_KP8:             return 0x48;
  case SDLK_KP9:             return 0x49;
  case SDLK_KP_MINUS:        return 0x4A;
  case SDLK_KP4:             return 0x4B;
  case SDLK_KP5:             return 0x4C;
  case SDLK_KP6:             return 0x4D;
  case SDLK_KP_PLUS:         return 0x4E;
  case SDLK_KP1:             return 0x4F;
  case SDLK_KP2:             return 0x50;
  case SDLK_KP3:             return 0x51;
  case SDLK_KP0:             return 0x52;
  case SDLK_KP_PERIOD:       return 0x53;
  case SDLK_PRINT:           return 0x54;
    //  case SDLK_SLASH:           return 0x56;
  case SDLK_F11:             return 0x57;
  case SDLK_F12:             return 0x58;

  case SDLK_LEFT:            return 0x4b;
  case SDLK_RIGHT:           return 0x4d;
  case SDLK_UP:              return 0x48;
  case SDLK_DOWN:            return 0x50;
  }
  return 0;
}
