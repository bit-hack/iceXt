#pragma once
#include <stdint.h>
#include <stdbool.h>

#define _SDL_main_h
#include <SDL.h>


void keyboard_io_write(uint16_t port, uint8_t data);
bool keyboard_io_read (uint16_t port, uint8_t *out);

void keyboard_key_event(SDL_Event* event);
