#ifndef JTAG_H
#define JTAG_H

#include <Arduino.h>

// Initialize JTAG GPIOs
void jtag_init();

// TAP Controller
void tap_reset();
void goto_shift_ir();
void goto_shift_dr();

// Low-level JTAG I/O
void jtag_write(bool tms, bool tdi);
int  jtag_read(bool tms, bool tdi);

// Instruction Register
void shift_ir(uint8_t ir);

// Data Register
uint32_t read_dr32();
uint64_t transfer_dr41(uint64_t value);

#endif
