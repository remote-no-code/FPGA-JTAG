# Task 3C: FPGA Hardware Debug Interface using JTAG

## Overview

This project implements a **JTAG-based hardware debug interface** for a custom single-cycle RISC-V processor running on the **VSDSquadron FM FPGA**. The design enables an external controller to inspect processor state and issue basic debug commands over the IEEE 1149.1 JTAG interface.

A **Raspberry Pi Pico** is used as a software-driven JTAG master. It bit-bangs the JTAG signals to communicate with the FPGA, read debug registers, and issue control requests such as halt, resume, and reset.

Unlike simulation-only debugging, this project demonstrates **real hardware control** of the processor. Through JTAG, the design can read the processor Program Counter (PC), observe execution status, and control processor execution in hardware.

To safely bridge the asynchronous JTAG clock domain and the processor clock domain, the design includes a dedicated **Clock Domain Crossing (CDC)** module between the JTAG TAP controller and the RISC-V core.

### Hardware Debug Path

```text
Raspberry Pi Pico
(Bit-Banged JTAG Master)
        │
        ▼
   JTAG Interface
        │
        ▼
JTAG TAP Controller
        │
        ▼
 Clock Domain Crossing
        │
        ▼
 Single-Cycle RISC-V
        │
        ▼
Debug Status / Program Counter
```

---

## Objectives

The primary objectives of this project are to:

- Implement a custom IEEE 1149.1-compatible JTAG TAP controller.
- Read the FPGA identification code (IDCODE) over JTAG.
- Implement debug registers for processor control and observation.
- Safely transfer debug requests from the JTAG clock domain to the processor clock domain using a CDC synchronizer.
- Read the processor Program Counter (PC) through the JTAG interface.
- Halt processor execution using an external JTAG command.
- Resume processor execution after a halt request.
- Reset the processor through the debug interface.
- Verify all debug functionality on real FPGA hardware using a Raspberry Pi Pico as the JTAG master.

---

## Features

| Feature | Description |
| --- | --- |
| IEEE 1149.1 JTAG TAP Controller | Implements the JTAG state machine and register access flow |
| IDCODE Register | Returns the FPGA identification value |
| DEBUG_CTRL Register | Accepts halt, resume, and reset commands |
| DEBUG_STATUS Register | Reports processor execution state |
| DEBUG_PC Register | Reads the current Program Counter |
| JTAG Instruction Register (IR) | Selects the active JTAG instruction |
| JTAG Data Register (DR) | Transfers debug data to and from the FPGA |
| Clock Domain Crossing (CDC) | Safely transfers control pulses between clock domains |
| Processor HALT | Stops processor execution |
| Processor RESUME | Continues processor execution |
| Processor RESET | Restarts the processor |
| Program Counter Readback | Observes processor execution progress |
| Raspberry Pi Pico JTAG Master | Provides a low-cost external JTAG controller |
| Hardware Verification on FPGA | Confirms the design on real hardware |

---

## Project Structure

```text
Task-3C/
├── src/
│   ├── emitter_uart.v
│   ├── riscv.v
│   ├── jtag_tap.v
│   ├── jtag_debug_cdc.v
│   ├── clockworks.v
│   ├── gpio_ctrl_ip.v
│   ├── uart.v
│   ├── timer.v
│   ├── femtopll.v
│   ├── tb_step2.v
│   ├── tb_Step3.v
│   ├── firmware.hex
│   ├── VSDSquadronFM.pcf
│   └── Makefile
├── scripts/
│   ├── pico_halt_resume_reader.ino
│   └── README.md
├── logs/
│   ├── synth.log
│   ├── pnr.log
│   ├── timing.log
│   └── programming.log
├── images/
│   ├── system_architecture.png
│   ├── jtag_tap_controller_architecture.png
│   ├── cdc_architecture.png
│   ├── fpga_bitstream.png
│   ├── wiring.jpg
│   ├── pico_output.png
│   └── hardware_debug_path.png
└── README.md
```

---

## System Architecture

The hardware architecture consists of four main blocks:

1. **Raspberry Pi Pico** acting as a software-based JTAG master.
2. **Custom JTAG TAP Controller** implementing the IEEE 1149.1 state machine and debug registers.
3. **Clock Domain Crossing (CDC)** logic that transfers debug requests between the JTAG clock domain and the processor clock domain.
4. **Single-Cycle RISC-V Processor** with external debug control.

### Hardware Debug Path

<p align="center">
  <img src="images/hardware_debug_path.png" alt="Hardware Debug Path" width="700">
</p>

The Pico communicates with the FPGA exclusively through JTAG. Debug requests are decoded by the TAP controller and synchronized into the processor clock domain before being applied to the CPU.

---

## RTL Design and Hardware Implementation

### Top-Level Hardware Architecture

The FPGA design is integrated through the `SOC` top-level module. It instantiates the processor, memory, peripherals, JTAG debug logic, and the CDC synchronizer.

The architecture keeps the JTAG logic independent from the processor clock. Any command received through JTAG is first synchronized into the processor clock domain before affecting CPU state.

### Major Hardware Blocks

- System-on-Chip (`SOC`)
- Custom JTAG TAP Controller
- JTAG Debug CDC Synchronizer
- Single-Cycle RISC-V Processor
- On-chip Memory
- GPIO Peripheral
- UART Peripheral
- Timer Peripheral

### RTL Hierarchy

```text
                           SOC
                            │
        ┌───────────────────┼────────────────────┐
        │                   │                    │
        ▼                   ▼                    ▼
   JTAG TAP           Debug CDC           RISC-V Processor
        │                   │                    │
        ▼                   ▼                    ▼
  Debug Registers     Synchronizers        Memory Interface
                                                │
                              ┌─────────────────┼────────────────┐
                              ▼                 ▼                ▼
                           Memory             GPIO             UART
                                                │
                                                ▼
                                              Timer
```

---

## JTAG TAP Controller

The JTAG TAP controller implements the IEEE 1149.1 Test Access Port state machine and connects the external JTAG master to the processor debug logic.

### Responsibilities

- Managing the TAP finite state machine
- Shifting instructions into the Instruction Register (IR)
- Shifting data into and out of the Data Register (DR)
- Decoding JTAG instructions
- Accessing debug registers
- Generating processor control requests

### Instruction Set

| Instruction | Opcode | Function |
| --- | :---: | --- |
| IDCODE | `0x1` | Read FPGA identification code |
| DEBUG_CTRL | `0x2` | Write processor debug commands |
| DEBUG_STATUS | `0x3` | Read processor status |
| DEBUG_PC | `0x4` | Read processor Program Counter |
| BYPASS | `0xF` | Select bypass register |

<p align="center">
  <img src="images/jtag_tap_controller_architecture.png" alt="JTAG TAP Controller Architecture" width="700">
</p>

This architecture includes the TAP FSM, Instruction Register, Data Register, instruction decoder, debug registers, and TDO multiplexer.

---

## Debug Register Implementation

Four debug registers are implemented to support processor control and observation.

### IDCODE

The IDCODE register contains the fixed FPGA identification value.

```text
IDCODE = 0x81262776
```

This value allows the external JTAG master to verify communication with the FPGA.

### DEBUG_CTRL

The DEBUG_CTRL register is used to send control commands from the JTAG master to the processor.

| Bit | Function |
| ---: | --- |
| 0 | HALT request |
| 1 | RESUME request |
| 2 | RESET request |
| 31:3 | Reserved |

Supported command values:

| Command | Value |
| --- | --- |
| HALT | `0x00000001` |
| RESUME | `0x00000002` |
| RESET | `0x00000004` |

When the register is updated during the JTAG `UPDATE_DR` state, the TAP controller generates a single-cycle request pulse that is forwarded to the CDC synchronizer.

### DEBUG_STATUS

The DEBUG_STATUS register reports the current processor execution state.

| Value | Meaning |
| --- | --- |
| `0x00000000` | Processor running |
| `0x00000001` | Processor halted |

The least significant bit reflects the processor's `debug_halted` signal.

### DEBUG_PC

The DEBUG_PC register provides read-only access to the current Program Counter.

This allows external software to observe processor execution without modifying CPU state.

Typical behavior:

- While running, consecutive reads return different PC values.
- While halted, consecutive reads return the same PC value.

---

## Clock Domain Crossing (CDC)

The JTAG TAP operates using the external JTAG clock (`TCK`), whereas the processor operates using the FPGA system clock (`CLK`). Because these clocks are asynchronous, the debug requests cannot be connected directly.

To safely transfer control requests, the design inserts a dedicated CDC module (`jtag_debug_cdc.v`) between the TAP controller and the processor.

### CDC Functions

- Synchronizes HALT requests
- Synchronizes RESUME requests
- Synchronizes RESET requests
- Generates single-cycle pulses in the processor clock domain

<p align="center">
  <img src="images/cdc_architecture.png" alt="CDC Architecture" width="700">
</p>

This diagram shows the synchronizer stages and the transfer of request pulses from the JTAG clock domain to the processor clock domain.

---

## Processor Debug Integration

The RISC-V processor includes a dedicated hardware debug interface.

### Added Debug Signals

| Signal | Direction | Description |
| --- | --- | --- |
| `debug_halt_req` | Input | Halt request from CDC |
| `debug_resume_req` | Input | Resume request from CDC |
| `debug_reset_req` | Input | Reset request from CDC |
| `debug_halted` | Output | Indicates processor halted state |
| `debug_pc` | Output | Current Program Counter |

When a HALT request is received, the processor enters a halted state by freezing the execution state machine while preserving the current Program Counter.

When a RESUME request is received, normal instruction execution resumes from the stored Program Counter.

A RESET request reinitializes the processor and restarts execution from the reset vector.

---

## Simulation

Before hardware validation, the design was verified in simulation.

| Testbench | Purpose |
| --- | --- |
| `tb_step2.v` | CPU debug verification |
| `tb_Step3.v` | Complete JTAG + CDC + CPU verification |

Simulation waveforms confirmed correct JTAG state transitions, debug register access, and HALT/RESUME behavior before FPGA deployment.

---

## FPGA Build and Hardware Validation

### FPGA Build Flow

The FPGA design is synthesized, placed, routed, and converted into a configuration bitstream using the open-source IceStorm toolchain.

```text
Verilog Source Files
        │
        ▼
      Yosys
 (Synthesis)
        │
        ▼
    SOC.json
        │
        ▼
 nextpnr-ice40
 (Place & Route)
        │
        ▼
    SOC.asc
        │
        ▼
     icepack
(Bitstream Generation)
        │
        ▼
    SOC.bin
        │
        ▼
     iceprog
 (FPGA Programming)
```

### Generated Files

| File | Description |
| --- | --- |
| `SOC.json` | Synthesized netlist generated by Yosys |
| `SOC.asc` | Place-and-route output generated by nextpnr |
| `SOC.bin` | FPGA configuration bitstream |
| `SOC.timings` | Timing report generated by icetime |

### Build Commands

```bash
make
make timing
make flash
# or
make prog
make clean
```

### Build Logs

The Makefile stores build logs in the `logs/` directory:

```text
logs/
├── synth.log
├── pnr.log
├── timing.log
└── programming.log
```

---

## FPGA Pin Mapping

The FPGA pin assignments are defined in `VSDSquadronFM.pcf`.

| FPGA Signal | Description |
| --- | --- |
| `tck` | JTAG Test Clock |
| `tms` | JTAG Test Mode Select |
| `tdi` | Test Data Input |
| `tdo` | Test Data Output |
| `trst` | TAP Reset |

The processor runs from the onboard FPGA system clock, while the JTAG TAP is driven independently by the external clock supplied from the Raspberry Pi Pico.

### FPGA Bitstream

<p align="center">
  <img src="images/fpga_bitstream.png" alt="FPGA Bitstream" width="700">
</p>

---

## Raspberry Pi Pico Firmware

The Raspberry Pi Pico acts as a software-based JTAG master.

Instead of using dedicated JTAG hardware, the Pico generates JTAG transactions by manually toggling GPIO pins.

The firmware is located at:

```text
scripts/pico_halt_resume_reader.ino
```

### Firmware Helper Functions

| Function | Description |
| --- | --- |
| `tapReset()` | Reset the JTAG TAP controller |
| `loadInstruction()` | Shift a 4-bit JTAG instruction into the Instruction Register |
| `readDR()` | Read a 32-bit Data Register |
| `writeDR()` | Write a 32-bit Data Register |
| `readRegister()` | Read a selected debug register |
| `writeRegister()` | Write to the DEBUG_CTRL register |

### Pico GPIO Connections

| Raspberry Pi Pico | FPGA Signal |
| --- | --- |
| GPIO 5 | TCK |
| GPIO 6 | TMS |
| GPIO 8 | TDI |
| GPIO 10 | TDO |
| GPIO 12 | TRST |
| GND | GND |

All communication uses **3.3 V logic levels**.

**Important:**

- FPGA and Pico must share a common ground.
- Do not use 5 V JTAG signals.

---

## Hardware Test Procedure

After programming the FPGA, the Pico firmware performs the following sequence:

```text
Reset TAP
      │
      ▼
Read IDCODE
      │
      ▼
Read DEBUG_STATUS
      │
      ▼
Read DEBUG_PC
      │
      ▼
Verify CPU Running
      │
      ▼
Send HALT Command
      │
      ▼
Verify STATUS = Halted
      │
      ▼
Verify PC Frozen
      │
      ▼
Send RESUME Command
      │
      ▼
Verify STATUS = Running
      │
      ▼
Verify PC Changes
      │
      ▼
Send RESET Command
      │
      ▼
Verify Processor Restart
```

---

## Validation Method

The design is verified using three independent observations.

### 1. IDCODE Verification

The Pico first reads the FPGA IDCODE.

Expected value:

```text
0x81262776
```

This confirms that the physical JTAG connection and TAP controller are functioning correctly.

### 2. Processor Status Verification

The firmware reads the `DEBUG_STATUS` register before and after issuing HALT and RESUME commands.

| Status Value | Meaning |
| --- | --- |
| `0x00000000` | Processor running |
| `0x00000001` | Processor halted |

### 3. Program Counter Verification

The `DEBUG_PC` register is read multiple times to verify processor execution.

| State | Expected Behavior |
| --- | --- |
| Running | `PC1 ≠ PC2` |
| Halted | `PC1 = PC2` |
| Resumed | `PC1 ≠ PC2` |

This confirms that processor execution stops during HALT and resumes correctly after RESUME.

---

## Experimental Results

The JTAG debug interface was successfully implemented and validated on the VSDSquadron FM FPGA using a Raspberry Pi Pico as the external JTAG master.

The Pico firmware communicated with the custom JTAG TAP controller to perform instruction and data register transactions. The FPGA responded correctly to all supported debug operations, demonstrating stable hardware-level debug control.

### Verified Features

| Feature | Result |
| --- | :---: |
| JTAG Communication | ✅ |
| IDCODE Read | ✅ |
| DEBUG_STATUS Read | ✅ |
| DEBUG_PC Read | ✅ |
| Processor HALT | ✅ |
| Processor RESUME | ✅ |
| Processor RESET | ✅ |
| Program Counter Freeze | ✅ |
| Program Counter Resume | ✅ |

---

## Hardware Verification

### Reading FPGA IDCODE

Observed output:

```text
Reading IDCODE...
IDCODE = 0x81262776
```

The returned value matches the implemented IDCODE register, confirming successful JTAG communication.

### Processor Running Verification

Observed output:

```text
CPU RUN TEST

PC = 0x60
PC = 0x60
PC = 0x68

PASS : CPU Running
```

The changing Program Counter confirms that the processor is executing instructions normally.

### HALT Verification

Observed output:

```text
Sending HALT

STATUS = 0x1

PC Before Halt = 0x70
PC After Halt  = 0x70

PASS : CPU Halted
```

After the HALT command, the processor reports the halted status and the Program Counter stops changing.

### RESUME Verification

Observed output:

```text
Sending RESUME

STATUS = 0x0

PC = 0x68
PC = 0x60
PC = 0x70
PC = 0x6C
PC = 0x64
PC = 0x68
PC = 0x70
```

The Program Counter begins changing again, demonstrating that normal processor execution has resumed.

### RESET Verification

Observed output:

```text
Sending RESET

PC = 0x6C
PC = 0x68
PC = 0x64
PC = 0x60
PC = 0x6C

STATUS = 0x0

PC After Reset = 0x68
```

The processor successfully restarts execution following the RESET request.

### Pico Output

![Pico Output](images/pico_output.png)

---

## Summary of Implemented Debug Features

| Debug Feature | Description |
| --- | --- |
| IDCODE | Reads FPGA identification register |
| DEBUG_STATUS | Reports processor execution state |
| DEBUG_PC | Reads the current Program Counter |
| HALT | Stops processor execution |
| RESUME | Continues processor execution |
| RESET | Restarts the processor |
| CDC Synchronizer | Safely transfers debug requests between clock domains |

---

## Generated Build Files

| File | Description |
| --- | --- |
| `SOC.json` | Synthesized design |
| `SOC.asc` | Place-and-route output |
| `SOC.bin` | FPGA configuration bitstream |
| `SOC.timings` | Timing analysis report |

The Makefile also generates build logs in `logs/`.

---

## Conclusion

This project demonstrates a custom hardware debug interface for a RISC-V processor implemented on the VSDSquadron FM FPGA.

A complete IEEE 1149.1-compatible JTAG TAP controller was developed and integrated with the processor through a dedicated Clock Domain Crossing (CDC) synchronizer. The Raspberry Pi Pico serves as an external JTAG master for real hardware validation.

The implemented debug registers enable external observation and control of processor execution through the JTAG interface. Hardware validation confirmed successful execution of all core debug operations:

- Reading the FPGA IDCODE
- Reading the processor Program Counter
- Reading processor execution status
- Halting processor execution
- Resuming processor execution
- Resetting the processor

The observed hardware behavior matches the intended functionality, confirming correct operation of the JTAG TAP controller, CDC synchronizer, and processor debug logic.

This implementation provides a solid foundation for future enhancements such as hardware breakpoints, single-step execution, and integration with standard debugging tools.
