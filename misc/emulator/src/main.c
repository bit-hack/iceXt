#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>

#include "cpu.h"


static uint8_t memory[1024 * 1024];

uint8_t port_read(unsigned port) {
  printf("PORT READ: %03x\n", port);
  return 0xff;
}

void port_write(unsigned port, uint8_t value) {
  printf("PORT WRITE: %03x <= %02x\n", port, value);
}

uint8_t mem_read(uint32_t addr) {
  addr &= 0x1fff;
  return memory[addr & 0xfffff];
}

void mem_write(uint32_t addr, uint8_t data) {
  addr &= 0x1fff;
  memory[addr & 0xfffff] = data;
}

bool load_hex(uint32_t addr, const char* path) {

  FILE* fd = fopen(path, "r");
  if (!fd) {
    return false;
  }

  const uint32_t start = addr;

  while (!feof(fd)) {

    char temp[256] = { 0 };
    if (!fgets(temp, sizeof(temp) - 1, fd)) {
      break;
    }

    uint32_t value = 0;
    if (!sscanf(temp, "%02x", &value)) {
      break;
    }

    mem_write(addr, value & 0xff);
    addr += 1;
  }

  printf("'%s' loaded (%05xh..%05xh)\n", path, start, addr);

  fclose(fd);
  return true;
}

int main(int argc, char** args) {

  cpu_init();

  for (uint32_t i = 0; i < 1024 * 1024; ++i) {
    memory[i] = 0x90;
  }

  if (argc >= 2) {
    if (!load_hex(0, args[1])) {
      return 1;
    }
  }

  const uint32_t steps = (argc >= 3) ? atoi(args[2]) : 100;

  for (uint32_t i = 0; i < steps; ++i) {
    cpu_step();
  }

  return 0;
}
