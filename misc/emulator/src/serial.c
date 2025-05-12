/*                     .__       .__
 *   ______ ___________|__|____  |  |
 *  /  ___// __ \_  __ \  \__  \ |  |
 *  \___ \\  ___/|  | \/  |/ __ \|  |__
 * /____  >\___  >__|  |__(____  /____/
 *      \/     \/              \/
 */
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

#include "serial.h"


struct serial_t {
  HANDLE handle;
};


static BOOL set_timeouts(
  HANDLE handle)
{
  COMMTIMEOUTS com_timeout;
  ZeroMemory(&com_timeout, sizeof(com_timeout));
  com_timeout.ReadIntervalTimeout         = 3;
  com_timeout.ReadTotalTimeoutMultiplier  = 3;
  com_timeout.ReadTotalTimeoutConstant    = 2;
  com_timeout.WriteTotalTimeoutMultiplier = 3;
  com_timeout.WriteTotalTimeoutConstant   = 2;
  return SetCommTimeouts(handle, &com_timeout);
}


serial_t *serial_open(
  uint32_t port,
  uint32_t baud_rate)
{
  // construct com port device name
  char dev_name[32];
  snprintf(dev_name, sizeof(dev_name), "\\\\.\\COM%d", (int)port);
  // open handle to serial device
  HANDLE handle = CreateFileA(
    dev_name,
    GENERIC_READ | GENERIC_WRITE,
    0,
    NULL,
    OPEN_EXISTING,
    0,
    NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    goto on_error;
  }
  // query serial device control block
  DCB dbc;
  ZeroMemory(&dbc, sizeof(dbc));
  dbc.DCBlength = sizeof(dbc);
  if (GetCommState(handle, &dbc) == FALSE) {
    goto on_error;
  }
  // change baud rate
  if (dbc.BaudRate != baud_rate) {
    dbc.BaudRate = baud_rate;
  }
  dbc.fBinary      = TRUE;
  dbc.fParity      = FALSE;
  dbc.fOutxCtsFlow = FALSE;
  dbc.fDtrControl  = FALSE;
  dbc.ByteSize     = 8;
  dbc.fOutX        = FALSE;
  dbc.fInX         = FALSE;
  dbc.fNull        = FALSE;
  dbc.fRtsControl  = RTS_CONTROL_DISABLE;
  dbc.Parity       = NOPARITY;
  dbc.StopBits     = ONESTOPBIT;
  dbc.EofChar      = 0;
  dbc.ErrorChar    = 0;
  dbc.EvtChar      = 0;
  dbc.XonChar      = 0;
  dbc.XoffChar     = 0;

  // warning: this seems to write a number of rogue bytes to the  serial port.
  if (SetCommState(handle, &dbc) == FALSE) {
    goto on_error;
  }
  // set com timeouts
  if (set_timeouts(handle) == FALSE) {
    goto on_error;
  }
  // wrap in serial object
  serial_t *serial = (serial_t*)malloc(sizeof(serial_t));
  if (serial == NULL) {
    goto on_error;
  }
  serial->handle = handle;

  // make sure all input and output queues are clear before we continue
  PurgeComm(handle, PURGE_TXCLEAR | PURGE_RXCLEAR);

  // success
  return serial;
  // error handler
on_error:
  if (handle != INVALID_HANDLE_VALUE)
    CloseHandle(handle);
  return NULL;
}

void serial_close(
  serial_t *serial)
{
  assert(serial);
  if (serial->handle != INVALID_HANDLE_VALUE) {
    CloseHandle(serial->handle);
  }
  free(serial);
}

uint32_t serial_send(
  serial_t *serial,
  const void *data,
  size_t nbytes)
{
  assert(serial && data && nbytes);
  DWORD nb_written = 0;
  if (WriteFile(
        serial->handle,
        data,
        (DWORD)nbytes,
        &nb_written,
        NULL) == FALSE) {
    return 0;
  }
  return nb_written;
}

uint32_t serial_read(
  serial_t *serial,
  void *dst,
  size_t nbytes)
{
  assert(serial && dst && nbytes);
  DWORD nb_read = 0;
  if (ReadFile(
        serial->handle,
        dst,
        (DWORD)nbytes,
        &nb_read,
        NULL) == FALSE) {
    return 0;
  }
  return nb_read;
}

void serial_flush(
  serial_t *serial) {
  FlushFileBuffers(serial->handle);
}

void serial_purge(
  serial_t* serial) {
  PurgeComm(serial->handle, PURGE_TXCLEAR | PURGE_RXCLEAR);
}
