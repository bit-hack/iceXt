#include "serial.h"
#include "cpu.h"


// notes:
//
//  COM1 3F8 IRQ4
//  COM2 2F8 IRQ3
//  COM3 3E8 IRQ4
//  COM4 2E8 IRQ3
//

static uint8_t RBR;         // 3F8 receiver buffer
static uint8_t THR;         // 3F8 transmit holding register
static uint8_t IER;         // 3F9 interrupt enable
static uint8_t IIR = 1;     // 3FA interrupt ident
static uint8_t LCR;         // 3FB line control
static uint8_t MCR;         // 3FC modem control

static uint8_t LSR = 0b1100000;  // 3FD line status
// { 0, TEMT, THRE, BI, FE, PE, OE, DR }
// DR   - data ready
// OE   - overrun error
// PE   - parity error
// FE   - framing error
// BI   - break interrupt
// THRE - transmitter holding register
// TEMT - transmitter empty

static uint8_t MSR = 0x30;  // 3FE modem status
static uint8_t SCR;  // 3FF scratch reg
static uint8_t DLL;  // 3F8 divisor lsb
static uint8_t DLM;  // 3F9 divisor msb

#define DLAB ((LCR & 0x80) ? 1 : 0)


static void mouse_send(uint8_t data) {
  RBR = data;
  LSR |= (LSR & 1) ? 2 : 0;  // OE<=DR
  LSR |= 1;                  // DR<=1
}

void mouse_poll() {

}

void mouse_reset(uint8_t RTS) {
  if (/*@posedge */RTS) {
    mouse_send('M');
  }
}

void serial_io_write(uint16_t port, uint8_t value) {

  if (port >= 0x3F8 && port <= 0x3FF) {
    printf("%03x <= %02x\n", port, value);
  }

  if (port == (0x3F8+0)) {  // 3F8
    if (DLAB) {
      DLL = value;
    }
    else {
      // write to transmit buffer
      THR = value;
      LSR &= ~0b1100000; // lower TEMT, THRE
    }
  }
  if (port == (0x3F8+1)) {  // 3F9
    if (DLAB) {
      DLM = value;
    }
    else {
      // interrupt enable
      IER = value;
    }
  }
  if (port == (0x3F8+3)) {  // 3FB
    LCR = value;
  }
  if (port == (0x3F8+4)) {  // 3FC
    uint8_t delta = MCR ^ value;
    MCR = value;
    if (delta & 2) {
      mouse_reset(MCR & 2);  // call when DTR changes
    }
  }
  if (port == (0x3F8+5)) {  // 3FD
    LSR = value;
  }
  if (port == (0x3F8+6)) {  // 3FE
    MSR = value;
  }
  if (port == (0x3F8+7)) {  // 3FF
    SCR = value;
  }
}

bool _serial_io_read(uint16_t port, uint8_t* out) {
  if (port == (0x3F8+0)) {  // 3F8
    if (DLAB) {
      *out = DLL;
    }
    else {
      *out = RBR;
      LSR &= ~1;  // DR<=0
      mouse_poll();
    }
    return true;
  }
  if (port == (0x3F8+1)) {  // 3F9
    if (DLAB) {
      *out = DLM;
    }
    else {
      *out = IER;
    }
    return true;
  }
  if (port == (0x3F8+2)) {  // 3FA
    *out = IIR;
    IIR = 0b001;
    return true;
  }
  if (port == (0x3F8+3)) {  // 3FB
    *out = LCR;
    return true;
  }
  if (port == (0x3F8+4)) {  // 3FC
    *out = MCR;
    return true;
  }
  if (port == (0x3F8+5)) {  // 3FD
    *out = LSR;
    LSR &= 0b01100001;
    return true;
  }
  if (port == (0x3F8+6)) {  // 3FE
    *out = MSR;
    return true;
  }
  if (port == (0x3F8+7)) {  // 3FF
    *out = SCR;
    return true;
  }
  return false;
}


bool serial_io_read(uint16_t port, uint8_t* out) {

  if (!_serial_io_read(port, out)) {
    return false;
  }

  if (port == 0x3FD && *out == 0x60) {
  }
  else {
    printf("%03x => %02x\n", port, *out);
  }
  return true;
}
