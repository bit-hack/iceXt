/*                     .__       .__
 *   ______ ___________|__|____  |  |
 *  /  ___// __ \_  __ \  \__  \ |  |
 *  \___ \\  ___/|  | \/  |/ __ \|  |__
 * /____  >\___  >__|  |__(____  /____/
 *      \/     \/              \/
 */
 #pragma once

#include <stdint.h>

typedef struct serial_t serial_t;

serial_t *serial_open(
  uint32_t port,
  uint32_t baud_rate);

void serial_close(
  serial_t *serial);

uint32_t serial_send(
  serial_t *serial,
  const void *data,
  size_t nbytes);

uint32_t serial_read(
  serial_t *serial,
  void *dst,
  size_t nbytes);

void serial_flush(
  serial_t *serial);

void serial_purge(
  serial_t* serial);
