#include "dtm.h"
#include "jtag.h"
#include "idcode.h"

static bool response_ok(DMIResponse r, const char *operation) {
    if (r.resp == DMI_RESP_SUCCESS)
        return true;

    Serial.print(operation);
    Serial.print(" FAIL: DMI response=");
    Serial.println(r.resp);
    return false;
}

static uint8_t get_cmderr(uint32_t abstractcs) {
    return (abstractcs >> 8) & 0x7;
}

static void clear_cmderr() {
    // W1C bits [10:8]
    DMIResponse r = dmi_write(ABSTRACTCS_ADDR, 0x00000700);

    if (!response_ok(r, "clear cmderr"))
        return;

    delay(2);
}

// DTMCS
uint32_t read_dtmcs() {
    goto_shift_ir();
    shift_ir(IR_DTMCS);
    return read_dr32();
}

bool dtmcs_test() {
    uint32_t value = read_dtmcs();

    if (value != EXPECTED_DTMCS) {
        Serial.print("FAIL, got 0x");
        Serial.println(value, HEX);
        return false;
    }

    Serial.println("PASS");
    return true;
}

// DMI transport
void select_dmi() {
    goto_shift_ir();
    shift_ir(IR_DMI);
}



DMIResponse dmi_transfer(uint8_t op, uint8_t address, uint32_t data) {
    uint64_t tx =
        ((uint64_t)(address & 0x7F) << 34) |
        ((uint64_t)data << 2) |
        ((uint64_t)op & 0x3);

    uint64_t rx = transfer_dr41(tx);

    DMIResponse result;
    result.data = (uint32_t)((rx >> 2) & 0xFFFFFFFFULL);
    result.resp = (uint8_t)(rx & 0x3);

    return result;
}

DMIResponse dmi_nop() {
    return dmi_transfer(DMI_NOP, 0, 0);
}

/*
 * DMI is pipelined:
 * scan request      -> sends READ/WRITE to the debug module
 * first NOP scan    -> allows CDC/DM/DTM response propagation
 * second NOP scan   -> returns the response belonging to the request
 *
 * The first response after reset may be stale success/data=0.
 * Therefore it must never be used as the response to the newly-issued request.
 */
DMIResponse dmi_wait_response() {
    DMIResponse response;

    // Flush the response that was already present before this request.
    dmi_nop();

    // Obtain the response to the preceding READ or WRITE.
    response = dmi_nop();

    // A busy response means the DTM/CDC has not completed yet.
    for (uint8_t i = 0;
         i < DMI_MAX_RETRIES && response.resp == DMI_RESP_BUSY;
         ++i) {
        delayMicroseconds(100);
        response = dmi_nop();
    }

    return response;
}

DMIResponse dmi_read(uint8_t address) {
    DMIResponse ignored;

    // Sends the read request. Its immediate return is the old response.
    ignored = dmi_transfer(DMI_READ, address, 0);
    (void)ignored;

    return dmi_wait_response();
}

DMIResponse dmi_write(uint8_t address, uint32_t data) {
    DMIResponse ignored;

    // Sends the write request. Its immediate return is the old response.
    ignored = dmi_transfer(DMI_WRITE, address, data);
    (void)ignored;

    return dmi_wait_response();
}

// DMSTATUS checks
bool dmstatus_running_test() {
    DMIResponse r = dmi_read(DMSTATUS_ADDR);

    if (r.resp != DMI_RESP_SUCCESS) {
        Serial.println("running FAIL: DMI response error");
        return false;
    }

    bool any_running = (r.data >> 10) & 1U;
    bool all_running = (r.data >> 11) & 1U;
    bool authenticated = (r.data >> 7) & 1U;
    bool version_ok = (r.data & 0xF) == 0x2;

    if (any_running && all_running && authenticated && version_ok) {
        Serial.println("running PASS");
        return true;
    }

    Serial.print("running FAIL, dmstatus=0x");
    Serial.println(r.data, HEX);
    return false;
}

bool dmstatus_halted_test() {
    DMIResponse r = dmi_read(DMSTATUS_ADDR);

    if (r.resp != DMI_RESP_SUCCESS) {
        Serial.println("allhalted FAIL: DMI response error");
        return false;
    }

    bool any_halted = (r.data >> 8) & 1U;
    bool all_halted = (r.data >> 9) & 1U;
    bool any_running = (r.data >> 10) & 1U;
    bool all_running = (r.data >> 11) & 1U;
    bool authenticated = (r.data >> 7) & 1U;
    bool version_ok = (r.data & 0xF) == 0x2;

    if (any_halted && all_halted &&
        !any_running && !all_running &&
        authenticated && version_ok) {
        Serial.println("allhalted PASS");
        return true;
    }

    Serial.print("allhalted FAIL, dmstatus=0x");
    Serial.println(r.data, HEX);
    return false;
}

// dmcontrol
bool halt_test() {
    DMIResponse r = dmi_write(
        DMCONTROL_ADDR,
        DMCONTROL_DMACTIVE | DMCONTROL_HALTREQ
    );

    if (!response_ok(r, "haltreq write"))
        return false;

    delay(5);
    Serial.println("PASS");
    return true;
}

bool resume_test() {
    DMIResponse r = dmi_write(
        DMCONTROL_ADDR,
        DMCONTROL_DMACTIVE | DMCONTROL_RESUMEREQ
    );

    if (!response_ok(r, "resumereq write"))
        return false;

    delay(5);
    Serial.println("PASS");
    return true;
}

static bool abstract_command_ok(const char *operation) {
    DMIResponse r = dmi_read(ABSTRACTCS_ADDR);

    if (!response_ok(r, operation))
        return false;

    Serial.print("ABSTRACTCS = 0x");
    Serial.println(r.data, HEX);

    Serial.print("CMDERR = ");
    Serial.println(get_cmderr(r.data));

    if (get_cmderr(r.data) != 0) {
        Serial.print(operation);
        Serial.print(" FAIL: cmderr=");
        Serial.println(get_cmderr(r.data));
        return false;
    }

    return true;
}

// Abstract register access
bool register_write_test(uint16_t regno, uint32_t value) {
    clear_cmderr();
    DMIResponse r = dmi_write(DATA0_ADDR, value);

    if (!response_ok(r, "DATA0 write"))
        return false;

    r = dmi_write(COMMAND_ADDR, make_reg_write_cmd(regno));

    if (!response_ok(r, "register command write"))
        return false;

    delay(2);

    if (!abstract_command_ok("register write"))
        return false;

    return true;
}

bool register_read_test(uint16_t regno, uint32_t expected_value) {
    clear_cmderr();
    DMIResponse r = dmi_write(COMMAND_ADDR, make_reg_read_cmd(regno));

    if (!response_ok(r, "register command read"))
        return false;

    delay(2);

    if (!abstract_command_ok("register read"))
        return false;

    r = dmi_read(DATA0_ADDR);

    if (!response_ok(r, "DATA0 read"))
        return false;

    if (r.data != expected_value) {
        Serial.print("FAIL: expected 0x");
        Serial.print(expected_value, HEX);
        Serial.print(", got 0x");
        Serial.println(r.data, HEX);
        return false;
    }

    return true;
}

// Abstract memory access
bool memory_write_test(uint32_t address, uint32_t value) {
    clear_cmderr();
    DMIResponse r = dmi_write(DATA0_ADDR, address);

    if (!response_ok(r, "memory address write"))
        return false;

    r = dmi_write(DATA1_ADDR, value);

    if (!response_ok(r, "memory DATA1 write"))
        return false;

    r = dmi_write(COMMAND_ADDR, make_mem_write_cmd());

    if (!response_ok(r, "memory write command"))
        return false;

    delay(2);

    return abstract_command_ok("memory write");
}

bool memory_read_test(uint32_t address, uint32_t expected_value) {
    DMIResponse r = dmi_write(DATA0_ADDR, address);

    if (!response_ok(r, "memory address write"))
        return false;

    r = dmi_write(COMMAND_ADDR, make_mem_read_cmd());

    if (!response_ok(r, "memory read command"))
        return false;

    delay(2);

    if (!abstract_command_ok("memory read"))
        return false;

    r = dmi_read(DATA0_ADDR);

    if (!response_ok(r, "memory DATA0 read"))
        return false;

    if (r.data != expected_value) {
        Serial.print("FAIL: expected 0x");
        Serial.print(expected_value, HEX);
        Serial.print(", got 0x");
        Serial.println(r.data, HEX);
        return false;
    }

    return true;
}

bool wait_for_running(uint32_t timeout_ms) {
    uint32_t start = millis();

    while ((millis() - start) < timeout_ms) {
        DMIResponse r = dmi_read(DMSTATUS_ADDR);

        if (r.resp == DMI_RESP_SUCCESS) {
            bool any_running = (r.data >> 10) & 1U;
            bool all_running = (r.data >> 11) & 1U;
            bool authenticated = (r.data >> 7) & 1U;
            bool version_ok = (r.data & 0xF) == 0x2;

            if (any_running && all_running &&
                authenticated && version_ok) {
                Serial.print("running PASS, dmstatus=0x");
                Serial.println(r.data, HEX);
                return true;
            }
        }

        delay(5);
    }

    Serial.println("running FAIL: timeout");
    return false;
}

bool wait_for_halted(uint32_t timeout_ms) {
    uint32_t start = millis();

    while ((millis() - start) < timeout_ms) {
        DMIResponse r = dmi_read(DMSTATUS_ADDR);

        if (r.resp == DMI_RESP_SUCCESS) {
            bool any_halted = (r.data >> 8) & 1U;
            bool all_halted = (r.data >> 9) & 1U;
            bool any_running = (r.data >> 10) & 1U;
            bool all_running = (r.data >> 11) & 1U;
            bool authenticated = (r.data >> 7) & 1U;
            bool version_ok = (r.data & 0xF) == 0x2;

            if (any_halted && all_halted &&
                !any_running && !all_running &&
                authenticated && version_ok) {
                Serial.print("allhalted PASS, dmstatus=0x");
                Serial.println(r.data, HEX);
                return true;
            }
        }

        delay(5);
    }

    Serial.println("allhalted FAIL: timeout");
    return false;
}

bool run_task4_hardware_probe() {
    bool ok = true;

    tap_reset();

    Serial.println("n_trst = HIGH, TAP reset released");

    Serial.print("Reading IDCODE... ");
    ok &= idcode_test();

    Serial.print("Reading DTMCS at IR 0x10... ");
    ok &= dtmcs_test();

    Serial.println("Selecting DMI at IR 0x11...");
    select_dmi();
    Serial.println("PASS");

    // Make the starting state deterministic.
    // If an earlier run halted the CPU, resume it first.
    Serial.println("Ensuring CPU is running...");

    dmi_write(
        DMCONTROL_ADDR,
        DMCONTROL_DMACTIVE | DMCONTROL_RESUMEREQ
    );

    delay(10);

    Serial.print("Reading dmstatus... ");
    ok &= wait_for_running(500);

    // Halt test
    Serial.print("Writing dmcontrol.haltreq... ");

    ok &= (dmi_write(
        DMCONTROL_ADDR,
        DMCONTROL_DMACTIVE | DMCONTROL_HALTREQ
    ).resp == DMI_RESP_SUCCESS);

    Serial.println(ok ? "PASS" : "FAIL");

    delay(10);

    Serial.print("Reading dmstatus... ");
    ok &= wait_for_halted(500);

    // Clear any earlier abstract-command error.
    Serial.println("Clearing ABSTRACTCS.cmderr...");

    DMIResponse clear_response =
        dmi_write(ABSTRACTCS_ADDR, 0x00000700UL);

    if (clear_response.resp != DMI_RESP_SUCCESS) {
        Serial.println("FAIL: ABSTRACTCS clear");
        ok = false;
    }

    delay(5);

    // Abstract GPR test
    Serial.print("Abstract register access x1... ");

    bool register_ok = true;

    register_ok &= register_write_test(
        0x1001,
        0x12345678UL
    );

    register_ok &= register_read_test(
        0x1001,
        0x12345678UL
    );

    Serial.println(register_ok ? "PASS" : "FAIL");
    ok &= register_ok;

    // Abstract memory test
    Serial.print("Abstract memory access 32-bit word... ");

    bool memory_ok = true;

    memory_ok &= memory_write_test(
        0x00000080UL,
        0x12345678UL
    );

    memory_ok &= memory_read_test(
        0x00000080UL,
        0x12345678UL
    );

    Serial.println(memory_ok ? "PASS" : "FAIL");
    ok &= memory_ok;

    // Resume test
    Serial.print("Writing dmcontrol.resumereq... ");

    bool resume_write_ok =
        dmi_write(
            DMCONTROL_ADDR,
            DMCONTROL_DMACTIVE | DMCONTROL_RESUMEREQ
        ).resp == DMI_RESP_SUCCESS;

    Serial.println(resume_write_ok ? "PASS" : "FAIL");
    ok &= resume_write_ok;

    delay(10);

    Serial.print("Reading dmstatus... ");
    ok &= wait_for_running(500);

    return ok;
}
