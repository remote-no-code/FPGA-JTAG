# 1. Introduction

Debugging is an essential capability in modern System-on-Chip (SoC) development, enabling software development, hardware verification, post-silicon validation, and system bring-up. As the complexity of RISC-V based processors continues to grow, a standardized debug infrastructure becomes increasingly important to ensure interoperability between processor implementations and external debugging tools.

The **RISC-V External Debug Specification** defines a standardized architecture for accessing and controlling a processor through a **JTAG Debug Transport Module (DTM)**, **Debug Module Interface (DMI)**, and **Debug Module (DM)**. This standardized approach enables compatibility with widely used debugging environments such as **OpenOCD**, **Ashling**, and other RISC-V compliant debug adapters without relying on proprietary protocols.

This project implements a **minimal RISC-V Debug Specification aligned debug subsystem** for a custom RISC-V processor running on the **VSDSquadron FM FPGA development board (Lattice iCE40UP5K-SG48)**. The implementation replaces a previously developed custom JTAG proof-of-concept with a standards-oriented debug architecture while remaining lightweight enough to operate within the resource constraints of the target FPGA.

The implemented architecture consists of the following major components:

- **JTAG Debug Transport Module (DTM)**
- **Debug Module Interface (DMI)**
- **Minimal RISC-V Debug Module (DM)**
- **Core Debug Adapter**
- **Abstract Access Unit (AAU)**

Together, these modules provide a complete debug communication path capable of:

- Reading the JTAG **IDCODE**
- Accessing **DTMCS**
- Performing **DMI transactions**
- Controlling processor execution using **HALT** and **RESUME** requests
- Performing **Abstract Register Access**
- Performing **Abstract Memory Access**
- Supporting active-low **nTRST** behavior as required by the RISC-V Debug Specification

Unlike the earlier proof-of-concept implementation, the external debug interface presented in this project no longer exposes proprietary JTAG instructions for processor control. Instead, all processor debug operations are performed through the standard RISC-V Debug Module architecture, providing a cleaner separation between the transport layer and processor-specific debug functionality.

The complete design has been implemented, simulated, synthesized, and validated on the **VSDSquadron FM FPGA** using the open-source FPGA toolchain consisting of **Yosys**, **nextpnr-ice40**, **Project IceStorm**, and **iceprog**. Hardware validation was performed using a **Raspberry Pi Pico** operating as a JTAG adapter, demonstrating successful communication through the complete debug path from the external probe to the processor.

This repository documents the complete architecture, RTL implementation, simulation methodology, FPGA implementation flow, hardware validation, and design decisions involved in developing a lightweight, standards-oriented RISC-V debug infrastructure suitable for resource-constrained FPGA platforms.

# 2. Objectives

The primary objective of this project is to replace a custom JTAG-based debug proof-of-concept with a **RISC-V Debug Specification aligned debug infrastructure** for a custom RISC-V processor implemented on the **VSDSquadron FM (Lattice iCE40UP5K)** FPGA platform.

The implementation is designed to provide a lightweight, standards-oriented debug path while remaining compatible with the resource limitations of the target FPGA and following the architectural principles defined in the RISC-V External Debug Specification.

---

## Primary Objectives

- Replace the proprietary JTAG debug protocol developed during the previous proof-of-concept with a standards-oriented RISC-V debug implementation.
- Implement a **5-bit JTAG Debug Transport Module (DTM)** supporting the mandatory **IDCODE**, **DTMCS**, **DMI**, and **BYPASS** instructions.
- Design and integrate a **Debug Module Interface (DMI)** capable of handling standard debug transactions between the transport layer and the Debug Module.
- Develop a **Minimal RISC-V Debug Module (DM)** supporting single-hart operation through standard debug registers.
- Implement a **Core Debug Adapter** to translate Debug Module requests into processor debug control signals.
- Support **Abstract Register Access** for reading and writing General Purpose Registers (GPRs).
- Support **Abstract Memory Access** for reading and writing aligned 32-bit memory locations.
- Implement active-low **nTRST** handling as specified by the RISC-V Debug Specification.
- Validate the complete debug path through simulation and FPGA hardware implementation.

---

## Functional Objectives

The completed implementation shall provide the following functionality:

- Read the processor **IDCODE** through the JTAG interface.
- Read the **DTM Control and Status Register (DTMCS)**.
- Perform standard **DMI read and write transactions**.
- Control processor execution using **HALT** and **RESUME** requests.
- Report processor execution state through **DMSTATUS**.
- Execute abstract register access commands while the processor is halted.
- Execute abstract memory access commands for aligned 32-bit memory transactions.
- Maintain compatibility with standard RISC-V debug communication flows without exposing proprietary external debug instructions.

---

## Design Constraints

To ensure compatibility with the target platform and project requirements, the implementation follows the following constraints:

- Target FPGA: **Lattice iCE40UP5K-SG48 (VSDSquadron FM)**
- Single-hart debug architecture
- Resource-conscious RTL implementation suitable for low-density FPGA devices
- 3.3 V JTAG signaling
- Active-low **nTRST** support
- Open-source FPGA toolchain (Yosys, nextpnr-ice40, Project IceStorm, iceprog)

The following features are intentionally excluded from this implementation:

- Program Buffer
- System Bus Access (SBA)
- Hardware Breakpoints / Trigger Module
- Single-Step Debugging
- Full OpenOCD Integration
- Full GDB Source-Level Debugging

---

## Validation Objectives

The implementation is considered complete after successfully demonstrating:

- Successful JTAG communication through the Debug Transport Module.
- Correct DMI request and response handling.
- Functional **DMCONTROL** and **DMSTATUS** registers.
- Successful processor **HALT** and **RESUME** operations.
- Correct abstract register access.
- Correct abstract memory access.
- Verification of active-low **nTRST** behavior.
- Successful FPGA synthesis, implementation, and programming on the VSDSquadron FM development board.
- End-to-end hardware validation using a Raspberry Pi Pico acting as the JTAG adapter.

# 3. System Overview

The implemented debug infrastructure follows the standard RISC-V external debug architecture by separating the communication transport layer from the processor-specific debug logic. The design provides a complete path from an external JTAG probe to the processor's debug interface while maintaining a modular architecture that simplifies integration, verification, and future feature expansion.

Unlike the proof-of-concept implementation developed during Task 3C, where processor control was achieved using custom JTAG instructions, this implementation routes all debug operations through a standard **Debug Transport Module (DTM)**, **Debug Module Interface (DMI)**, and **Debug Module (DM)**. This modular approach aligns with the RISC-V External Debug Specification and establishes a foundation for interoperability with standard RISC-V debug tools.

---

## System Architecture

<p align="center">
  <img src="docs/images/riscv_debug_architecture.png" alt="RISC-V Debug Architecture" width="900"/>
</p>

<p align="center">
<b>Figure 1.</b> Overall RISC-V Debug Architecture
</p>

The implemented debug subsystem consists of six primary functional blocks:

| Component | Description |
|-----------|-------------|
| **External Debug Probe** | Raspberry Pi Pico configured as a JTAG master for issuing standard RISC-V debug commands. |
| **JTAG Debug Transport Module (DTM)** | Implements the IEEE 1149.1 TAP controller and decodes the standard RISC-V JTAG instructions (IDCODE, DTMCS, DMI and BYPASS). |
| **Debug Module Interface (DMI)** | Provides the transaction interface between the transport layer and the Debug Module, handling read/write requests and response generation. |
| **Debug Module (DM)** | Implements the standard debug registers, processor control logic, and command execution engine. |
| **Core Debug Adapter** | Converts Debug Module requests into processor-specific debug control signals such as halt, resume and reset while monitoring processor execution status. |
| **Abstract Access Unit (AAU)** | Performs register and memory accesses on behalf of the Debug Module without requiring System Bus Access or a Program Buffer. |

---

## Operational Flow

The debug communication follows the sequence illustrated below:

```
External Debug Probe
        │
        ▼
JTAG Interface
        │
        ▼
Debug Transport Module (DTM)
        │
        ▼
Debug Module Interface (DMI)
        │
        ▼
Minimal Debug Module (DM)
        │
        ▼
Core Debug Adapter
        │
        ▼
Abstract Access Unit
        │
        ▼
RISC-V Processor
```

Each debug request generated by the external probe traverses the transport layer before reaching the Debug Module. Depending on the requested operation, the Debug Module either controls processor execution (halt, resume, reset) or delegates register and memory operations to the Abstract Access Unit. The resulting status or data is returned through the same communication path back to the external debugger.

---

## Design Principles

The implementation was developed according to the following engineering principles:

- **Standards Compliance** — Implements the mandatory components of the RISC-V External Debug Specification required for Task 4.
- **Modular Design** — Separates transport, protocol, debug control, and processor-specific functionality into independent RTL modules.
- **Resource Efficiency** — Optimized for the Lattice iCE40UP5K FPGA while maintaining functional completeness.
- **Scalability** — The modular architecture allows future addition of Program Buffer, System Bus Access, trigger modules, and multi-hart support without significant redesign.
- **Maintainability** — Clearly defined module interfaces simplify verification, debugging, and future enhancements.

---

## Key Capabilities

The implemented debug infrastructure provides the following capabilities:

- Standard JTAG Debug Transport Module with a 5-bit Instruction Register.
- Support for the mandatory JTAG instructions:
  - IDCODE
  - DTMCS
  - DMI
  - BYPASS
- Standard Debug Module Interface transactions.
- Processor execution control through **HALT**, **RESUME**, and optional **NDMRESET**.
- Abstract Register Access for General Purpose Registers (GPRs).
- Abstract Memory Access for aligned 32-bit memory transactions.
- Active-low **nTRST** support for TAP reset.
- FPGA implementation and hardware validation on the VSDSquadron FM platform.

The following chapters describe each subsystem in detail, including its architecture, implementation, verification methodology, and hardware validation results.

# 4. Repository Structure

The repository is organized to separate the RTL implementation, simulation environment, FPGA build flow, hardware validation, and supporting documentation. This modular organization improves maintainability, simplifies navigation, and allows each stage of the development flow to be reproduced independently.

```text
Task-4/
│
├── README.md                           # Project overview and documentation
│
├── rtl/                                # RTL source files
│   ├── riscv_jtag_dtm.v
│   ├── dmi_interface.v
│   ├── riscv_debug_module_minimal.v
│   ├── core_debug_adapter.v
│   ├── abstract_access_unit.v
│   └── top_riscv_debug_spec_fm.v
│
├── sim/                                # Simulation environment
│   ├── tb_soc_debug.v
│   ├── waveforms/
│   └── logs/
│
├── fpga/                               # FPGA implementation files
│   ├── Makefile
│   ├── VSDSquadronFM_debug_spec.pcf
│   ├── build/
│   └── bitstream/
│
├── scripts/                            # JTAG host utilities
│   └── pico_standard_dmi_probe.*
│
├── docs/                               # Supporting documentation
│   ├── images/
│   ├── hardware_setup/
│   ├── architecture/
│   └── references/
│
├── results/                            # Validation results
│   ├── simulation_logs/
│   ├── synthesis_logs/
│   ├── timing_reports/
│   └── hardware_logs/
│
└── LICENSE
```

---

## Directory Description

### `rtl/`

Contains the complete Register Transfer Level (RTL) implementation of the RISC-V debug subsystem. Each module performs a specific function within the overall debug architecture, ranging from JTAG communication to processor control and abstract access operations.

---

### `sim/`

Contains the simulation environment used to functionally verify the complete debug path. This includes the top-level verification testbench, waveform files, and simulation logs used during development.

---

### `fpga/`

Contains all files required to synthesize, place, route, and program the VSDSquadron FM FPGA. The directory includes the FPGA constraint file, build scripts, generated bitstreams, and implementation artifacts.

---

### `scripts/`

Contains host-side utilities used to communicate with the FPGA during hardware validation. In this project, a Raspberry Pi Pico is used as the JTAG master to issue standard DMI transactions and verify debug functionality.

---

### `docs/`

Stores supporting documentation, architectural diagrams, hardware photographs, and additional reference material used throughout the project. These assets are referenced throughout this README to improve readability while keeping the repository organized.

---

### `results/`

Contains the outputs generated during verification and implementation, including simulation logs, synthesis reports, timing analysis, and hardware validation logs. These artifacts provide evidence of successful implementation and FPGA validation.

---

## Development Flow

The repository follows a structured hardware development workflow, progressing from RTL design through simulation, FPGA implementation, and hardware validation.

```
RTL Design
     │
     ▼
Functional Simulation
     │
     ▼
Waveform Verification
     │
     ▼
FPGA Synthesis
     │
     ▼
Place & Route
     │
     ▼
Bitstream Generation
     │
     ▼
FPGA Programming
     │
     ▼
Hardware Validation
     │
     ▼
Result Documentation
```

This workflow ensures that every modification is verified through simulation before being synthesized for FPGA implementation, enabling systematic debugging and repeatable hardware validation.

# 5. Design Methodology

The implementation presented in this repository follows a modular and standards-oriented design methodology based on the **RISC-V External Debug Specification**. Rather than extending the custom JTAG protocol developed during the earlier proof-of-concept, the entire debug path was redesigned to separate transport, protocol, processor control, and abstract access into independent functional blocks.

This modular approach improves readability, maintainability, verification, and future scalability while remaining suitable for implementation on the resource-constrained **Lattice iCE40UP5K FPGA**.

---

## Design Philosophy

The development of the debug subsystem was guided by the following engineering principles:

- **Standards Compliance** – Follow the RISC-V External Debug Specification wherever applicable within the scope of Task 4.
- **Modularity** – Separate each functional layer into an independent RTL module with clearly defined interfaces.
- **Resource Efficiency** – Minimize FPGA resource utilization while preserving essential debugging functionality.
- **Scalability** – Allow future integration of advanced debug features without requiring major architectural changes.
- **Maintainability** – Keep each RTL module focused on a single responsibility to simplify debugging and future development.

---

## Layered Architecture

Instead of directly connecting JTAG commands to processor control signals, the implementation follows a layered architecture in which each module performs a dedicated task.

```
External Debug Probe
          │
          ▼
JTAG Debug Transport Module (DTM)
          │
          ▼
Debug Module Interface (DMI)
          │
          ▼
Debug Module (DM)
          │
          ▼
Core Debug Adapter
          │
          ▼
Abstract Access Unit (AAU)
          │
          ▼
RISC-V Processor
```

Each layer communicates only with its adjacent modules, resulting in a clean and maintainable architecture.

---

## Modular Design

The complete implementation is divided into six primary RTL modules.

| Module | Responsibility |
|---------|----------------|
| **riscv_jtag_dtm.v** | Implements the IEEE 1149.1 TAP Controller, Instruction Register, Data Registers, IDCODE, DTMCS, DMI and BYPASS instructions. |
| **dmi_interface.v** | Converts DTM requests into DMI transactions and returns responses to the transport layer. |
| **riscv_debug_module_minimal.v** | Implements the Debug Module registers and executes debug commands received through DMI. |
| **core_debug_adapter.v** | Translates Debug Module requests into processor-specific halt, resume, reset and status signals. |
| **abstract_access_unit.v** | Executes register and memory access commands on behalf of the Debug Module. |
| **top_riscv_debug_spec_fm.v** | Integrates all modules into the complete FPGA design. |

This modular organization allows each block to be developed, simulated, and verified independently before system integration.

---

## Debug Communication Flow

The external debugger communicates with the processor using a layered request-response mechanism.

1. The external JTAG adapter shifts instructions and data through the TAP controller.
2. The Debug Transport Module decodes the selected instruction.
3. DMI transactions are generated and forwarded to the Debug Module.
4. The Debug Module interprets the request and issues the corresponding processor command.
5. The Core Debug Adapter converts generic debug requests into processor-specific control signals.
6. The Abstract Access Unit performs register or memory operations when required.
7. The response is propagated back through the DMI and DTM to the external debugger.

This separation ensures that processor-specific functionality remains isolated from the transport protocol.

---

## Processor Debug Strategy

The processor can exist in one of two execution states:

- **Running**
- **Halted**

Processor execution is controlled exclusively through the Debug Module using standard **DMCONTROL** requests.

While the processor is halted, the Abstract Access Unit provides controlled access to:

- General Purpose Registers (GPRs)
- 32-bit aligned memory locations

Normal program execution resumes only after a valid **RESUME** request is received.

---

## FPGA-Oriented Design Considerations

Since the target platform is the **VSDSquadron FM** based on the **Lattice iCE40UP5K**, several implementation decisions were made to reduce hardware complexity.

These include:

- Single-hart implementation
- Minimal Debug Module
- No Program Buffer
- No System Bus Access
- Lightweight Abstract Access Unit
- Resource-conscious RTL implementation
- Simplified processor integration

These choices reduce logic utilization while preserving the core functionality required for standards-oriented debugging.

---

## Verification Methodology

Each subsystem was verified independently before complete system integration.

The verification process consisted of:

1. RTL module development
2. Functional simulation
3. Integration testing
4. FPGA synthesis
5. Place and Route
6. Bitstream generation
7. Hardware validation using Raspberry Pi Pico
8. Verification of complete debug communication flow

This staged verification methodology simplified debugging by isolating issues within individual modules before validating the complete design.

---

The following sections describe each subsystem in detail, beginning with the overall **RISC-V Debug Architecture** and progressing through the implementation of the Debug Transport Module, Debug Module Interface, Debug Module, Core Debug Adapter, and Abstract Access Unit.

# 6. RISC-V Debug Architecture

The implemented debug subsystem follows the layered architecture defined by the **RISC-V External Debug Specification**, separating the debug transport layer from processor-specific control logic. This modular organization enables standardized communication between an external debugger and the processor while maintaining clear functional boundaries between each subsystem.

Unlike the custom debug implementation developed during Task 3C, where processor control was performed through proprietary JTAG instructions, the current implementation routes all debug operations through the standard **Debug Transport Module (DTM)**, **Debug Module Interface (DMI)**, and **Debug Module (DM)**. This architecture establishes a standards-oriented debug path that can be extended for compatibility with tools such as **Ashling**, **OpenOCD**, and other RISC-V compliant debug environments.

---

## Overall Debug Architecture

<p align="center">
    <img src="docs/images/riscv_debug_architecture.png" width="900">
</p>

<p align="center">
<b>Figure 2.</b> Overall RISC-V Debug Architecture
</p>

The architecture consists of six primary functional blocks that collectively establish the communication path between the external debugger and the processor.

| Component | Function |
|-----------|----------|
| **External Debug Probe** | Generates standard JTAG transactions and initiates debug operations. In this project, a Raspberry Pi Pico is used as the JTAG master for hardware validation. |
| **JTAG Debug Transport Module (DTM)** | Implements the IEEE 1149.1 TAP controller, decodes the standard RISC-V JTAG instructions, and converts JTAG transactions into DMI requests. |
| **Debug Module Interface (DMI)** | Provides a request-response communication channel between the transport layer and the Debug Module. |
| **Debug Module (DM)** | Implements the standard debug registers, interprets DMI requests, and controls processor debugging operations. |
| **Core Debug Adapter** | Converts generic debug requests into processor-specific control signals including halt, resume, reset, and execution status monitoring. |
| **Abstract Access Unit (AAU)** | Executes register and memory access commands while the processor is halted. |

---

## Architectural Overview

The debug communication path begins with an external debugger connected through the JTAG interface. The **Debug Transport Module (DTM)** receives serialized JTAG data, manages the TAP controller state machine, and decodes the selected instruction. Depending on the active instruction, the DTM either accesses internal registers such as **IDCODE** and **DTMCS** or forwards a Debug Module Interface (DMI) transaction.

The **DMI** acts as the communication protocol between the transport layer and the Debug Module. It encapsulates read and write requests, processor status information, and abstract command execution into a standard transaction format.

Within the **Debug Module**, incoming DMI requests are decoded and mapped to the appropriate debug registers or control logic. Operations such as processor halt, resume, debug status reporting, and abstract command execution are initiated from this module.

The **Core Debug Adapter** forms the interface between the Debug Module and the custom RISC-V processor. It translates generic debug requests into processor-specific control signals while continuously monitoring processor execution status. This abstraction isolates processor-specific implementation details from the standard debug architecture.

When register or memory access is requested, the **Abstract Access Unit (AAU)** performs the required operation on behalf of the Debug Module. This implementation supports abstract register access and aligned 32-bit memory transactions without implementing a Program Buffer or System Bus Access, thereby reducing hardware complexity while satisfying the functional requirements of Task 4.

---

## Communication Path

The overall communication sequence is illustrated below.

```text
External Debug Probe
        │
        ▼
JTAG Interface
        │
        ▼
Debug Transport Module (DTM)
        │
        ▼
Debug Module Interface (DMI)
        │
        ▼
Debug Module (DM)
        │
        ▼
Core Debug Adapter
        │
        ▼
Abstract Access Unit (AAU)
        │
        ▼
RISC-V Processor
```

Every debug transaction follows this communication path, ensuring a clear separation between protocol handling, processor control, and abstract resource access.

---

## Key Architectural Features

The implemented architecture provides the following capabilities:

- Standard **5-bit JTAG Instruction Register**.
- Support for **IDCODE**, **DTMCS**, **DMI**, and **BYPASS** instructions.
- Standardized DMI request-response transactions.
- Minimal single-hart Debug Module implementation.
- Processor control through **HALT**, **RESUME**, and optional **NDMRESET** requests.
- Abstract Register Access for General Purpose Registers (GPRs).
- Abstract Memory Access for aligned 32-bit memory locations.
- Active-low **nTRST** support for TAP reset.
- FPGA implementation optimized for the **Lattice iCE40UP5K** architecture.

---

## Design Advantages

The layered architecture offers several practical advantages over the previous proof-of-concept implementation.

- **Standards-Oriented Design** – Debug communication follows the RISC-V External Debug Specification instead of relying on custom JTAG instructions.
- **Modularity** – Individual components can be developed, verified, and maintained independently.
- **Scalability** – Future support for Program Buffer, System Bus Access, Trigger Modules, and multi-hart debugging can be added without redesigning the transport layer.
- **Maintainability** – Processor-specific functionality remains isolated from the JTAG transport mechanism, simplifying future processor modifications.
- **FPGA Efficiency** – The implementation remains lightweight enough for deployment on the resource-constrained VSDSquadron FM platform.

---

The following section describes how debug requests propagate through the implemented architecture, illustrating the complete flow of information from the external debugger to the processor and back through the standard RISC-V debug communication path.

# 7. RISC-V Debug Communication Flow

The RISC-V Debug Specification defines a layered communication protocol that allows an external debugger to control processor execution through a standardized transport mechanism. In this implementation, every debug operation—including processor halt, resume, register access, and memory access—is performed through a sequence of transactions beginning at the external JTAG interface and terminating at the processor.

Unlike the custom protocol implemented during the Task 3C proof-of-concept, all debug operations are initiated using standard **JTAG Debug Transport Module (DTM)** instructions and communicated to the processor through the **Debug Module Interface (DMI)** and **Debug Module (DM)**.

---

## Debug Communication Flow

<p align="center">
    <img src="docs/images/riscv_debug_data_flow.png" width="900">
</p>

<p align="center">
<b>Figure 3.</b> End-to-End RISC-V Debug Communication Flow
</p>

The communication path is illustrated below.

```
External Debug Probe
        │
        ▼
JTAG Interface
        │
        ▼
Debug Transport Module (DTM)
        │
        ▼
Debug Module Interface (DMI)
        │
        ▼
Debug Module (DM)
        │
        ▼
Core Debug Adapter
        │
        ▼
Abstract Access Unit
        │
        ▼
RISC-V Processor
```

Each debug request follows this path in the forward direction, while status information and data responses propagate back through the same path to the external debugger.

---

## Debug Transaction Sequence

A complete debug transaction proceeds through the following stages:

### Step 1 – JTAG Command Reception

The external debugger (Raspberry Pi Pico in this implementation) generates standard JTAG transactions by driving the **TCK**, **TMS**, **TDI**, and **nTRST** signals. The JTAG TAP controller inside the Debug Transport Module samples these signals and advances through the IEEE 1149.1 TAP state machine.

Depending on the selected instruction, the TAP either accesses internal DTM registers or initiates a Debug Module Interface (DMI) transaction.

---

### Step 2 – Debug Transport Module (DTM)

The Debug Transport Module serves as the communication bridge between the JTAG interface and the Debug Module.

Its primary responsibilities include:

- Managing the TAP controller state machine
- Decoding the active Instruction Register (IR)
- Supporting the mandatory JTAG instructions:
  - **IDCODE**
  - **DTMCS**
  - **DMI**
  - **BYPASS**
- Converting serialized JTAG data into DMI request packets
- Returning DMI responses back to the external debugger

The DTM itself does not control processor execution; it only transports debug transactions.

---

### Step 3 – Debug Module Interface (DMI)

The DMI provides a standardized request-response protocol between the transport layer and the Debug Module.

Each DMI transaction contains:

- Operation type (Read / Write)
- Register Address
- Data Payload
- Response Status

The interface ensures that requests are correctly delivered to the Debug Module and that responses are returned to the transport layer.

---

### Step 4 – Debug Module (DM)

The Debug Module is responsible for interpreting DMI requests and executing processor debug operations.

Depending on the accessed register, the Debug Module may:

- Read processor status
- Halt processor execution
- Resume processor execution
- Reset the processor
- Execute abstract commands
- Access internal debug registers

The Debug Module therefore acts as the central controller of the debug subsystem.

---

### Step 5 – Core Debug Adapter

The Core Debug Adapter translates generic Debug Module commands into processor-specific control signals.

These signals include:

- `haltreq`
- `resumereq`
- `ndmreset`
- `debug_halted`
- `debug_running`
- `debug_pc`

By isolating processor-specific functionality from the Debug Module, the implementation becomes easier to maintain and adapt to different processor architectures.

---

### Step 6 – Abstract Access Unit (AAU)

When a DMI command requests register or memory access, the Debug Module delegates the operation to the Abstract Access Unit.

The AAU supports:

- Reading General Purpose Registers (GPRs)
- Writing General Purpose Registers (GPRs)
- Reading aligned 32-bit memory locations
- Writing aligned 32-bit memory locations

All abstract accesses are performed while the processor remains halted, ensuring architectural consistency during debugging.

---

### Step 7 – Response Generation

After the requested operation has completed, the resulting data or processor status is returned through the reverse communication path.

```
Processor
      │
      ▼
Abstract Access Unit
      │
      ▼
Debug Module
      │
      ▼
DMI
      │
      ▼
DTM
      │
      ▼
External Debug Probe
```

The external debugger then receives the requested data or confirmation that the operation completed successfully.

---

## Example Debug Operations

The communication flow remains identical for all supported debug operations.

| Operation | Flow |
|-----------|------|
| Read IDCODE | Probe → DTM → IDCODE Register → Probe |
| Read DTMCS | Probe → DTM → DTMCS Register → Probe |
| Read DMSTATUS | Probe → DTM → DMI → DM → Probe |
| HALT Processor | Probe → DTM → DMI → DM → Core Adapter → CPU |
| RESUME Processor | Probe → DTM → DMI → DM → Core Adapter → CPU |
| Register Access | Probe → DTM → DMI → DM → AAU → CPU Registers |
| Memory Access | Probe → DTM → DMI → DM → AAU → Memory |

---

## Advantages of the Communication Flow

The layered communication model provides several important engineering advantages:

- **Protocol Independence** – The processor is isolated from the JTAG transport protocol.
- **Modularity** – Each layer performs a well-defined function, simplifying development and verification.
- **Scalability** – Additional debug features can be introduced without modifying the transport layer.
- **Maintainability** – Processor-specific logic is confined to the Core Debug Adapter.
- **Standards Compliance** – Communication follows the architecture defined by the RISC-V External Debug Specification.

---

The following section describes the internal organization of the **Debug Module**, including the implementation of debug registers, command processing, processor control logic, and abstract command execution.

# 8. Debug Module Architecture

The **Debug Module (DM)** is the central control unit of the implemented RISC-V debug subsystem. It receives Debug Module Interface (DMI) requests from the Debug Transport Module, interprets debug commands, controls processor execution, and coordinates abstract register and memory access operations.

Unlike the Debug Transport Module, which is responsible only for transporting debug transactions, the Debug Module implements the processor-specific debugging functionality defined by the RISC-V External Debug Specification. It serves as the interface between the standard debug protocol and the custom RISC-V processor implemented on the FPGA.

---

## Debug Module Architecture

<p align="center">
    <img src="docs/images/debug_module_architecture.png" width="900">
</p>

<p align="center">
<b>Figure 4.</b> Internal Architecture of the Minimal RISC-V Debug Module
</p>

The Debug Module is organized into multiple functional blocks, each responsible for a specific aspect of processor debugging. Together, these blocks implement the minimum functionality required to support a standards-oriented debug interface while remaining suitable for implementation on the resource-constrained Lattice iCE40UP5K FPGA.

---

## Internal Components

### Debug Register File

The Debug Register File stores the control, status, and command registers accessed through the Debug Module Interface.

The implementation includes support for the following standard registers:

| Register | Purpose |
|----------|---------|
| **DMCONTROL** | Controls processor halt, resume, reset, and debug activation. |
| **DMSTATUS** | Reports the current execution state of the processor. |
| **COMMAND** | Holds abstract command requests issued by the debugger. |
| **ABSTRACTCS** | Reports the status of abstract command execution. |
| **DATA0** | Primary data register used for abstract register and memory access. |
| **DATA1** | Secondary data register for extended data transfers (implemented as required). |

These registers form the primary software-visible interface of the Debug Module.

---

### Command Decoder

The Command Decoder interprets incoming DMI write transactions and determines the requested debug operation.

Supported command categories include:

- Processor execution control
- Abstract register access
- Abstract memory access
- Debug register read/write operations

Each decoded command is forwarded to the appropriate functional block for execution.

---

### Processor Control Logic

The Processor Control Logic manages the execution state of the processor.

The implemented control signals include:

- **haltreq**
- **resumereq**
- **ndmreset** *(optional implementation)*
- **debug_running**
- **debug_halted**

When a halt request is received, processor execution is suspended and the processor enters Debug Mode. Upon receiving a resume request, normal instruction execution is restored.

The Debug Module continuously monitors the processor state to ensure that **DMSTATUS** accurately reflects the current execution status.

---

### Abstract Command Engine

The Abstract Command Engine is responsible for executing debugger requests that require direct access to processor resources.

Supported operations include:

- Reading General Purpose Registers
- Writing General Purpose Registers
- Reading aligned 32-bit memory locations
- Writing aligned 32-bit memory locations

Rather than directly accessing processor resources, the Command Engine forwards these requests to the **Abstract Access Unit (AAU)**, maintaining a clear separation between command processing and resource access.

---

### Status Generation

The Debug Module continuously monitors processor execution and updates the status registers accordingly.

The implemented status fields include:

- **authenticated**
- **allrunning**
- **anyrunning**
- **allhalted**
- **anyhalted**

Since the current implementation supports only a **single hart**, the values of **all*** and **any*** status fields are identical.

---

## Debug Register Access

All communication between the external debugger and the Debug Module occurs through the Debug Module Interface (DMI).

A typical register access sequence consists of:

1. External debugger issues a DMI request.
2. DMI forwards the request to the Debug Module.
3. Debug Module decodes the requested register address.
4. Requested register is read or updated.
5. Response is returned through the DMI.
6. External debugger receives the completed transaction.

This mechanism provides a standardized interface for accessing all debug functionality without exposing processor-specific implementation details.

---

## Processor Control Flow

The Debug Module manages processor execution through a controlled sequence of events.

### HALT Operation

```
Debugger
    │
    ▼
DMCONTROL.haltreq
    │
    ▼
Debug Module
    │
    ▼
Core Debug Adapter
    │
    ▼
Processor Halt
    │
    ▼
DMSTATUS.allhalted = 1
```

---

### RESUME Operation

```
Debugger
    │
    ▼
DMCONTROL.resumereq
    │
    ▼
Debug Module
    │
    ▼
Core Debug Adapter
    │
    ▼
Processor Resume
    │
    ▼
DMSTATUS.allrunning = 1
```

These control sequences ensure that processor execution state remains synchronized with the values reported through the Debug Module status registers.

---

## Design Considerations

The Debug Module was designed with the following objectives:

- Compliance with the mandatory features required by the RISC-V External Debug Specification.
- Clear separation between protocol handling and processor control.
- Minimal hardware resource utilization suitable for the Lattice iCE40UP5K FPGA.
- Simple and modular RTL implementation for ease of verification and future extension.
- Support for abstract register and memory access without implementing Program Buffer or System Bus Access.

By limiting the implementation to the features required for Task 4, the resulting Debug Module remains lightweight while providing a complete standards-oriented debug interface for a single-hart RISC-V processor.

---

## Summary

The Debug Module serves as the control center of the implemented debug subsystem. It receives standardized DMI requests, manages processor execution, coordinates abstract resource access, and reports processor status through a well-defined register interface. This modular organization provides a clean separation between the external debug protocol and the processor-specific implementation, forming the foundation for future expansion toward a more complete RISC-V debug environment.

The next section describes the **Clock Domain Crossing (CDC)** mechanism used to safely transfer debug requests between the JTAG clock domain and the processor system clock domain.

# 9. Clock Domain Crossing (CDC)

The implemented debug subsystem operates across two independent clock domains:

- **JTAG Clock Domain (`tck`)** – Driven by the external JTAG debugger.
- **Processor Clock Domain (`clk`)** – Drives the RISC-V processor and the remaining SoC logic.

Since these clocks are asynchronous, debug requests generated by the Debug Transport Module cannot be directly connected to the processor. Without proper synchronization, asynchronous signal transfers may lead to metastability, unreliable operation, and unpredictable processor behavior.

To ensure reliable communication, a dedicated **Clock Domain Crossing (CDC)** module is used to safely transfer debug requests and status information between the two clock domains.

---

## Clock Domain Crossing Architecture

<p align="center">
    <img src="docs/images/cdc_architecture.png" width="850">
</p>

<p align="center">
<b>Figure 5.</b> Clock Domain Crossing between the JTAG and Processor Clock Domains
</p>

The CDC module acts as a synchronization layer between the Debug Transport Module and the processor debug logic. It ensures that requests originating in the JTAG clock domain are safely captured and executed within the processor clock domain.

---

## Clock Domains

| Clock Domain | Source | Components |
|--------------|--------|------------|
| **JTAG Domain (`tck`)** | External JTAG Probe | TAP Controller, Instruction Register, Shift Registers, DTM |
| **Processor Domain (`clk`)** | FPGA System Clock | Debug Module, Core Debug Adapter, Abstract Access Unit, RISC-V Processor |

Since the clocks operate independently, direct signal transfers are avoided.

---

## Synchronization Strategy

The CDC implementation uses synchronization logic to safely communicate between the two domains.

### Request Path

The following debug requests originate from the JTAG clock domain:

- HALT Request
- RESUME Request
- RESET Request
- DMI Read Request
- DMI Write Request

These requests are synchronized before being processed by the Debug Module and Core Debug Adapter.

```
JTAG Domain (tck)
        │
        ▼
Synchronization Logic
        │
        ▼
Processor Domain (clk)
```

---

### Response Path

Processor status signals generated in the system clock domain are also synchronized before being returned to the JTAG interface.

Typical synchronized status signals include:

- Processor Halted
- Processor Running
- Abstract Command Complete
- DMI Response Ready

```
Processor Domain (clk)
        │
        ▼
Synchronization Logic
        │
        ▼
JTAG Domain (tck)
```

---

## Pulse Generation

Control operations such as **HALT**, **RESUME**, and **RESET** are implemented as single-cycle pulses within the processor clock domain.

After synchronization, the CDC module generates one-clock-wide pulses that trigger the required processor operation.

```
HALT Request
        │
        ▼
Synchronizer
        │
        ▼
Single-Cycle Pulse
        │
        ▼
Processor
```

This approach prevents repeated execution of the same debug command while ensuring deterministic processor control.

---

## Metastability Protection

To improve reliability, asynchronous control signals are passed through multi-stage synchronizers before being used by the processor.

This technique significantly reduces the probability of metastability by allowing sufficient settling time before the synchronized signal is consumed by downstream logic.

The synchronization strategy ensures:

- Reliable transfer of asynchronous requests.
- Stable processor control signals.
- Deterministic debug operation.
- Independence between the JTAG and processor clock frequencies.

---

## Design Advantages

The dedicated CDC implementation provides several important benefits:

- Safe communication between asynchronous clock domains.
- Prevention of metastability-related failures.
- Reliable execution of HALT, RESUME, and RESET commands.
- Deterministic synchronization of processor status signals.
- Modular interface between the transport layer and processor logic.
- Scalability for future enhancements and additional debug features.

---

## Verification

The Clock Domain Crossing module was verified during simulation using dedicated CDC test scenarios.

The verification included:

- HALT request synchronization.
- RESUME request synchronization.
- RESET request synchronization.
- Correct generation of single-cycle control pulses.
- Reliable propagation of processor status signals.
- End-to-end validation within the complete SoC debug testbench.

Simulation results confirmed that debug requests were transferred safely across clock domains without missed events or repeated command execution.

---

## Summary

The Clock Domain Crossing module provides a reliable bridge between the asynchronous JTAG and processor clock domains. By synchronizing control requests and status responses, it enables deterministic processor debugging while preventing metastability and ensuring correct operation of the complete RISC-V debug subsystem.

The following section describes the RTL implementation of the major hardware modules, including the Debug Transport Module, Debug Module Interface, Debug Module, Core Debug Adapter, and Abstract Access Unit.

# 10. RTL Implementation

The complete RISC-V debug subsystem is implemented in synthesizable Verilog and organized as a collection of modular RTL components. Each module performs a well-defined function within the overall debug architecture, allowing independent development, verification, and future extensibility.

The RTL implementation closely follows the layered architecture presented in the previous sections, separating transport, protocol, processor control, and abstract access into distinct hardware modules. This modular organization improves code readability, simplifies debugging, and facilitates future integration of additional RISC-V debug features.

The complete implementation consists of the following RTL modules:

| RTL Module | Function |
|------------|----------|
| `riscv_jtag_dtm.v` | Implements the JTAG Debug Transport Module (DTM), including the TAP controller, Instruction Register, Data Registers, and standard JTAG instructions. |
| `dmi_interface.v` | Implements the Debug Module Interface (DMI), providing request-response communication between the DTM and the Debug Module. |
| `riscv_debug_module_minimal.v` | Implements the Debug Module registers, command decoder, processor control logic, and abstract command management. |
| `core_debug_adapter.v` | Translates generic debug requests into processor-specific control signals such as halt, resume, and reset. |
| `abstract_access_unit.v` | Executes abstract register and memory access operations while the processor is halted. |
| `top_riscv_debug_spec_fm.v` | Integrates all debug components with the RISC-V processor and FPGA peripherals into a complete top-level design. |

---

## 10.1 JTAG Debug Transport Module (DTM)

The Debug Transport Module forms the external interface of the debug subsystem. It implements the IEEE 1149.1 JTAG Test Access Port (TAP) controller and provides the transport layer defined by the RISC-V External Debug Specification.

Its primary responsibilities include:

- Implementing the TAP controller state machine.
- Managing the 5-bit Instruction Register.
- Supporting the mandatory JTAG instructions:
  - IDCODE
  - DTMCS
  - DMI
  - BYPASS
- Serializing and deserializing JTAG data.
- Generating DMI requests from JTAG transactions.
- Returning DMI responses to the external debugger.

The DTM is intentionally protocol-oriented and contains no processor-specific functionality.

---

## 10.2 Debug Module Interface (DMI)

The Debug Module Interface provides a standardized communication channel between the Debug Transport Module and the Debug Module.

Its responsibilities include:

- Receiving read and write requests from the DTM.
- Decoding DMI operations.
- Forwarding requests to the Debug Module.
- Returning response data and status information.
- Supporting synchronized request-response communication.

The DMI abstracts the transport mechanism from the Debug Module, allowing processor control logic to remain independent of the JTAG interface.

---

## 10.3 Debug Module (DM)

The Debug Module serves as the central controller of the debug subsystem.

Its responsibilities include:

- Managing debug control registers.
- Maintaining processor status information.
- Decoding incoming DMI commands.
- Generating processor halt, resume, and reset requests.
- Managing abstract command execution.
- Coordinating register and memory access operations.

The implemented Debug Module supports the mandatory functionality required for a single-hart RISC-V processor while minimizing FPGA resource utilization.

---

## 10.4 Core Debug Adapter

The Core Debug Adapter provides the interface between the generic Debug Module and the processor-specific debug signals.

Its responsibilities include:

- Translating HALT requests.
- Translating RESUME requests.
- Translating RESET requests.
- Monitoring processor execution state.
- Reporting processor status to the Debug Module.
- Isolating processor-specific implementation details from the standard debug architecture.

This separation allows the Debug Module to remain compliant with the RISC-V debug architecture while simplifying processor integration.

---

## 10.5 Abstract Access Unit (AAU)

The Abstract Access Unit executes debugger requests requiring access to processor resources.

Supported operations include:

- Reading General Purpose Registers (GPRs).
- Writing General Purpose Registers (GPRs).
- Reading aligned 32-bit memory locations.
- Writing aligned 32-bit memory locations.

All abstract accesses are performed while the processor is halted, ensuring a consistent processor state during debugging.

The AAU eliminates the need for direct debugger interaction with processor internals, providing a clean abstraction layer between the Debug Module and the processor.

---

## 10.6 Top-Level Integration

The top-level module integrates all RTL components into a complete FPGA-ready design.

The integration includes:

- JTAG interface.
- Debug Transport Module.
- Debug Module Interface.
- Debug Module.
- Core Debug Adapter.
- Abstract Access Unit.
- RISC-V processor.
- System memory.
- FPGA I/O interfaces.

The top-level module also connects the external JTAG pins to the internal debug subsystem and interfaces the processor with the surrounding SoC components.

---

## RTL Design Characteristics

The RTL implementation was developed with the following design objectives:

- Fully synthesizable Verilog implementation.
- Modular architecture with clearly defined interfaces.
- Compliance with the mandatory features of the RISC-V External Debug Specification.
- Efficient resource utilization for the Lattice iCE40UP5K FPGA.
- Simple integration with an existing RISC-V processor.
- Ease of verification through independent module testing.

---

## Module Interaction

The interaction between the RTL modules follows the same layered architecture described in previous sections.

```text
JTAG Interface
      │
      ▼
JTAG Debug Transport Module
      │
      ▼
Debug Module Interface
      │
      ▼
Debug Module
      │
      ▼
Core Debug Adapter
      │
      ▼
Abstract Access Unit
      │
      ▼
RISC-V Processor
```

Each module performs a dedicated function, resulting in a modular, maintainable, and extensible debug implementation suitable for FPGA deployment.

---

The following sections provide implementation details for FPGA synthesis, simulation, and hardware validation, demonstrating the successful deployment of the complete debug subsystem on the VSDSquadron FM platform.

# 11. FPGA Implementation

Following functional verification of the RTL modules, the complete RISC-V debug subsystem was synthesized, placed, routed, and programmed onto the **VSDSquadron FM FPGA**. The objective of the FPGA implementation was to validate that the complete debug architecture operates correctly on real hardware and interfaces successfully with an external JTAG debugger.

The implementation flow followed a standard FPGA design methodology using an open-source toolchain, ensuring reproducibility and compatibility with the Lattice iCE40UP5K FPGA.

---

## Target Hardware

The design was implemented on the following hardware platform.

| Parameter | Value |
|----------|-------|
| FPGA Board | VSDSquadron FM |
| FPGA Device | Lattice iCE40UP5K |
| Logic Family | UltraPlus |
| Debug Interface | IEEE 1149.1 JTAG |
| External Debug Probe | Raspberry Pi Pico |
| Programming Interface | USB |

The FPGA hosts the complete RISC-V processor along with the integrated debug subsystem, allowing hardware validation of processor control and abstract access operations.

---

## FPGA Design Flow

The implementation followed the standard FPGA development flow shown below.

```text
RTL Design
     │
     ▼
Functional Simulation
     │
     ▼
Synthesis (Yosys)
     │
     ▼
Technology Mapping
     │
     ▼
Place & Route (nextpnr)
     │
     ▼
Bitstream Generation (IcePack)
     │
     ▼
FPGA Programming
     │
     ▼
Hardware Validation
```

Each stage was completed successfully before progressing to the next phase of development.

---

## Toolchain

The complete implementation was performed using an open-source FPGA development toolchain.

| Tool | Purpose |
|------|---------|
| **Yosys** | RTL synthesis |
| **nextpnr-ice40** | Placement and routing |
| **IcePack** | Bitstream generation |
| **IceProg / Board Programmer** | FPGA programming |
| **Icarus Verilog** | Functional simulation |
| **GTKWave** | Waveform analysis |

This toolchain provides a fully open-source workflow from RTL design to FPGA deployment.

---

## Pin Assignment

The FPGA pin constraints were defined in the project constraint file (`VSDSquadronFM_debug_spec.pcf`).

The following interfaces were mapped:

- JTAG Clock (`TCK`)
- JTAG Mode Select (`TMS`)
- JTAG Data Input (`TDI`)
- JTAG Data Output (`TDO`)
- Active-Low Reset (`nTRST`)
- System Clock
- Reset Input
- Status LEDs

These constraints establish the physical connection between the FPGA and the external Raspberry Pi Pico JTAG debugger.

---

## Top-Level Integration

The top-level FPGA design integrates:

- RISC-V Processor
- Debug Transport Module (DTM)
- Debug Module Interface (DMI)
- Minimal Debug Module
- Core Debug Adapter
- Abstract Access Unit
- On-chip Memory
- Clock Generation
- FPGA I/O

All debug-related modules are instantiated within the top-level design and interconnected according to the architecture described in previous sections.

---

## Hardware Build Process

The FPGA build process consists of the following stages:

1. RTL source files are synthesized using **Yosys**.
2. The synthesized netlist is mapped to the iCE40UP5K architecture.
3. **nextpnr** performs placement and routing.
4. Timing checks are completed.
5. A configuration bitstream is generated.
6. The bitstream is programmed onto the VSDSquadron FM FPGA.
7. Hardware validation is performed using the Raspberry Pi Pico as the external JTAG debugger.

---

## Implementation Results

The FPGA implementation completed successfully without synthesis or routing errors. The generated bitstream was programmed onto the VSDSquadron FM board, enabling real-time verification of the implemented debug subsystem.

Successful hardware operation confirmed:

- Correct FPGA synthesis.
- Successful place and route.
- Proper JTAG connectivity.
- Functional DTM and DMI communication.
- Correct processor halt and resume control.
- Successful abstract register access.
- Successful abstract memory access.
- Reliable processor reset operation.

---

## Hardware Demonstration

The implemented system was validated using a Raspberry Pi Pico configured as a JTAG master. The Pico generated standard RISC-V debug transactions, which were processed by the FPGA to verify end-to-end functionality of the debug subsystem.

The hardware setup included:

- VSDSquadron FM FPGA Board
- Raspberry Pi Pico
- JTAG connection wires
- USB interface for programming and serial communication

A photograph of the complete hardware setup is shown below.

<p align="center">
    <img src="docs/images/hardware_setup.jpg" width="800">
</p>

<p align="center">
<b>Figure 6.</b> FPGA Hardware Validation Setup
</p>

---

## Summary

The successful FPGA implementation demonstrates that the proposed RISC-V debug subsystem is not only functionally correct in simulation but also operates reliably on physical hardware. The use of an open-source FPGA toolchain and a Raspberry Pi Pico as the JTAG debugger validates the portability and practical applicability of the design.

The next section presents the simulation and functional verification results, followed by hardware validation demonstrating the successful execution of all required debug operations.

# 12. Simulation and Functional Verification

Prior to FPGA implementation, the complete RISC-V debug subsystem was verified through functional simulation. The objective of this verification phase was to ensure that each component operated correctly in isolation and that the integrated system complied with the required functionality of the RISC-V External Debug Specification.

A comprehensive SystemVerilog testbench (`tb_soc_debug.v`) was developed to exercise the entire debug communication path, from the external JTAG interface to the processor debug logic. The testbench generates standard JTAG transactions, monitors DMI communication, and validates processor responses for each supported debug operation.

---

## Verification Objectives

The simulation environment was designed to verify the following functionality:

- Correct operation of the IEEE 1149.1 TAP controller.
- Proper decoding of the 5-bit JTAG Instruction Register.
- Successful execution of the mandatory JTAG instructions:
  - IDCODE
  - DTMCS
  - DMI
  - BYPASS
- Correct DMI read and write transactions.
- Processor HALT request.
- Processor RESUME request.
- Processor RESET request.
- Abstract Register Access.
- Abstract Memory Access.
- Correct Debug Module status reporting.
- Reliable Clock Domain Crossing (CDC).

---

## Simulation Environment

The complete design was simulated using the following tools:

| Tool | Purpose |
|------|---------|
| **Icarus Verilog** | RTL compilation and simulation |
| **GTKWave** | Waveform visualization |
| **tb_soc_debug.v** | Comprehensive system-level verification |

The testbench models the behavior of an external JTAG debugger and verifies the complete debug communication flow.

---

## Verification Flow

Each simulation follows the sequence shown below:

```text
Initialize Testbench
        │
        ▼
Reset Debug System
        │
        ▼
Read IDCODE
        │
        ▼
Read DTMCS
        │
        ▼
Execute DMI Transactions
        │
        ▼
Verify DMSTATUS
        │
        ▼
HALT Processor
        │
        ▼
Register Access
        │
        ▼
Memory Access
        │
        ▼
RESUME Processor
        │
        ▼
RESET Processor
        │
        ▼
End Simulation
```

Each stage is verified before the next operation begins, ensuring complete end-to-end validation.

---

## Functional Test Results

The following table summarizes the verification performed during simulation.

| Test Case | Description | Result |
|-----------|-------------|--------|
| TAP Reset | Verify proper reset of the TAP controller | ✅ PASS |
| IDCODE | Read and verify device identification register | ✅ PASS |
| DTMCS | Read Debug Transport Module Control and Status register | ✅ PASS |
| DMI Read/Write | Verify Debug Module Interface transactions | ✅ PASS |
| DMSTATUS | Read processor debug status | ✅ PASS |
| HALT | Stop processor execution | ✅ PASS |
| Register Access | Read and write General Purpose Registers | ✅ PASS |
| Memory Access | Read and write aligned 32-bit memory | ✅ PASS |
| RESUME | Resume processor execution | ✅ PASS |
| RESET | Reset processor and verify recovery | ✅ PASS |

All required verification scenarios completed successfully.

---

## Simulation Waveforms

Waveform analysis was performed throughout the verification process to confirm correct protocol behavior and timing relationships.

The following waveforms were inspected:

- TAP controller state transitions.
- Instruction Register shifting.
- DMI request and response timing.
- HALT and RESUME control signals.
- Processor status transitions.
- Register access transactions.
- Memory access transactions.
- RESET sequence.
- Clock Domain Crossing synchronization.

Representative waveform captures are included below.

<p align="center">
    <img src="docs/images/simulation_waveform_1.png" width="850">
</p>

<p align="center">
<b>Figure 7.</b> Representative Simulation Waveform
</p>

---

## Simulation Log

The simulation testbench reports the result of each verification stage through the simulation console.

A typical execution includes:

- TAP reset confirmation.
- Successful IDCODE read.
- Successful DTMCS read.
- Correct DMI transactions.
- HALT acknowledged.
- Register access completed.
- Memory access completed.
- Processor resumed.
- Processor reset completed.
- Overall verification passed.

An example simulation log is shown below.

<p align="center">
    <img src="docs/images/simulation_log.png" width="850">
</p>

<p align="center">
<b>Figure 8.</b> Simulation Output
</p>

---

## Verification Summary

The functional simulation demonstrates that the implemented debug subsystem correctly performs all mandatory operations required for the project. The successful execution of processor control, abstract access operations, and DMI communication confirms that the RTL implementation is functionally correct before deployment on FPGA hardware.

The next section presents the hardware validation of the implemented design on the VSDSquadron FM FPGA using a Raspberry Pi Pico configured as the external JTAG debugger.

# 13. Hardware Validation

Following successful functional simulation, the complete RISC-V debug subsystem was deployed on the **VSDSquadron FM FPGA** for hardware validation. The objective of this phase was to verify that the implemented debug architecture operates correctly on physical hardware and that all mandatory debug operations function reliably under real-world conditions.

Hardware validation confirms that the RTL implementation is not only functionally correct in simulation but also synthesizable, deployable, and capable of interacting with an external JTAG debugger.

---

## Hardware Platform

The validation setup consisted of the following hardware components.

| Component | Description |
|----------|-------------|
| FPGA Board | VSDSquadron FM |
| FPGA Device | Lattice iCE40UP5K |
| Processor | Custom 32-bit RISC-V Core |
| Debug Interface | IEEE 1149.1 JTAG |
| External Debug Probe | Raspberry Pi Pico |
| Communication | USB Serial + JTAG |

The Raspberry Pi Pico was programmed to function as a JTAG master, generating standard RISC-V debug transactions and communicating directly with the FPGA.

---

## Hardware Setup

The complete hardware setup is illustrated below.

<p align="center">
    <img src="docs/images/hardware_setup.jpg" width="850">
</p>

<p align="center">
<b>Figure 9.</b> Hardware Validation Setup
</p>

The Raspberry Pi Pico was connected to the FPGA using the standard JTAG interface.

| JTAG Signal | Function |
|-------------|----------|
| TCK | Test Clock |
| TMS | Test Mode Select |
| TDI | Test Data Input |
| TDO | Test Data Output |
| nTRST | Active-Low TAP Reset |
| GND | Common Ground |

The FPGA was programmed with the generated bitstream before initiating hardware verification.

---

## Hardware Validation Procedure

Each debug operation was validated independently using the Raspberry Pi Pico.

The verification sequence consisted of the following steps:

1. Program the FPGA with the generated bitstream.
2. Initialize the JTAG interface.
3. Reset the TAP controller using **nTRST**.
4. Read the **IDCODE** register.
5. Read the **DTMCS** register.
6. Execute DMI read and write transactions.
7. Read **DMSTATUS**.
8. Issue a **HALT** request.
9. Perform abstract register access.
10. Perform abstract memory access.
11. Issue a **RESUME** request.
12. Issue a **RESET** request.
13. Verify successful completion of all operations.

---

## Functional Validation Results

The following table summarizes the results obtained during hardware testing.

| Test | Objective | Result |
|------|-----------|--------|
| TAP Reset | Verify proper TAP initialization | ✅ PASS |
| IDCODE | Read device identification register | ✅ PASS |
| DTMCS | Read transport module status register | ✅ PASS |
| DMI Transactions | Verify Debug Module communication | ✅ PASS |
| DMSTATUS | Read processor debug status | ✅ PASS |
| HALT | Stop processor execution | ✅ PASS |
| Register Access | Read and write General Purpose Registers | ✅ PASS |
| Memory Access | Read and write aligned 32-bit memory | ✅ PASS |
| RESUME | Resume processor execution | ✅ PASS |
| RESET | Reset processor successfully | ✅ PASS |

Every mandatory debug operation completed successfully during hardware validation.

---

## Terminal Output

Communication between the Raspberry Pi Pico and the FPGA was monitored through the serial terminal.

The terminal output confirmed:

- Successful TAP initialization.
- Correct IDCODE detection.
- Successful DTMCS communication.
- Proper DMI request and response handling.
- Processor halt acknowledgment.
- Successful abstract register access.
- Successful abstract memory access.
- Processor resume confirmation.
- Successful processor reset.

An example terminal output is shown below.

<p align="center">
    <img src="docs/images/terminal_output.png" width="850">
</p>

<p align="center">
<b>Figure 10.</b> Hardware Validation Terminal Output
</p>

---

## FPGA Status Indication

To assist with hardware debugging, selected processor and debug states were mapped to the onboard LEDs.

| LED | Function |
|-----|----------|
| LED1 | Heartbeat / System Running |
| LED2 | Processor Running |
| LED3 | Processor Halted |
| LED4 | Resume Request Indicator |
| LED5 | Reset Request Indicator |

These visual indicators provided immediate confirmation of processor state transitions during hardware testing.

---

## Observations

The implemented debug subsystem behaved consistently throughout the hardware validation process.

The following observations were made:

- JTAG communication remained stable during repeated transactions.
- The Debug Transport Module correctly decoded all supported instructions.
- DMI transactions completed without communication errors.
- Processor halt and resume requests produced the expected execution state transitions.
- Abstract register and memory access operations returned valid data.
- Processor reset correctly restored execution to the reset state.
- Clock Domain Crossing logic reliably synchronized requests between the JTAG and processor clock domains.

The hardware behavior closely matched the results obtained during functional simulation, confirming the correctness of the RTL implementation.

---

## Validation Summary

The successful deployment of the design on the VSDSquadron FM FPGA demonstrates that the proposed RISC-V debug subsystem satisfies the functional requirements of the project. All mandatory debug features—including processor control, abstract register access, abstract memory access, and standardized DMI communication—were verified on physical hardware using a Raspberry Pi Pico configured as an external JTAG debugger.

The close agreement between simulation and hardware results provides confidence in both the architecture and the RTL implementation, demonstrating that the design is suitable for practical FPGA-based RISC-V debugging applications.

The following section presents a discussion of the overall implementation results, resource utilization, and key achievements of the project.


# 14. Results and Discussion

The implementation and validation of the RISC-V debug subsystem demonstrate the successful integration of a standards-oriented debugging architecture into a custom RISC-V processor running on the VSDSquadron FM FPGA. Through comprehensive simulation and hardware validation, all mandatory functionality required for the project was verified, confirming both the correctness of the RTL implementation and its practical applicability on physical hardware.

The project successfully replaces the custom debugging approach developed during the earlier proof-of-concept with a structured architecture based on the RISC-V External Debug Specification. By introducing a dedicated Debug Transport Module (DTM), Debug Module Interface (DMI), Minimal Debug Module (DM), Core Debug Adapter, and Abstract Access Unit (AAU), the implementation achieves a clear separation between transport, protocol handling, processor control, and abstract resource access.

---

## Achievements

The following major objectives of the project were successfully accomplished:

- Implementation of a standards-oriented **JTAG Debug Transport Module (DTM)** with a 5-bit Instruction Register.
- Support for the mandatory JTAG instructions:
  - IDCODE
  - DTMCS
  - DMI
  - BYPASS
- Successful implementation of the **Debug Module Interface (DMI)** for request-response communication.
- Development of a **Minimal Debug Module** supporting processor control and status reporting.
- Integration of a **Core Debug Adapter** for processor-specific debug control.
- Implementation of an **Abstract Access Unit** supporting register and memory access.
- Safe communication between asynchronous clock domains using dedicated Clock Domain Crossing (CDC) logic.
- Successful deployment on the **VSDSquadron FM FPGA**.
- End-to-end hardware validation using a **Raspberry Pi Pico** configured as a JTAG debugger.

---

## Functional Results

The implemented debug subsystem successfully supports all mandatory debug operations required for the project.

| Feature | Status |
|---------|--------|
| JTAG TAP Controller | ✅ Verified |
| 5-bit Instruction Register | ✅ Verified |
| IDCODE Instruction | ✅ Verified |
| DTMCS Instruction | ✅ Verified |
| DMI Transactions | ✅ Verified |
| DMSTATUS Register | ✅ Verified |
| Processor HALT | ✅ Verified |
| Processor RESUME | ✅ Verified |
| Processor RESET | ✅ Verified |
| Abstract Register Access | ✅ Verified |
| Abstract Memory Access | ✅ Verified |
| nTRST Support | ✅ Verified |
| FPGA Deployment | ✅ Verified |
| Hardware Validation | ✅ Verified |

The successful completion of these tests confirms that the implemented debug subsystem satisfies the functional requirements defined for the project.

---

## Discussion

The layered architecture adopted in this implementation proved to be highly effective for developing and verifying the debug subsystem. By separating transport, communication, processor control, and abstract access into independent modules, each component could be designed and tested individually before complete system integration. This modular structure also simplified debugging and improved the maintainability of the RTL code.

The dedicated Clock Domain Crossing (CDC) logic ensured reliable communication between the asynchronous JTAG clock domain and the processor system clock domain. Both simulation and hardware testing confirmed that debug requests and status signals were transferred correctly without introducing synchronization-related issues.

Hardware validation demonstrated close agreement with simulation results. Operations such as processor halt, resume, reset, register access, and memory access behaved consistently across both environments, providing confidence in the correctness of the implementation and the verification methodology.

Although the implementation focuses on a minimal single-hart debug architecture, the modular design allows additional functionality to be incorporated with minimal changes to the existing framework.

---

## Compliance with Project Requirements

The implemented design addresses the primary technical requirements of the project, including:

- Standard JTAG-based debug communication.
- Debug Module Interface (DMI).
- Minimal Debug Module implementation.
- Processor execution control.
- Abstract register access.
- Abstract memory access.
- Active-low TAP reset (nTRST).
- FPGA implementation and hardware validation.

These capabilities demonstrate successful completion of the required functionality while maintaining compatibility with the architecture defined by the RISC-V External Debug Specification.

---

## Key Contributions

The primary contributions of this project include:

- Design and implementation of a modular RISC-V debug subsystem.
- Integration of a standards-oriented debug architecture into a custom RISC-V processor.
- FPGA realization using the VSDSquadron FM platform.
- End-to-end verification through simulation and hardware testing.
- Demonstration of reliable processor control and abstract resource access using an external JTAG debugger.

These contributions provide a foundation for future enhancements while demonstrating the feasibility of implementing a lightweight RISC-V debug solution on resource-constrained FPGA platforms.

---

## Summary

The results presented in this chapter demonstrate that the implemented debug subsystem satisfies the functional objectives established at the beginning of the project. Successful verification in both simulation and hardware confirms the correctness of the architecture, the reliability of the RTL implementation, and the effectiveness of the adopted design methodology.

While the implementation intentionally focuses on the mandatory features of the RISC-V External Debug Specification, its modular organization provides a scalable framework for extending the debug subsystem with more advanced capabilities in future work.

The following section discusses the limitations of the current implementation and outlines possible enhancements for future development.

# 15. Conclusion

This project presented the design, implementation, and validation of a standards-oriented RISC-V debug subsystem based on the RISC-V External Debug Specification. The developed architecture replaces the custom debugging mechanism from the earlier proof-of-concept with a modular framework consisting of a **JTAG Debug Transport Module (DTM)**, **Debug Module Interface (DMI)**, **Minimal Debug Module (DM)**, **Core Debug Adapter**, and **Abstract Access Unit (AAU)**. Together, these components establish a complete debug communication path between an external JTAG debugger and the RISC-V processor.

The implementation supports the mandatory debug functionality required for a minimal RISC-V debug environment, including **IDCODE**, **DTMCS**, **DMI** transactions, processor **HALT**, **RESUME**, and **RESET** operations, **Abstract Register Access**, **Abstract Memory Access**, and **nTRST** support. A dedicated **Clock Domain Crossing (CDC)** mechanism was incorporated to ensure reliable communication between the asynchronous JTAG and processor clock domains.

Comprehensive verification was performed through functional simulation using a system-level testbench, followed by successful deployment on the **VSDSquadron FM FPGA**. Hardware validation with a **Raspberry Pi Pico** configured as a JTAG master confirmed correct execution of all implemented debug operations. The close agreement between simulation and hardware results demonstrates the correctness of the RTL implementation and the effectiveness of the adopted verification methodology.

Beyond satisfying the project requirements, this work establishes a modular and extensible debug framework that can serve as the foundation for more advanced RISC-V debugging capabilities. Features such as multi-hart support, Program Buffer execution, System Bus Access (SBA), hardware breakpoints, trigger modules, and integration with standard debug tools such as **OpenOCD** and **GDB** can be incorporated with minimal architectural changes.

Overall, the project demonstrates that a lightweight, standards-oriented RISC-V debug subsystem can be successfully implemented on a resource-constrained FPGA while maintaining modularity, reliability, and compliance with the essential concepts of the RISC-V External Debug Specification. The resulting design provides a practical platform for future research, education, and FPGA-based RISC-V processor development.



