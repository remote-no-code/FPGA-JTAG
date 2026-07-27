#ifndef DTM_H
#define DTM_H

#include <Arduino.h>

//============================================================
// JTAG IR Instructions
//============================================================
#define IR_IDCODE   0x01
#define IR_DTMCS    0x10
#define IR_DMI      0x11

//============================================================
// DMI Operations
//============================================================
#define DMI_NOP     0
#define DMI_READ    1
#define DMI_WRITE   2

//============================================================
// Debug Module Registers
//============================================================
#define DATA0_ADDR        0x04
#define DATA1_ADDR        0x05

#define DMCONTROL_ADDR    0x10
#define DMSTATUS_ADDR     0x11
#define ABSTRACTCS_ADDR   0x16
#define COMMAND_ADDR      0x17

//============================================================
// Abstract Command Opcodes
//============================================================
#define CMD_REG_READ      0x01
#define CMD_REG_WRITE     0x02
#define CMD_MEM_READ      0x03
#define CMD_MEM_WRITE     0x04

//============================================================
// DMI Response Structure
//============================================================
struct DMIResponse
{
    uint32_t data;
    uint8_t  resp;
};

//============================================================
// DTM Functions
//============================================================
uint32_t read_dtmcs();
bool dtmcs_test();

//============================================================
// DMI Functions
//============================================================
void select_dmi();

DMIResponse dmi_transfer(uint8_t op,
                         uint8_t address,
                         uint32_t data);

DMIResponse dmi_nop();
DMIResponse dmi_read(uint8_t address);
DMIResponse dmi_write(uint8_t address,
                      uint32_t data);

bool dmi_nop_test();
bool dmstatus_test();

//============================================================
// Debug Control Tests
//============================================================
bool halt_test();
bool resume_test();
bool reset_test();

//============================================================
// AAU Tests
//============================================================
bool data0_test();

// Register Access
bool register_read_x0_test();              // Existing test
bool register_read_test(uint8_t regno);    // Generic register read
bool register_write_test(uint8_t regno,
                         uint32_t value);  // Generic register write

// Program Counter
bool pc_read_test();

// Memory Access
bool memory_read_test(uint32_t addr);
bool memory_write_test(uint32_t addr,
                       uint32_t value);
#endif
