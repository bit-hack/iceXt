#pragma once
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

enum { AX, CX, DX, BX, SP, BP, SI, DI };
enum { ES, CS, SS, DS, NoSeg };

extern uint8_t memory[1024 * 1024];
extern uint8_t io[1024 * 64];
extern bool cpu_debug;

uint32_t cpu_get_address(uint16_t segment, uint16_t offset);

uint8_t port_read (uint32_t port);
void    port_write(uint32_t port, uint8_t value);
uint8_t mem_read  (uint32_t addr);
void    mem_write (uint32_t addr, uint8_t data);

void cpu_step(void);
void cpu_init(void);
void cpu_interrupt(uint8_t irqn);

uint8_t  cpu_get_AH(void);
uint8_t  cpu_get_AL(void);
uint16_t cpu_get_AX(void);
uint8_t  cpu_get_CH(void);
uint8_t  cpu_get_CL(void);
uint16_t cpu_get_CX(void);
uint8_t  cpu_get_DH(void);
uint8_t  cpu_get_DL(void);
uint16_t cpu_get_DX(void);
uint8_t  cpu_get_BH(void);
uint8_t  cpu_get_BL(void);
uint16_t cpu_get_BX(void);
uint16_t cpu_get_SP(void);
uint16_t cpu_get_BP(void);
uint16_t cpu_get_SI(void);
uint16_t cpu_get_DI(void);
uint16_t cpu_get_ES(void);
uint16_t cpu_get_CS(void);
uint16_t cpu_get_SS(void);
uint16_t cpu_get_DS(void);
uint16_t cpu_get_IP(void);

// Set CPU registers from outside
void cpu_set_AH(uint8_t  v);
void cpu_set_AL(uint8_t  v);
void cpu_set_AX(uint16_t v);

void cpu_set_CH(uint8_t  v);
void cpu_set_CL(uint8_t  v);
void cpu_set_CX(uint16_t v);

void cpu_set_DH(uint8_t  v);
void cpu_set_DL(uint8_t  v);
void cpu_set_DX(uint16_t v);

void cpu_set_BH(uint8_t  v);
void cpu_set_BL(uint8_t  v);
void cpu_set_BX(uint16_t v);

void cpu_set_SP(uint16_t v);
void cpu_set_BP(uint16_t v);
void cpu_set_SI(uint16_t v);
void cpu_set_DI(uint16_t v);
void cpu_set_ES(uint16_t v);
void cpu_set_CS(uint16_t v);
void cpu_set_SS(uint16_t v);
void cpu_set_DS(uint16_t v);
void cpu_set_IP(uint16_t v);

void cpu_set_CF(uint8_t  v);

void cpu_dump_state();
