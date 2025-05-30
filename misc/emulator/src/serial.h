#pragma once
#include <stdint.h>
#include <stdbool.h>


void serial_io_write(uint16_t port, uint8_t value);
bool serial_io_read(uint16_t port, uint8_t* out);
