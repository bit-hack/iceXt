#pragma once

#include <stdbool.h>
#include <stdint.h>

#define _SDL_main_h
#include <SDL.h>


void    display_set_mode (uint8_t mode);
void    display_mem_write(uint32_t addr, uint8_t data);
void    display_io_write (uint32_t port, uint8_t data);
uint8_t display_io_read  (uint32_t port);
void    display_draw     (SDL_Surface* screen);
