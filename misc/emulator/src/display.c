#include "display.h"


extern uint8_t font[];

static uint8_t vram[1024 * 16];

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


static void render_mode_ega_gfx(SDL_Surface* screen);


static void render_mode_cga_gfx(SDL_Surface* screen) {
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

    uint32_t addrx = ((iy / 2) * (320 / 4)) + ((iy & 1) ? 0x2000 : 0);

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

static void render_mode_cga_txt(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  uint32_t* dst = screen->pixels;

  for (uint32_t y = 0; y < 400; ++y) {
    uint32_t iy = y / 2;

    uint32_t addrx = (iy / 8) * (80 * 2);
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

void display_cga_mem_write(uint32_t addr, uint8_t data) {
  vram[addr] = data;
}

uint8_t display_cga_mem_read(uint32_t addr) {
  return vram[addr];
}

void display_cga_io_write(uint32_t port, uint8_t data) {
  switch (port) {
  case 0x3d8: reg3D8 = data; break;  // Mode control register
  case 0x3d9: reg3D9 = data; break;  // Color control register
  }
}

bool display_cga_io_read(uint32_t port, uint8_t *out) {
  return false;
}

void display_set_mode(uint8_t mode) {
  display_mode = mode;
}

void display_draw(SDL_Surface* screen) {

  switch (display_mode) {
  case 4:
  case 5:
    render_mode_cga_gfx(screen);
    break;
  case 0xd:
    render_mode_ega_gfx(screen);
    break;
  default:
    render_mode_cga_txt(screen);
    break;
  }
}

//----------------------------------------------------------------

// EGA memory planes
static uint8_t plane0[16 * 1024];
static uint8_t plane1[16 * 1024];
static uint8_t plane2[16 * 1024];
static uint8_t plane3[16 * 1024];

static uint8_t latch0;
static uint8_t latch1;
static uint8_t latch2;
static uint8_t latch3;

static uint8_t palette[16] = {
  0,
  1,
  2,
  3,
  4,
  5,
  20,
  7,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63
};

static uint8_t p3C0_ff;         // 0-index, 1-data
static uint8_t p3C0_index = 0;

static uint8_t p3C4_index = 0;
static uint8_t p3C4_2 = 0xf;    // Graphics: Bit Mask Register

static uint8_t p3CE_index = 0;
static uint8_t p3CE_0 = 0;      // Graphics: Set/Reset Register
static uint8_t p3CE_1 = 0;      // Graphics: Enable Set/Reset Register
static uint8_t p3CE_4 = 0;      // Graphics: Read Map Select Register
static uint8_t p3CE_5 = 0;      // Graphics: Mode Register
static uint8_t p3CE_8 = 0;      // Graphics: Bit Mask Register


static uint8_t ega_write_mode() {
  return p3CE_5 & 3;
}

static uint8_t ega_read_mode() {
  return (p3CE_5 >> 3) & 1;
}

static uint8_t ega_read_plane() {
  // Number of the plane Read Mode 0 will read from.
  return (p3CE_4 & 3);
}

static void render_mode_ega_gfx(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  uint32_t* dst = screen->pixels;

  for (uint32_t y = 0; y < 400; ++y) {
    uint32_t iy = y / 2;

    for (uint32_t x = 0; x < 640; ++x) {
      uint32_t ix = x / 2;

      dst[x] = 0xFF00FF;
    }

    dst += screen->pitch / 4;
  }
}

void display_ega_mem_write(uint32_t addr, uint8_t data) {

  const uint8_t mode = ega_write_mode();

  const o0 = plane0[addr] & ~p3CE_8;
  const o1 = plane1[addr] & ~p3CE_8;
  const o2 = plane2[addr] & ~p3CE_8;
  const o3 = plane3[addr] & ~p3CE_8;

  // mode0
  if (mode == 0) {
    // TODO
    return;
  }

  // mode1
  if (mode == 1) {
    if (p3C4_2 & 0b0001) { plane0[addr] = o0 | (p3CE_8 & latch0); }
    if (p3C4_2 & 0b0010) { plane1[addr] = o1 | (p3CE_8 & latch1); }
    if (p3C4_2 & 0b0100) { plane2[addr] = o2 | (p3CE_8 & latch2); }
    if (p3C4_2 & 0b1000) { plane3[addr] = o3 | (p3CE_8 & latch3); }
    return;
  }

  // mode2
  if (mode == 2) {
    if (p3C4_2 & 0b0001) { plane0[addr] = o0 | p3CE_8; }
    if (p3C4_2 & 0b0010) { plane1[addr] = o1 | p3CE_8; }
    if (p3C4_2 & 0b0100) { plane2[addr] = o2 | p3CE_8; }
    if (p3C4_2 & 0b1000) { plane3[addr] = o3 | p3CE_8; }
    return;
  }
}

uint8_t display_ega_mem_read(uint32_t addr) {

  latch0 = plane0[addr & 0x3fff];
  latch1 = plane1[addr & 0x3fff];
  latch2 = plane2[addr & 0x3fff];
  latch3 = plane3[addr & 0x3fff];

  if (ega_read_mode() == 0) {

    switch (ega_read_plane()) {
    case 0: return latch0;
    case 1: return latch1;
    case 2: return latch2;
    case 3: return latch3;
    }

  }
  if (ega_read_mode() == 1) {

    // TODO
  }

  return 0;
}

void ega_write_3C0(uint8_t data) {
  if (p3C0_ff == 0) {  // index write
    p3C0_index = data;
  }
  if (p3C0_ff == 1) {  // data write

    if (p3C0_index < 16) {
      palette[p3C0_index & 0xf] = data;
    }

  }
  p3C0_ff = !p3C0_ff;
}

void ega_write_3C5(uint8_t index, uint8_t data) {
  if (index == 2) {
    p3C4_2 = data;  // Sequencer: Map Mask Register
  }
}

void ega_write_3CF(uint8_t index, uint8_t data) {
  if (index == 0) {
    p3CE_0 = data;  // Graphics: Set/Reset Register
  }
  if (index == 1) {
    p3CE_1 = data;  // Graphics: Enable Set/Reset Register
  }
  if (index == 4) {
    p3CE_4 = data;  // Graphics: Read Map Select Register
  }
  if (index == 5) {
    p3CE_5 = data;  // Graphics: Mode Register
  }
  if (index == 8) {
    p3CE_8 = data;  // Graphics: Bit(Map) Mask Register
  }
}

void display_ega_io_write(uint32_t port, uint8_t data) {
  if (port == 0x3C0) {
    ega_write_3C0(data);
  }
  if (port == 0x3C4) {
    p3C4_index = data;
  }
  if (port == 0x3C5) {
    ega_write_3C5(p3C4_index, data);
  }
  if (port == 0x3CE) {
    p3CE_index = data;
  }
  if (port == 0x3CF) {
    ega_write_3CF(p3CE_index, data);
  }
}

bool display_ega_io_read(uint32_t port, uint8_t *out) {
  if (port == 0x3DA) {
    p3C0_ff = 0;  // reset FF to address
  }
  return false;
}
