# Pico JTAG HALT/RESUME Firmware

## Overview

This firmware turns the Raspberry Pi Pico into a simple bit-banged JTAG master for the FPGA.

It communicates with the custom JTAG TAP implemented on the FPGA and demonstrates hardware debug functionality by reading debug registers and sending control commands to the RISC-V processor.

The firmware was developed for **Task 3C: FPGA HALT/RESUME Hardware Proof**.

---

## Features

The firmware supports the following operations:

- Reset the JTAG TAP
- Read FPGA IDCODE
- Read DEBUG_STATUS register
- Read DEBUG_PC register
- Send HALT command
- Send RESUME command
- Send RESET command
- Verify processor execution by monitoring the Program Counter (PC)

---

## JTAG Pin Connections

| Pico GPIO | FPGA Signal |
|-----------|-------------|
| GPIO 5 | TCK |
| GPIO 6 | TMS |
| GPIO 8 | TDI |
| GPIO 10 | TDO |
| GPIO 12 | TRST |
| GND | GND |

The interface operates at **3.3V logic levels**.

---

## JTAG Instructions

The firmware uses the following JTAG instruction encodings:

| Instruction | Value | Description |
|-------------|-------|-------------|
| IDCODE | 0x1 | Read FPGA identification code |
| DEBUG_CTRL | 0x2 | Write debug control commands |
| DEBUG_STATUS | 0x3 | Read processor status |
| DEBUG_PC | 0x4 | Read processor program counter |

---

## DEBUG_CTRL Commands

The DEBUG_CTRL register uses the following command bits:

| Bit | Function |
|-----|----------|
| Bit 0 | HALT request |
| Bit 1 | RESUME request |
| Bit 2 | RESET request |

Examples:

```
HALT   = 0x00000001
RESUME = 0x00000002
RESET  = 0x00000004
```

---

## Firmware Operation

The firmware performs the following sequence:

1. Reset the JTAG TAP.
2. Read the FPGA IDCODE.
3. Read the initial processor status.
4. Read the current Program Counter (PC).
5. Verify that the processor is executing by observing changes in the PC.
6. Send a HALT request.
7. Verify that the processor enters the halted state.
8. Read the PC twice and confirm it remains unchanged.
9. Send a RESUME request.
10. Verify that the processor resumes execution by observing changes in the PC.
11. Send a RESET request.
12. Verify that the processor restarts execution.

---

## Terminal Output

A successful execution produces output similar to:

```
Reading IDCODE...
IDCODE = 0x81262776

Reading DEBUG_STATUS...
STATUS = 0x0

Reading DEBUG_PC...
PC = 0x68

CPU RUN TEST
PASS : CPU Running

Sending HALT
STATUS = 0x1
PASS : CPU Halted

Sending RESUME
STATUS = 0x0

Sending RESET

TASK 3C STEP 2 COMPLETE
```

---

## JTAG Helper Functions

The firmware is organized into reusable helper functions:

- `tapReset()`  
  Resets the TAP controller into the Test-Logic-Reset state.

- `loadInstruction()`  
  Loads a 4-bit instruction into the Instruction Register (IR).

- `readDR()`  
  Reads a 32-bit Data Register from the FPGA.

- `writeDR()`  
  Writes a 32-bit Data Register to the FPGA.

- `readRegister()`  
  Convenience function that loads an instruction and reads its associated register.

- `writeRegister()`  
  Convenience function that loads an instruction and writes data to its associated register.

---

## Notes

- JTAG communication is implemented entirely in software using GPIO bit-banging.
- Instructions and data are shifted **LSB first**.
- The firmware is intended for hardware verification and debugging of the custom JTAG interface implemented on the FPGA.
