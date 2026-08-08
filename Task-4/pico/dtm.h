#ifndef DTM_H
#define DTM_H

#include <Arduino.h>

// JTAG instructions
#define IR_IDCODE  0x01
#define IR_DTMCS   0x10
#define IR_DMI     0x11
#define IR_BYPASS  0x1F

// DMI operations
#define DMI_NOP    0x0
#define DMI_READ   0x1
#define DMI_WRITE  0x2

// DMI response values
#define DMI_RESP_SUCCESS  0x0
#define DMI_RESP_RESERVED 0x1
#define DMI_RESP_BUSY     0x2
#define DMI_RESP_ERROR    0x3

// Debug Module register addresses
#define DATA0_ADDR      0x04
#define DATA1_ADDR      0x05
#define DMCONTROL_ADDR  0x10
#define DMSTATUS_ADDR   0x11
#define HARTINFO_ADDR   0x12
#define ABSTRACTCS_ADDR 0x16
#define COMMAND_ADDR    0x17

// Debug register numbers
#define DCSR_REGNO  0x7B0
#define DPC_REGNO   0x7B1

// Expected values from the RTL
#define EXPECTED_DTMCS  0x00000071UL

// dmcontrol values implemented by the RTL
#define DMCONTROL_DMACTIVE  0x00000001UL
#define DMCONTROL_HALTREQ   0x80000000UL
#define DMCONTROL_RESUMEREQ 0x40000000UL
#define DMCONTROL_HARTRESET 0x20000000UL

#define DMI_MAX_RETRIES 40

struct DMIResponse {
    uint32_t data;
    uint8_t resp;
};

// Abstract-command constructors
inline uint32_t make_reg_read_cmd(uint16_t regno) {
    return (0x00UL << 24) |
           (1UL << 22) |
           (0UL << 21) |
           (2UL << 17) |
           regno;
}

inline uint32_t make_reg_write_cmd(uint16_t regno) {
    return (0x00UL << 24) |
           (1UL << 22) |
           (1UL << 21) |
           (2UL << 17) |
           regno;
}

inline uint32_t make_mem_read_cmd() {
    return (0x02UL << 24) |
           (1UL << 22) |
           (2UL << 17);
}

inline uint32_t make_mem_write_cmd() {
    return (0x02UL << 24) |
           (1UL << 22) |
           (1UL << 21) |
           (2UL << 17);
}

// DTM / DMI transport
uint32_t read_dtmcs();
bool dtmcs_test();

void select_dmi();
DMIResponse dmi_transfer(uint8_t op, uint8_t address, uint32_t data);
DMIResponse dmi_nop();
DMIResponse dmi_wait_response();
DMIResponse dmi_read(uint8_t address);
DMIResponse dmi_write(uint8_t address, uint32_t data);

// Task 4 checks
bool dmstatus_running_test();
bool dmstatus_halted_test();

bool halt_test();
bool resume_test();

bool register_write_test(uint16_t regno, uint32_t value);
bool register_read_test(uint16_t regno, uint32_t expected_value);

bool memory_write_test(uint32_t address, uint32_t value);
bool memory_read_test(uint32_t address, uint32_t expected_value);
bool wait_for_running(uint32_t timeout_ms);
bool wait_for_halted(uint32_t timeout_ms);
bool run_task4_hardware_probe();

#endif
