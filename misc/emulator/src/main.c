#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>

#define _SDL_main_h
#include <SDL.h>

#include "cpu.h"


static uint8_t memory[1024 * 1024];
uint8_t font[];


uint8_t port_read(uint32_t port) {
//  printf("PORT READ: %03x\n", port);
  return 0x0;
}

void port_write(uint32_t port, uint8_t value) {
//  printf("PORT WRITE: %03x <= %02x\n", port, value);
}

uint8_t mem_read(uint32_t addr) {
  addr &= 0xfffff;
  return memory[addr];
}

void mem_write(uint32_t addr, uint8_t data) {
  addr &= 0xfffff;
  memory[addr] = data;
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

  FILE* fd = fopen(path, "r");
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

static void render_mda(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  uint32_t addry = 0xB0000;

  uint32_t* dst = screen->pixels;

  for (uint32_t y = 0; y < 400; ++y) {

    uint32_t addrx = 0xB0000 + (y / 16) * (80 * 2);
    uint32_t cy = (y / 2) % 8;

    for (uint32_t x = 0; x < 640; ++x) {

      uint32_t addr = addrx + (x / 8) * 2;
      uint32_t cx = x % 8;

      uint8_t ch = memory[addr + 0];
      uint8_t at = memory[addr + 1];

      uint8_t font_row = font[ch * 8 + cy];
      uint8_t font_bit = font_row & (1 << cx);

      dst[x] = font_bit ? 0x93a1a8 : 0x101010;
    }

    dst += screen->pitch / 4;
  }
}

int main(int argc, char** args) {

  SDL_Init(SDL_INIT_VIDEO);

#if 0
  for (uint32_t i = 0; i < 1024 * 1024; ++i) {
    memory[i] = 0x90;
  }
#endif

  cpu_init();

  const char* path = argc >= 2 ? args[1] : "program.hex";

  if (!load_hex(memory, 0xfe000, path, 1024 * 8)) {
    fprintf(stderr, "Unable to load program!\n");
    return 1;
  }

  const uint32_t steps = 10000;

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
    }

    for (uint32_t i = 0; i < steps; ++i) {
      cpu_step();
    }

    render_mda(screen);
    SDL_Flip(screen);
  }

  SDL_Quit();
  return 0;
}
