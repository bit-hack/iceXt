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
  printf("Display Mode: %x\n", mode);
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
static uint8_t p3CE_2 = 0;      // Graphics: Color Compare Register
static uint8_t p3CE_3 = 0;      // Graphics: Data Rotate
static uint8_t p3CE_4 = 0;      // Graphics: Read Map Select Register
static uint8_t p3CE_5 = 0;      // Graphics: Mode Register
static uint8_t p3CE_7 = 0;      // Graphics: Color Don't Care Register
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

static uint8_t ega_rotate() {
  // note: only active in write mode 0
  return (p3CE_3 & 7);
}

static uint8_t ega_alu_func() {
  return (p3CE_3 >> 3) & 3;
}

static void render_mode_ega_gfx(SDL_Surface* screen) {
  SDL_FillRect(screen, NULL, 0x101010);

  uint32_t dst_pitch = (screen->pitch / 4);
  uint32_t src_pitch = 320 / 8;

  uint32_t* dst0 = screen->pixels;
  uint32_t* dst1 = ((uint32_t*)screen->pixels) + dst_pitch;

  uint8_t scanline[320] = { 0 };

  for (uint32_t y = 0; y < 200; ++y) {

    uint32_t base = y * src_pitch;

    for (uint32_t x = 0; x < 320; x += 8) {
      for (uint32_t i = 0; i < 8; ++i) {

        const uint8_t mask = 0x80 >> i;

        const uint8_t b0 = plane0[base + (x/8)] & mask;
        const uint8_t b1 = plane1[base + (x/8)] & mask;
        const uint8_t b2 = plane2[base + (x/8)] & mask;
        const uint8_t b3 = plane3[base + (x/8)] & mask;

        scanline[x + i] =
          (b0 ? 0x1 : 0x0) |
          (b1 ? 0x2 : 0x0) |
          (b2 ? 0x4 : 0x0) |
          (b3 ? 0x8 : 0x0);
      }
    }

    for (uint32_t x = 0; x < 320; ++x) {

      uint8_t index = palette[ scanline[ x ] & 0xf ];

      // x x RL GL BL RH GH BH

      uint32_t r = ((index >> 1) & 2) | ((index >> 5) & 1);
      uint32_t g = ((index >> 0) & 2) | ((index >> 4) & 1);
      uint32_t b = ((index << 1) & 2) | ((index >> 3) & 1);

      uint32_t rgb = ((r << 24) | (g << 16) | (b << 8)) >> 2;

      dst0[ x * 2 + 0 ] = rgb;
      dst0[ x * 2 + 1 ] = rgb;
      dst1[ x * 2 + 0 ] = rgb;
      dst1[ x * 2 + 1 ] = rgb;
    }

    dst0 += dst_pitch * 2;
    dst1 += dst_pitch * 2;
  }
}

static uint8_t blend(uint8_t mask, uint8_t a, uint8_t b) {
  return (a & mask) | (b & ~mask);
}

static uint8_t rotate(uint8_t rot, uint8_t a) {
  const uint16_t t = (a << 8) >> rot;
  return ((t & 0xff00) | ((t & 0xff) << 8)) >> 8;
}

void ega_write_planes(uint32_t addr, uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3) {
  if (p3C4_2 & 1) { plane0[addr] = d0; }
  if (p3C4_2 & 2) { plane1[addr] = d1; }
  if (p3C4_2 & 4) { plane2[addr] = d2; }
  if (p3C4_2 & 8) { plane3[addr] = d3; }
}

uint8_t alu_op(uint8_t a, uint8_t b) {
  switch (ega_alu_func() & 3) {
  case 0: return a;
  case 1: return a & b;
  case 2: return a | b;
  case 3: return a ^ b;
  }
}

void display_ega_mem_write(uint32_t addr, uint8_t data) {

  const uint8_t mode = ega_write_mode();

  // mode0
  if (mode == 0) {

    data = rotate(ega_rotate(), data);

    // compute set/reset values
    const uint8_t sr0 = (p3CE_0 & 1) ? 0xff : 0x00;
    const uint8_t sr1 = (p3CE_0 & 2) ? 0xff : 0x00;
    const uint8_t sr2 = (p3CE_0 & 4) ? 0xff : 0x00;
    const uint8_t sr3 = (p3CE_0 & 8) ? 0xff : 0x00;

    // set/reset enable mux
    const uint8_t in0 = (p3CE_1 & 1) ? sr0 : data;
    const uint8_t in1 = (p3CE_1 & 2) ? sr1 : data;
    const uint8_t in2 = (p3CE_1 & 4) ? sr2 : data;
    const uint8_t in3 = (p3CE_1 & 8) ? sr3 : data;

    // ALU result
    const uint8_t alu0 = alu_op(in0, latch0);
    const uint8_t alu1 = alu_op(in1, latch1);
    const uint8_t alu2 = alu_op(in2, latch2);
    const uint8_t alu3 = alu_op(in3, latch3);

    ega_write_planes(addr,
      blend(p3CE_8, alu0, latch0),
      blend(p3CE_8, alu1, latch1),
      blend(p3CE_8, alu2, latch2),
      blend(p3CE_8, alu3, latch3)
    );
    return;
  }

  // mode1
  if (mode == 1) {
    ega_write_planes(addr,
      latch0,
      latch1,
      latch2,
      latch3
    );
    return;
  }

  // mode2
  if (mode == 2) {

    const uint8_t b0 = (data & 1) ? 0xff : 0x00;
    const uint8_t b1 = (data & 2) ? 0xff : 0x00;
    const uint8_t b2 = (data & 4) ? 0xff : 0x00;
    const uint8_t b3 = (data & 8) ? 0xff : 0x00;

    // ALU result
    const uint8_t alu0 = alu_op(b0, latch0);
    const uint8_t alu1 = alu_op(b1, latch1);
    const uint8_t alu2 = alu_op(b2, latch2);
    const uint8_t alu3 = alu_op(b3, latch3);

    ega_write_planes(addr,
      blend(p3CE_8, alu0, latch0),
      blend(p3CE_8, alu1, latch1),
      blend(p3CE_8, alu2, latch2),
      blend(p3CE_8, alu3, latch3)
    );
    return;
  }
}

uint8_t display_ega_mem_read(uint32_t addr) {

  // a read fills the latches
  latch0 = plane0[addr];
  latch1 = plane1[addr];
  latch2 = plane2[addr];
  latch3 = plane3[addr];

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

  return 0xff;
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
  if (index == 2) {
    p3CE_2 = data;  // Graphics: Color Compare Register
  }
  if (index == 3) {
    p3CE_3 = data;  // Graphics: Data Rotate 
  }
  if (index == 4) {
    p3CE_4 = data;  // Graphics: Read Map Select Register
  }
  if (index == 5) {
    p3CE_5 = data;  // Graphics: Mode Register
  }
  if (index == 7) {
    p3CE_7 = data;  // Graphics: Color Don't Care Register
  }
  if (index == 8) {
    p3CE_8 = data;  // Graphics: Bit(Map) Mask Register
  }
}

void display_ega_io_write(uint32_t port, uint8_t data) {

  if ((port & 0xF00) == 0x300) {
    printf("%03x <= %02x\n", port, data);
  }
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

  if ((port & 0xF00) == 0x300) {
    printf("%03x => ??\n", port);
  }

  if (port == 0x3DA) {
    p3C0_ff = 0;  // reset FF to address
    *out = 0xff;
    return true;
  }

  return false;
}
