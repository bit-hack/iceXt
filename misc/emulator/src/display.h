#pragma once

#include <stdbool.h>
#include <stdint.h>

#define _SDL_main_h
#include <SDL.h>


void    display_set_mode(uint8_t mode);
void    display_draw    (SDL_Surface* screen);

void    display_cga_mem_write(uint32_t addr, uint8_t data);
uint8_t display_cga_mem_read (uint32_t addr);
void    display_cga_io_write (uint32_t port, uint8_t data);
bool    display_cga_io_read  (uint32_t port, uint8_t *out);

void    display_ega_mem_write(uint32_t addr, uint8_t data);
uint8_t display_ega_mem_read (uint32_t addr);
void    display_ega_io_write (uint32_t port, uint8_t data);
bool    display_ega_io_read  (uint32_t port, uint8_t* out);
