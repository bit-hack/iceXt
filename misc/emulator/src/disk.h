#pragma once

#include <stdbool.h>

bool disk_load(const char* path);
void disk_int13(void);

void    disk_spi_ctrl (uint8_t tx);
void    disk_spi_write(uint8_t tx);
uint8_t disk_spi_read ();
