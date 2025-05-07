#pragma once

#include <stdbool.h>

bool disk_load(const char* path);
void disk_int13(void);

void disk_read_sector(void);
