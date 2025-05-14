#include "display.h"


extern uint8_t font[];

static uint8_t vram[1024 * 1024];

static uint8_t display_mode = 3;

// https://www.seasip.info/VintagePC/cga.html

// .......h
//        +--- high res text
//       +---- graphics mode
//      +----- black and white
//     +------ enable video output
//    +------- high res graphics
//   +-------- blinking
//
static uint8_t reg3D8 = 0;  // Mode control register

// ..pBbbbb
//     ++++--- border color
//    +------- bright foreground
//   +-------- palette
//
static uint8_t reg3D9 = 0;  // Color control register


static void render_mode_4(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  const uint32_t palette[] = {

    0x000000,   // 0
    0x00AAAA,   // 3
    0xAA00AA,   // 5
    0xAAAAAA,   // 7

    0x000000,   // 0
    0x55FFFF,   // 11
    0xFF55FF,   // 13
    0xFFFFFF,   // 15

  };

  uint32_t* dst = screen->pixels;

  uint32_t rgb0 = 0;
  uint32_t rgb1 = 0;

  uint32_t intensity = (reg3D9 & 0x10) ? 4 : 0;

  for (uint32_t y = 0; y < 400; ++y) {
    uint32_t iy = y / 2;

    uint32_t addrx = 0xB8000 + ((iy / 2) * (320 / 4)) + ((iy & 1) ? 0x2000 : 0);

    for (uint32_t x = 0; x < 640; ++x) {
      uint32_t ix = x / 2;

      uint8_t byte  = vram[addrx + ix / 4];
      uint8_t shift = (3 - ix % 4) * 2;
      uint8_t pix   = 3 & (byte >> shift);

      rgb1 = rgb0;
      rgb0 = palette[intensity | pix];
      dst[x] = ((rgb0 >> 1) & 0x7f7f7f) + ((rgb1 >> 1) & 0x7f7f7f);
    }

    dst += screen->pitch / 4;
  }
}

static void render_mda(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  uint32_t* dst = screen->pixels;

  for (uint32_t y = 0; y < 400; ++y) {
    uint32_t iy = y / 2;

    uint32_t addrx = 0xB8000 + (iy / 8) * (80 * 2);
    uint32_t cy = iy % 8;

    for (uint32_t x = 0; x < 640; ++x) {

      uint32_t addr = addrx + (x / 8) * 2;
      uint32_t cx = x % 8;

      uint8_t ch = vram[addr + 0];
      uint8_t at = vram[addr + 1];

      uint8_t font_row = font[ch * 8 + cy];
      uint8_t font_bit = font_row & (1 << cx);

      dst[x] = font_bit ? 0x93a1a8 : 0x101010;
    }

    dst += screen->pitch / 4;
  }
}

void display_set_mode(uint8_t mode) {
  display_mode = mode;
}

void display_mem_write(uint32_t addr, uint8_t data) {
  vram[addr] = data;
}

void display_io_write(uint32_t port, uint8_t data) {
  switch (port) {
  case 0x3d8:
    printf("%03x <= %02x\n", port, data);
    reg3D8 = data;
    break;
  case 0x3d9:
    printf("%03x <= %02x\n", port, data);
    reg3D9 = data;
    break;
  case 0x3D4:
    printf("%03x <= %02x\n", port, data);
    break;
  case 0x3D5:
    printf("%03x <= %02x\n", port, data);
    break;
  }
}

uint8_t display_io_read(uint32_t port) {
  return 0;
}

void display_draw(SDL_Surface* screen) {

  if (reg3D8 & 2) {
    render_mode_4(screen);
  }
  else {
    render_mda(screen);
  }
}
