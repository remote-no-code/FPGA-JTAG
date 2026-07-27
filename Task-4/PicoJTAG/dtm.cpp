#include "dtm.h"
#include "jtag.h"

uint32_t read_dtmcs()
{
    goto_shift_ir();
    shift_ir(IR_DTMCS);

    return read_dr32();
}

bool dtmcs_test()
{
    uint32_t dtmcs = read_dtmcs();

    Serial.print("DTMCS = 0x");
    Serial.println(dtmcs, HEX);

    return true;
}

bool dmi_nop_test()
{
    DMIResponse r = dmi_nop();

    Serial.print("DMI RESP = ");
    Serial.println(r.resp);

    Serial.print("DATA = 0x");
    Serial.println(r.data, HEX);

    return (r.resp == 0);
}

DMIResponse dmi_transfer(uint8_t op,
                         uint8_t address,
                         uint32_t data)
{
    uint64_t tx = ((uint64_t)address << 34) |
                  ((uint64_t)data << 2) |
                  op;

    uint64_t rx = transfer_dr41(tx);

    DMIResponse r;

    r.resp = rx & 0x3;
    r.data = (rx >> 2) & 0xffffffff;

    return r;
}
void select_dmi()
{
    goto_shift_ir();
    shift_ir(IR_DMI);
}

DMIResponse dmi_nop()
{
    return dmi_transfer(0, 0, 0);
}

DMIResponse dmi_read(uint8_t address)
{
    dmi_transfer(1, address, 0);   // Issue READ

    dmi_nop();                     // Flush pipeline

    return dmi_nop();              // Actual response
}

bool dmstatus_test()
{
    DMIResponse r = dmi_read(0x11);

    Serial.print("DMSTATUS = 0x");
    Serial.println(r.data, HEX);

    return (r.resp == 0);
}



DMIResponse dmi_write(uint8_t address,
                      uint32_t data)
{
    dmi_transfer(DMI_WRITE, address, data);

    dmi_nop();

    return dmi_nop();
}

bool halt_test()
{
    Serial.println();
    Serial.println("========== HALT TEST ==========");

    DMIResponse before = dmi_read(0x11);

    Serial.print("Before HALT DMSTATUS = 0x");
    Serial.println(before.data, HEX);

    DMIResponse wr = dmi_write(0x10, 0x1);

    Serial.print("WRITE RESP = ");
    Serial.println(wr.resp);

    delay(20);

    DMIResponse after = dmi_read(0x11);

    Serial.print("After HALT DMSTATUS = 0x");
    Serial.println(after.data, HEX);

    if(after.data == 0x1)
    {
        Serial.println("[PASS] HALT");
        return true;
    }

    Serial.println("[FAIL] HALT");

    return false;
}
bool resume_test()
{
    Serial.println();
    Serial.println("========== RESUME TEST ==========");

    dmi_write(0x10, 0x2);

    delay(20);

    DMIResponse r = dmi_read(0x11);

    Serial.print("DMSTATUS = 0x");
    Serial.println(r.data, HEX);

    return (r.data == 0x2);
}

bool reset_test()
{
    Serial.println();
    Serial.println("========== RESET TEST ==========");

    dmi_write(0x10, 0x4);

    delay(20);

    Serial.println("Reset request sent.");

    return true;
}

bool data0_test()
{
    Serial.println();
    Serial.println("========== DATA0 TEST ==========");

    dmi_write(DATA0_ADDR, 0x12345678);

    DMIResponse r = dmi_read(DATA0_ADDR);

    Serial.print("DATA0 = 0x");
    Serial.println(r.data, HEX);

    if(r.data == 0x12345678)
    {
        Serial.println("[PASS] DATA0");
        return true;
    }

    Serial.println("[FAIL] DATA0");
    return false;
}

bool register_read_x0_test()
{
    Serial.println();
    Serial.println("===== REGISTER READ x0 =====");

    // Halt CPU first
    halt_test();

    // COMMAND = reg=0, opcode=1
    uint32_t cmd = (0 << 8) | CMD_REG_READ;

    dmi_write(COMMAND_ADDR, cmd);

    delay(5);

    DMIResponse r = dmi_read(DATA0_ADDR);

    Serial.print("x0 = 0x");
    Serial.println(r.data, HEX);

    return (r.data == 0);
}


bool pc_read_test()
{
    Serial.println();
    Serial.println("========== PC READ TEST ==========");

    // Make sure CPU is halted
    DMIResponse status = dmi_read(DMSTATUS_ADDR);

    if (status.data != 0x1)
    {
        Serial.println("CPU not halted. Halting...");
        halt_test();
    }

    // COMMAND = Register Read, Register = 32 (PC)
    uint32_t cmd = (32 << 8) | CMD_REG_READ;

    DMIResponse wr = dmi_write(COMMAND_ADDR, cmd);

    if (wr.resp != 0)
    {
        Serial.println("[FAIL] COMMAND WRITE");
        return false;
    }



    // Read DATA0
    DMIResponse r = dmi_read(DATA0_ADDR);

    Serial.print("PC = 0x");
    Serial.println(r.data, HEX);

    if (r.resp != 0)
    {
        Serial.println("[FAIL] DMI RESPONSE");
        return false;
    }

    if (r.data == 0)
    {
        Serial.println("[FAIL] PC READ");
        return false;
    }

    Serial.println("[PASS] PC READ");

    return true;
}


bool register_read_test(uint8_t regno)
{
    Serial.println();
    Serial.print("===== REGISTER READ x");
    Serial.print(regno);
    Serial.println(" =====");

    uint32_t cmd = (regno << 8) | CMD_REG_READ;

    dmi_write(COMMAND_ADDR, cmd);
    delay(5);

    DMIResponse r = dmi_read(DATA0_ADDR);

    Serial.print("x");
    Serial.print(regno);
    Serial.print(" = 0x");
    Serial.println(r.data, HEX);

    return (r.resp == 0);
}



bool register_write_test(uint8_t regno, uint32_t value)
{
    Serial.println();

    Serial.print("===== REGISTER WRITE x");
    Serial.print(regno);
    Serial.println(" =====");

    dmi_write(DATA0_ADDR, value);

    uint32_t cmd = (regno << 8) | CMD_REG_WRITE;
    dmi_write(COMMAND_ADDR, cmd);

    delay(5);

    return true;
}

bool memory_read_test(uint32_t addr)
{
    Serial.println();

    Serial.print("===== MEMORY READ 0x");
    Serial.print(addr, HEX);
    Serial.println(" =====");

    dmi_write(DATA0_ADDR, addr);

    uint32_t cmd = CMD_MEM_READ;
    dmi_write(COMMAND_ADDR, cmd);

    delay(5);

    DMIResponse r = dmi_read(DATA0_ADDR);

    Serial.print("MEM = 0x");
    Serial.println(r.data, HEX);

    return (r.resp == 0);
}

bool memory_write_test(uint32_t addr, uint32_t value)
{
    Serial.println();

    Serial.print("===== MEMORY WRITE 0x");
    Serial.print(addr, HEX);
    Serial.println(" =====");

    // DATA0 = address
    dmi_write(DATA0_ADDR, addr);

    // DATA1 = value
    dmi_write(DATA1_ADDR, value);

    // Execute memory write command
    dmi_write(COMMAND_ADDR, CMD_MEM_WRITE);

    delay(5);

    return true;
}
