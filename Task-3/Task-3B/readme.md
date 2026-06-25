# Task 3B – JTAG Debug Clock Domain Crossing (CDC)

> **Implementation and verification of a toggle-based two-flip-flop synchronizer for safely transferring JTAG debug requests between asynchronous clock domains using Verilog HDL.**

---

# 1. Overview

This project implements a **Clock Domain Crossing (CDC)** mechanism for a JTAG debug interface. The objective is to safely transfer asynchronous debug requests generated in the **JTAG clock domain (TCK)** into the **processor clock domain (CLK)** without introducing metastability or losing short debug pulses.

A **toggle-based synchronization technique** combined with a **two-stage flip-flop synchronizer** is used to reliably transfer three debug commands:

* HALT
* RESUME
* RESET

The design is implemented in **Verilog HDL** and functionally verified using **Icarus Verilog** and **GTKWave**.

---

# 2. Objectives

* Implement a reliable Clock Domain Crossing (CDC) mechanism.
* Synchronize JTAG debug requests across asynchronous clock domains.
* Generate single-clock pulses in the processor clock domain.
* Verify HALT, RESUME, and RESET operations.
* Demonstrate correct processor behavior through simulation.

---

# 3. Repository Structure

```text
Task3B/
├──  src/
│   ├── jtag_debug_cdc.v          # CDC implementation
│   └── tb_jtag_debug_cdc.v       # Self-checking testbench
│
├── README.md
│
└── images/
    ├── 01_CDC_Architecture.png
    ├── 02_halt_sync.png
    ├── 03_resume_sync.png
    ├── 04_reset_sync.png
    ├── 05_logsA.png
    └── 06_logsB.png
```

---

# 4. Clock Domain Crossing (CDC)

Digital systems often contain multiple clock domains operating at different frequencies. Signals crossing between these domains may violate setup and hold timing requirements, leading to **metastability** or loss of short pulses.

To overcome this issue, this implementation uses a **toggle-based synchronization scheme**. Instead of transferring a narrow pulse directly, the request toggles a register in the JTAG clock domain. This toggle is synchronized into the processor clock domain using a **two-flip-flop synchronizer**, after which an **edge detector** regenerates a single-clock pulse for the processor.

This technique provides reliable event transfer while significantly reducing the probability of metastability propagating into downstream logic.

---

# 5. System Architecture

> **Figure 1 – JTAG Debug Clock Domain Crossing Architecture**

*![CDC Architecture](images/CDC_Architecture.png)*

### Architecture Description

The architecture consists of three functional regions:

### **JTAG Clock Domain (TCK)**

The JTAG TAP Controller decodes debug instructions and generates three asynchronous debug requests:

* `debug_halt_req_tck`
* `debug_resume_req_tck`
* `debug_reset_req_tck`

### **Clock Domain Crossing Logic**

Each request passes through three stages:

**Toggle Generation**

* Converts each debug request into a persistent toggle event.

**Two-Flip-Flop Synchronizer**

* Safely transfers the toggle into the processor clock domain.
* Reduces the probability of metastability.

**Edge Detector**

* Detects synchronized toggle transitions.
* Generates a single-clock pulse.

### **Processor Clock Domain (CLK)**

The synchronized debug pulses control the processor model:

* HALT stops program execution.
* RESUME restarts execution.
* RESET clears the Program Counter.

---

# 6. Implementation

## CDC Module

The `jtag_debug_cdc.v` module implements:

* Toggle generation
* Two-stage synchronizers
* Edge detection
* Synchronized HALT, RESUME and RESET outputs

The module is fully synchronous in the processor clock domain after synchronization.

---

## Testbench

The testbench models:

* Independent JTAG and processor clocks
* A simple processor model
* Program Counter behaviour
* HALT
* RESUME
* RESET verification

Clock configuration:

| Signal | Period |
| ------ | ------ |
| TCK    | 100 ns |
| CLK    | 20 ns  |

---

# 7. Verification Methodology

The design is verified through three independent test scenarios.

---

## HALT Synchronization

> **Figure 2 – HALT Request Synchronization**

*![HALT Synchronization](images/halt_sync.png)*

Verification steps:

1. HALT request generated in TCK domain.
2. Toggle created.
3. Toggle synchronized using two flip-flops.
4. Edge detector generates a single-cycle pulse.
5. Processor enters HALT state.
6. Program Counter stops incrementing.

---

## RESUME Synchronization

> **Figure 3 – RESUME Request Synchronization**

*![Resume Synchronization](images/resume_sync.png)*

Verification steps:

1. RESUME request generated.
2. Toggle synchronized.
3. Pulse regenerated.
4. Processor resumes execution.
5. Program Counter continues incrementing.

---

## RESET Synchronization

> **Figure 4 – RESET Request Synchronization**

*![Reset Synchronization](images/reset_sync.png)*

Verification steps:

1. RESET request generated.
2. Toggle synchronized.
3. Pulse regenerated.
4. Processor reset.
5. Program Counter cleared.

---

# 8. Simulation Execution

Simulation commands:

```bash
iverilog -o sim jtag_debug_cdc.v tb_jtag_debug_cdc.v

vvp sim
```

---

# 9. Terminal Output

> **Figure 5 – Verification Log**

*![LOG A](images/logsA.png)*

*![LOG B](images/logsB.png)*

The verification log confirms:

* Processor initialization
* HALT synchronization
* RESUME synchronization
* RESET synchronization
* Successful completion of all verification steps

---

# 10. Results Summary

| Verification Item           
| ---------------------------- 
| Independent Clock Domains    |
| Toggle Generation            |
| Two-Flip-Flop Synchronizer   |
| Edge Detection               |
| HALT Synchronization         |
| RESUME Synchronization       |
| RESET Synchronization        |
| Program Counter Verification |
| Simulation Passed            |

---

# 11. Conclusion

A complete **JTAG Debug Clock Domain Crossing (CDC)** mechanism was successfully designed and verified using Verilog HDL. The implementation employs a toggle-based synchronization technique together with a two-flip-flop synchronizer to safely transfer asynchronous debug requests between independent clock domains. Simulation results confirm the reliable synchronization of HALT, RESUME, and RESET requests while maintaining correct processor behavior, demonstrating an effective solution for CDC in JTAG-based debug systems.

---


