#include "jtag.h"
#include "idcode.h"
#include "dtm.h"

void setup()
{
    Serial.begin(115200);

    Serial.println();
    Serial.println("RISC-V JTAG Debug Test");

    jtag_init();
    tap_reset();
}

void loop()
{
    bool pass = true;

    Serial.println();
    Serial.println("==========================================");
    Serial.println("      RISC-V Debug Module Validation");
    Serial.println("==========================================");

    tap_reset();

    //----------------------------------------------------------
    // 1. JTAG Interface
    //----------------------------------------------------------
    Serial.println("\n[1] JTAG INTERFACE");

    pass &= idcode_test();
    pass &= dtmcs_test();

    //----------------------------------------------------------
    // 2. DMI Interface
    //----------------------------------------------------------
    Serial.println("\n[2] DMI INTERFACE");

    select_dmi();

    pass &= dmi_nop_test();
    pass &= dmstatus_test();

    //----------------------------------------------------------
    // 3. Debug Control
    //----------------------------------------------------------
    Serial.println("\n[3] DEBUG CONTROL");

    pass &= halt_test();
    pass &= resume_test();
    pass &= reset_test();

    //----------------------------------------------------------
    // 4. Abstract Data Registers
    //----------------------------------------------------------
    Serial.println("\n[4] ABSTRACT DATA REGISTERS");

    pass &= data0_test();

    //----------------------------------------------------------
    // 5. Register Access
    //----------------------------------------------------------
    Serial.println("\n[5] REGISTER ACCESS");

    pass &= register_read_x0_test();
    pass &= pc_read_test();

    Serial.println("\nReading all 32 GPRs");

    for (int i = 0; i < 32; i++)
        pass &= register_read_test(i);

    Serial.println("\nRegister Write Verification");

    pass &= register_write_test(5,  0x07102006);
    pass &= register_read_test(5);

    pass &= register_write_test(10, 0xCAFEBABE);
    pass &= register_read_test(10);

    pass &= register_write_test(20, 0xDEADBEEF);
    pass &= register_read_test(20);

    pass &= register_write_test(31, 0x87654321);
    pass &= register_read_test(31);

    //----------------------------------------------------------
    // 6. Memory Access
    //----------------------------------------------------------
    Serial.println("\n[6] MEMORY ACCESS");

    pass &= memory_write_test(0x100, 0x11223344);
    pass &= memory_read_test(0x100);

    pass &= memory_write_test(0x104, 0x55667788);
    pass &= memory_read_test(0x104);

    //----------------------------------------------------------
    // Final Report
    //----------------------------------------------------------
    Serial.println();
    Serial.println("==========================================");

    if (pass)
        Serial.println("ALL DEBUG MODULE TESTS PASSED");
    else
        Serial.println("DEBUG MODULE TEST FAILED");

    Serial.println("==========================================");

    delay(1000);
}