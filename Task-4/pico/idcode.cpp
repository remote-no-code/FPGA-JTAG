#include "idcode.h"
#include "jtag.h"
#include "dtm.h"

uint32_t read_idcode()
{
    goto_shift_ir();
    shift_ir(IR_IDCODE);

    return read_dr32();
}

bool idcode_test()
{
    uint32_t id = read_idcode();

    Serial.print("IDCODE = 0x");
    Serial.println(id, HEX);

    if(id == 0x81262776)
    {
        Serial.println("[PASS] IDCODE");
        return true;
    }
    else
    {
        Serial.println("[FAIL] IDCODE");
        return false;
    }
}
