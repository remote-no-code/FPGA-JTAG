#include "jtag.h"

// JTAG Pins
#define TCK   5
#define TMS   6
#define TDI   8
#define TDO   10
#define TRST  12

void jtag_init()
{
    pinMode(TCK, OUTPUT);
    pinMode(TMS, OUTPUT);
    pinMode(TDI, OUTPUT);
    pinMode(TDO, INPUT);
    pinMode(TRST, OUTPUT);

    digitalWrite(TCK, LOW);
    digitalWrite(TMS, HIGH);
    digitalWrite(TDI, LOW);
    digitalWrite(TRST, HIGH);

    delay(100);
}

inline void tck_cycle()
{
    digitalWrite(TCK, LOW);
    delayMicroseconds(2);

    digitalWrite(TCK, HIGH);
    delayMicroseconds(2);

    digitalWrite(TCK, LOW);
    delayMicroseconds(2);
}

void jtag_write(bool tms, bool tdi)
{
    digitalWrite(TMS, tms);
    digitalWrite(TDI, tdi);

    // Rising edge clocks FPGA
    digitalWrite(TCK, HIGH);
    delayMicroseconds(2);

    // Return low
    digitalWrite(TCK, LOW);
    delayMicroseconds(2);
}

int jtag_read(bool tms, bool tdi)
{
    digitalWrite(TMS, tms);
    digitalWrite(TDI, tdi);

    // Rising edge
    digitalWrite(TCK, HIGH);
    delayMicroseconds(2);

    // Falling edge
    digitalWrite(TCK, LOW);
    delayMicroseconds(2);

    delayMicroseconds(2);

    return digitalRead(TDO);
}

void tap_reset()
{
    // Assert nTRST
    digitalWrite(TRST, LOW);
    digitalWrite(TMS, HIGH);
    digitalWrite(TDI, LOW);

    for (int i = 0; i < 6; i++)
    {
        digitalWrite(TCK, HIGH);
        delayMicroseconds(2);

        digitalWrite(TCK, LOW);
        delayMicroseconds(2);
    }

    // Release nTRST
    digitalWrite(TRST, HIGH);
    delayMicroseconds(5);

    // Enter Run-Test/Idle
    digitalWrite(TMS, LOW);

    digitalWrite(TCK, HIGH);
    delayMicroseconds(2);

    digitalWrite(TCK, LOW);
    delayMicroseconds(2);
}

void goto_shift_ir()
{
    jtag_write(1,0);   // Select-DR
    jtag_write(1,0);   // Select-IR
    jtag_write(0,0);   // Capture-IR
    jtag_write(0,0);   // Shift-IR
}

void goto_shift_dr()
{
    jtag_write(1,0);   // Select-DR
    jtag_write(0,0);   // Capture-DR
    jtag_write(0,0);   // Shift-DR
}

void shift_ir(uint8_t ir)
{
    for(int i = 0; i < 5; i++)
    {
        bool last = (i == 4);

        jtag_read(last, (ir >> i) & 1);
    }

    jtag_write(1,0);   // Update-IR
    jtag_write(0,0);   // Run-Test/Idle
}

uint32_t read_dr32()
{
    uint32_t value = 0;

    goto_shift_dr();

    for(int i = 0; i < 32; i++)
    {
        bool last = (i == 31);

        int bit = jtag_read(last, 0);

        value |= ((uint32_t)bit << i);
    }

    jtag_write(1,0);   // Update-DR
    jtag_write(0,0);   // Run-Test/Idle

    return value;
}
uint64_t transfer_dr41(uint64_t value)
{
    uint64_t result = 0;

    goto_shift_dr();

    for(int i = 0; i < 41; i++)
    {
        bool last = (i == 40);

        int bit = jtag_read(last, (value >> i) & 1ULL);

        result |= ((uint64_t)bit << i);
    }

    jtag_write(1,0);
    jtag_write(0,0);

    return result;
}
