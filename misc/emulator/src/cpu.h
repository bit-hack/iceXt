#pragma once
#include <stdint.h>
#include <stdio.h>
#include <string.h>

uint32_t cpuGetAddress(uint16_t segment, uint16_t offset);
uint32_t cpuGetAddrDS(uint16_t offset);
uint32_t cpuGetAddrES(uint16_t offset);

uint8_t port_read (uint32_t port);
void    port_write(uint32_t port, uint8_t value);
uint8_t mem_read  (uint32_t addr);
void    mem_write (uint32_t addr, uint8_t data);

void cpu_dump(void);
void cpu_step(void);
void cpu_init(void);
void cpu_interrupt(uint8_t irqn);

// Trigger hardware interrupts.
// IRQ-0 to IRQ-7 call INT-08 to INT-0F
// IRQ-8 to IRQ-F call INT-70 to INT-77
void cpuTriggerIRQ(uint8_t num);

uint32_t cpuGetAX(void);
uint32_t cpuGetCX(void);
uint32_t cpuGetDX(void);
uint32_t cpuGetBX(void);
uint32_t cpuGetSP(void);
uint32_t cpuGetBP(void);
uint32_t cpuGetSI(void);
uint32_t cpuGetDI(void);
uint32_t cpuGetES(void);
uint32_t cpuGetCS(void);
uint32_t cpuGetSS(void);
uint32_t cpuGetDS(void);
uint32_t cpuGetIP(void);
