#include <stdio.h>

#include "keyboard.h"
#include "cpu.h"


static uint8_t buffer_recv;


static uint8_t keyScanCode(int in);


void keyboard_io_write(uint16_t port, uint8_t data) {
  if (port == 0x60) {
  }
}

bool keyboard_io_read(uint16_t port, uint8_t* out) {
  if (port == 0x60) {
    *out = buffer_recv;
    return true;
  }
  return false;
}

void keyboard_key_event(SDL_Event* event) {
  if (event->type == SDL_KEYDOWN) {
    buffer_recv = 0x00 | keyScanCode(event->key.keysym.sym);
    cpu_interrupt(1);
  }
  if (event->type == SDL_KEYUP) {
    buffer_recv = 0x80 | keyScanCode(event->key.keysym.sym);
    cpu_interrupt(1);
  }
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
