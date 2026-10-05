# SIMT GPGPU

## A Custom Multi-Core SIMT GPU Architecture in Verilog RTL

A custom **SIMT (Single Instruction, Multiple Threads) General-Purpose GPU** designed and implemented from scratch using **Verilog RTL**.

The architecture implements a **64-thread SIMT execution engine** organized into **4 cores**, with **2 blocks per core** and **8 threads per block**.

The design includes a shared instruction and control path, parallel thread-level execution units, private write-back L1 caches, cache arbitration, a shared memory controller, and a backing data memory.

The project focuses on practical implementation of GPU microarchitecture concepts including:

* SIMT execution
* Multi-core organization
* Thread activation and masking
* Shared instruction fetch and decode
* Parallel ALU execution
* Load/Store execution
* Per-thread register files
* Private L1 caches
* Direct-mapped write-back caching
* Dirty-line eviction
* Cache arbitration
* Memory-controller arbitration
* FSM-based control
* RTL hierarchy and modular design
* Simulation-based hardware verification

---

# Architecture Overview

The GPU is organized hierarchically around a shared control path and four independent execution cores.

```text
                         SIMT GPGPU
                             │
              ┌──────────────┴──────────────┐
              │       Shared Control        │
              │                              │
              │  Thread Controller           │
              │  Scheduler                   │
              │  Program Counter             │
              │  Fetcher                     │
              │  Decoder                     │
              │  Instruction Memory          │
              └──────────────┬──────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
       CORE 0             CORE 1             CORE 2             CORE 3
          │                  │                  │                  │
      2 Blocks           2 Blocks           2 Blocks           2 Blocks
          │                  │                  │                  │
     16 Threads         16 Threads         16 Threads         16 Threads
          │                  │                  │                  │
       L1 Cache           L1 Cache           L1 Cache           L1 Cache
          │                  │                  │                  │
          └──────────────────┴──────────────────┴──────────────────┘
                                      │
                                      ▼
                             Memory Controller
                                      │
                                      ▼
                                 Data Memory
```

The architecture follows the **SIMT execution model**, where active threads execute the same decoded instruction while maintaining independent register and data state.

The GPU uses a **single shared instruction stream**. The Scheduler, PC, Fetcher, Decoder, and Instruction Memory are shared by the four cores rather than being duplicated per core.

This allows the architecture to demonstrate the fundamental relationship between **SIMT control flow and parallel thread execution**.

---

# Architecture Diagram

The following diagram represents the complete high-level architecture of the GPU.



<img width="1264" height="843" alt="Gemini_Generated_Image_i910rni910rni910" src="https://github.com/user-attachments/assets/931888ee-bcc6-4dbc-a5e0-99d183756fef" />


---

# Architecture Specifications

| Feature                | Specification    |
| ---------------------- | ---------------- |
| Architecture           | SIMT GPGPU       |
| RTL Language           | Verilog          |
| Number of Cores        | 4                |
| Blocks per Core        | 2                |
| Threads per Block      | 8                |
| Threads per Core       | 16               |
| Total Hardware Threads | 64               |
| Instruction Width      | 16 bits          |
| Data Width             | 32 bits          |
| Address Width          | 32 bits          |
| Registers per Thread   | 16               |
| Register Width         | 32 bits          |
| Instruction Memory     | 256 × 16-bit     |
| L1 Cache               | Private per Core |
| Cache Organization     | Direct-Mapped    |
| Cache Lines            | 128              |
| Words per Line         | 8                |
| L1 Cache Capacity      | 4 KB / Core      |
| Cache Policy           | Write-Back       |
| Cache Arbitration      | Round-Robin      |
| L1 Requesters          | 16 LSUs / Core   |
| Memory Controllers     | 1 Shared         |
| Data Memory            | 1 Shared         |
| Execution Model        | Lockstep SIMT    |

### Thread Organization

```text
4 Cores
   │
   ├── Core 0
   │    ├── Block 0 → 8 Threads
   │    └── Block 1 → 8 Threads
   │
   ├── Core 1
   │    ├── Block 2 → 8 Threads
   │    └── Block 3 → 8 Threads
   │
   ├── Core 2
   │    ├── Block 4 → 8 Threads
   │    └── Block 5 → 8 Threads
   │
   └── Core 3
        ├── Block 6 → 8 Threads
        └── Block 7 → 8 Threads

Total = 4 × 2 × 8 = 64 Hardware Threads
```

---

# SIMT Execution Model

The GPU follows a **Single Instruction, Multiple Threads** execution model.

Instead of each thread having its own instruction-fetch and decode path, the GPU uses a shared control path.

```text
                       Instruction
                            │
                            ▼
                         Fetch
                            │
                            ▼
                         Decode
                            │
                            ▼
                   ┌─────────────────┐
                   │    Scheduler    │
                   └────────┬────────┘
                            │
                     Shared Instruction
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
       Thread 0          Thread 1         Thread N
          │                 │                 │
         ALU               ALU               ALU
         LSU               LSU               LSU
         RF                RF                RF
```

Every active thread executes the same instruction while operating on its own register state and memory data.

The `Thread_Controller` generates the active-thread mask used throughout the execution hierarchy.

---

# Thread Activation and Masking


<img width="1364" height="768" alt="Gemini_Generated_Image_xcc2ctxcc2ctxcc2" src="https://github.com/user-attachments/assets/7f6eec1c-1fea-4b41-abfa-ea810a9584fe" />



The GPU supports thread-level activation through the `thread_en` mask.

For example, if only 10 threads are active:

```text
thread_count = 10

thread_en =
0000000000000000000000000000000000000000000000000011111111111111
```

Only the enabled threads participate in the current instruction.

Inactive threads remain disabled.

The Thread Controller provides:

* `thread_en`
* `thread_id`
* `block_id`

The global thread ID uses 6 bits:

```text
Thread 0  → 000000
Thread 1  → 000001
...
Thread 63 → 111111
```

The block ID uses 3 bits:

```text
Block 0 → 000
Block 1 → 001
...
Block 7 → 111
```

---

# Shared Control Path

The entire GPU uses a shared instruction/control path.

```text
Thread Controller
       │
       ├──────────────► thread_en
       │
       ▼
      PC
       │
       ▼
    Fetcher
       │
       ▼
Instruction Memory
       │
       ▼
    Decoder
       │
       ▼
   Scheduler
       │
       ├──────────────► Core 0
       ├──────────────► Core 1
       ├──────────────► Core 2
       └──────────────► Core 3
```

This approach avoids duplicating the instruction fetch and decode logic for every core.

All cores receive the same instruction stream and execute it across their active threads.

---

# Program Counter

The GPU uses a shared **8-bit Program Counter**.

The PC supports sequential execution:

```text
PC = PC + 1
```

and branch execution:

```text
PC = Branch Target
```

Because the architecture follows a shared SIMT instruction stream, there is no independent PC for every hardware thread.

---

# Instruction Fetch

The Fetcher connects the shared PC to the Instruction Memory.

```text
PC
 │
 ▼
Fetcher
 │
 ▼
Instruction Memory
 │
 │ 16-bit instruction
 ▼
Decoder
```

The Instruction Memory contains:

```text
256 × 16-bit instructions
```

The Fetcher generates the instruction memory access and provides the fetched instruction to the Decoder.

---

# Instruction Decoder

The Decoder receives a 16-bit instruction and extracts the relevant fields.

A simplified instruction layout is:

```text
15          12 11        8 7        4 3        0
┌────────────┬────────────┬──────────┬──────────┐
│   Opcode   │  RD / NZP │    RS    │ RT / IMM │
└────────────┴────────────┴──────────┴──────────┘
```

Depending on the instruction, fields can represent:

* Opcode
* Destination register
* Source registers
* Immediate value
* NZP branch condition

The Decoder generates control signals for:

* Register write
* Memory read
* Memory write
* ALU operation
* ALU comparison
* Branch control
* Result MUX selection
* Return/end execution

Reserved opcodes are handled safely as no-operations.

---

# Scheduler

The Scheduler is the central control FSM of the GPU.

The main execution states are:

```text
IDLE
  │
  ▼
FETCH
  │
  ▼
DECODE
  │
  ▼
REQUEST
  │
  ▼
WAIT
  │
  ▼
EXECUTE
  │
  ▼
UPDATE
  │
  └──────────────► FETCH
```

The Scheduler controls:

* Instruction sequencing
* Fetch enable
* PC enable
* Branch control
* Register write enables
* ALU execution
* LSU execution
* Completion handling
* Thread-level execution enables

The `thread_en` mask is applied to execution units.

For an ALU instruction:

```text
alu_start = thread_en
```

For an LSU instruction:

```text
lsu_start = thread_en
```

For an immediate register-write instruction:

```text
reg_wen = thread_en
```

---

# Execution Flow

Each instruction follows the shared control FSM.

## 1. FETCH

The Fetcher reads the instruction located at the current PC.

## 2. DECODE

The Decoder determines the instruction type and required operands/control signals.

## 3. REQUEST

The Scheduler activates the required execution units for the active threads.

Example:

```text
ADD
alu_start = thread_en
```

```text
LDR
lsu_start = thread_en
```

```text
CONST
reg_wen = thread_en
```

## 4. WAIT

The Scheduler waits for the required execution units to complete.

## 5. EXECUTE

The active ALUs and/or LSUs perform their operations.

## 6. UPDATE

Results are written back to the appropriate register files and the PC is updated.

---

# GPU Core Organization

Each GPU Core contains two Blocks.

```text
                    GPU CORE
                       │
             ┌─────────┴─────────┐
             │                   │
          BLOCK 0             BLOCK 1
             │                   │
         8 Threads           8 Threads
             │                   │
             └─────────┬─────────┘
                       │
                    16 Threads
                       │
                    L1 Cache
```

Each Core therefore contains:

```text
2 Blocks × 8 Threads = 16 Threads
```

Across the complete GPU:

```text
4 Cores × 16 Threads = 64 Threads
```

The `GPU_CORE` distributes the shared control signals to its two blocks and aggregates their completion information.

---

# GPU Block

Each Block contains exactly 8 hardware threads.

```text
┌─────────────────────────┐
│ Thread 0                │
│ Thread 1                │
│ Thread 2                │
│ Thread 3                │
│ Thread 4                │
│ Thread 5                │
│ Thread 6                │
│ Thread 7                │
└─────────────────────────┘
```

Shared instruction-level signals are broadcast to all threads.

Thread-specific signals are distributed through bit slicing.

For example:

```text
alu_start[7:0]
```

maps to:

```text
alu_start[0] → Thread 0
alu_start[1] → Thread 1
...
alu_start[7] → Thread 7
```

The same principle applies to:

* LSU enables
* Register write enables
* Thread IDs
* Memory addresses
* Memory data
* Completion signals

---

# GPU Thread

The Thread is the fundamental execution unit.

Each thread contains:

```text
              GPU THREAD
                   │
       ┌───────────┼───────────┐
       │           │           │
       ▼           ▼           ▼
  Register        ALU         LSU
    File           │           │
       │           │           │
       └──────┬────┴─────┬─────┘
              │          │
              ▼          ▼
             MUX       Memory
              │
              ▼
         Register File
```

Each thread contains:

* Register File
* ALU
* LSU
* Result MUX

---

# Register File

Every thread has a private register file.

```text
16 registers × 32 bits
```

The register organization is:

| Register | Purpose                   |
| -------- | ------------------------- |
| R0–R12   | General-purpose registers |
| R13      | THREAD_ID                 |
| R14      | BLOCK_ID                  |
| R15      | BLOCK_DIM                 |

The hardware context registers allow a thread to access:

* Its global thread ID
* Its block ID
* The block dimension

without requiring additional instruction operands.

---

# ALU

Each thread contains a 32-bit ALU.

Supported operations include:

```text
ADD
SUB
MUL
DIV
CMP
```

The ALU receives:

```text
A
B
ALU_OP
ALU_CMP
```

and generates:

```text
RESULT
NZP
DONE
```

The comparison operation generates:

```text
N = Negative
Z = Zero
P = Positive
```

The NZP result is used by the branch mechanism.

---

# Load/Store Unit

Each thread contains an LSU responsible for memory operations.

Supported operations:

```text
LDR
STR
```

For a load:

```text
Register File
      │
      ▼
     LSU
      │
      ▼
   L1 Cache
      │
      ▼
Memory Hierarchy
      │
      ▼
    Data
      │
      ▼
Register File
```

For a store:

```text
Register File
      │
      ▼
     LSU
      │
      ▼
   L1 Cache
      │
      ▼
 Cache Line
```

The LSU uses an FSM to control memory requests and completion.

---

# Result MUX

The Result MUX selects the value written back to the register file.

Possible sources are:

```text
ALU Result
LSU Result
Immediate
```

```text
                    ┌──────────────┐
ALU_RESULT ────────►│              │
LSU_RESULT ────────►│     MUX      ├──► Register File
IMMEDIATE ─────────►│              │
                    └──────────────┘
```

Examples:

```text
ADD   → ALU Result
LDR   → LSU Result
CONST → Immediate
```

---

# L1 Cache Architecture

Each Core contains a private L1 cache.

```text
Core 0 → L1 Cache 0
Core 1 → L1 Cache 1
Core 2 → L1 Cache 2
Core 3 → L1 Cache 3
```

Each L1 cache serves the 16 LSUs belonging to its Core.

### Cache Specifications

* Direct-Mapped
* 4 KB capacity
* 128 cache lines
* 8 words per line
* 32-bit words
* Write-Back
* Dirty-line eviction
* Round-Robin arbitration
* 16 LSU requesters per Core

### Address Format

```text
┌──────────┬─────────┬────────────┬──────────────┐
│   TAG    │  INDEX  │ WORD OFF.  │ BYTE OFFSET  │
│ 20 bits  │ 7 bits  │   3 bits   │    2 bits    │
└──────────┴─────────┴────────────┴──────────────┘
```

Cache capacity:

```text
128 lines × 8 words × 4 bytes
= 4096 bytes
= 4 KB
```

---

# L1 Cache Arbitration

Each L1 cache receives requests from 16 LSUs.

Because the cache uses a single cache pipeline, requests must be arbitrated.

```text
LSU 0 ──┐
LSU 1 ──┤
LSU 2 ──┤
LSU 3 ──┤
...     ├──► Round-Robin Arbiter ──► L1 Cache
LSU 14 ─┤
LSU 15 ─┘
```

The Round-Robin Arbiter selects one requester at a time.

The selected request is processed until completion before another request is granted.

This prevents multiple LSUs from simultaneously accessing the same cache pipeline.

---

# Cache Hit

A cache hit occurs when the requested cache line is valid and the stored tag matches the requested address.

```text
LSU
 │
 ▼
L1 Cache
 │
 ▼
Tag Check
 │
 ├── HIT
 │
 ▼
Cache Data
 │
 ▼
Response
 │
 ▼
LSU
```

A hit is serviced directly by the L1 cache without accessing the lower memory hierarchy.

---

# Cache Miss

If the requested cache line is not present:

```text
LSU
 │
 ▼
L1 Cache
 │
 ▼
MISS
 │
 ▼
Memory Controller
 │
 ▼
Data Memory
 │
 ▼
8-Word Burst
 │
 ▼
L1 Cache
 │
 ▼
Cache Line Fill
 │
 ▼
Complete Request
```

The cache FSM handles the required miss-processing stages.

---

# Write-Back Cache

The L1 caches use a **write-back policy**.

When a store modifies cached data:

```text
Cache Data
    │
    ▼
Modified
    │
    ▼
dirty = 1
```

The modified data remains inside the cache instead of immediately being written to Data Memory.

This reduces unnecessary lower-level memory traffic.

---

# Dirty-Line Eviction

When a cache miss targets a valid dirty line:

```text
New Request
    │
    ▼
Cache Miss
    │
    ▼
Dirty Victim?
    │
   YES
    │
    ▼
Write Back Old Line
    │
    ▼
Fetch New Line
    │
    ▼
Fill Cache
    │
    ▼
Complete Request
```

The dirty victim is written back before the new cache line replaces it.

Typical control flow:

```text
IDLE
 ↓
CHECK
 ↓
WRITEBACK_REQUEST
 ↓
WRITEBACK
 ↓
MEM_REQUEST
 ↓
MEM_WAIT
 ↓
FILL
 ↓
RESPOND
 ↓
IDLE
```

---

# Shared Memory Controller

All four L1 caches connect to one shared Memory Controller.

```text
             L1 Cache 0 ──┐
             L1 Cache 1 ──┤
             L1 Cache 2 ──┼──► Memory Controller
             L1 Cache 3 ──┘
                                  │
                                  ▼
                             Data Memory
```

The Memory Controller arbitrates between the four L1 caches using Round-Robin scheduling.

It tracks the owner of the active transaction so that returned memory data is routed to the correct cache.

Only one cache transaction is serviced at a time.

---

# Data Memory

Data Memory provides the backing storage beneath the L1 cache hierarchy.

For a cache-line read:

```text
Memory Controller
       │
       ▼
   Data Memory
       │
       ├── Word 0
       ├── Word 1
       ├── Word 2
       ├── Word 3
       ├── Word 4
       ├── Word 5
       ├── Word 6
       └── Word 7
```

The memory transfers one word per cycle during a cache-line burst.

For write-back operations, the cache sends the dirty line back one word at a time.

---

# Complete Memory Hierarchy

For a load instruction:

```text
Thread
  │
  ▼
LSU
  │
  ▼
L1 Cache
  │
  ├──────── HIT ─────────────► Data
  │
  └──────── MISS
                │
                ▼
        Memory Controller
                │
                ▼
           Data Memory
                │
                │ 8-word burst
                ▼
           Memory Controller
                │
                ▼
             L1 Cache
                │
                ▼
              LSU
                │
                ▼
          Register File
```

The memory hierarchy separates:

1. Thread-level memory requests
2. Core-level cache management
3. Global memory arbitration
4. Backing memory access

---

# Instruction Set Architecture

The processor uses a compact 16-bit instruction set.

| Opcode      | Instruction | Operation              |
| ----------- | ----------- | ---------------------- |
| `0000`      | NOP         | No operation           |
| `0001`      | BRnzp       | Conditional branch     |
| `0010`      | CMP         | Compare two registers  |
| `0011`      | ADD         | Integer addition       |
| `0100`      | SUB         | Integer subtraction    |
| `0101`      | MUL         | Integer multiplication |
| `0110`      | DIV         | Integer division       |
| `0111`      | LDR         | Load from memory       |
| `1000`      | STR         | Store to memory        |
| `1001`      | CONST       | Load immediate         |
| `1010–1110` | Reserved    | Unused                 |
| `1111`      | RET         | Return / end execution |

The branch mechanism uses the NZP condition generated by the comparison operation.

---

# Example: ADD Instruction

For:

```text
ADD R1, R2, R3
```

the execution sequence is:

```text
FETCH
  │
  ▼
DECODE
  │
  ├── Opcode = ADD
  ├── Source = R2
  ├── Source = R3
  └── Destination = R1
  │
  ▼
REQUEST
  │
  └── alu_start = thread_en
  │
  ▼
WAIT
  │
  ▼
EXECUTE
  │
  └── ALU performs R2 + R3
  │
  ▼
UPDATE
  │
  └── R1 ← ALU_RESULT
```

Every active thread performs its own ADD using its private register file.

---

# Example: CONST Instruction

For:

```text
CONST R1, #10
```

the ALU and LSU do not need to be activated.

The immediate value is selected directly by the Result MUX:

```text
Immediate
    │
    ▼
   MUX
    │
    ▼
Register File
```

The write enable is masked by the active-thread mask:

```text
reg_wen = thread_en
```

Only active threads update their destination register.

---

# Example: LDR Instruction

For:

```text
LDR R1, R2
```

the execution flow is:

```text
Thread
  │
  ▼
Register File
  │
  │ Address Source
  ▼
LSU
  │
  ▼
L1 Cache
  │
  ├── HIT ──► Data
  │
  └── MISS
       │
       ▼
Memory Controller
       │
       ▼
Data Memory
       │
       ▼
L1 Cache
       │
       ▼
LSU
       │
       ▼
Result MUX
       │
       ▼
Register File
       │
       ▼
R1
```

---

# Example: STR Instruction

For:

```text
STR R2, R3
```

the thread's register file provides the source data and address.

```text
Register File
     │
     ▼
    LSU
     │
     ▼
  L1 Cache
     │
     ▼
 Cache Line
     │
     ▼
 dirty = 1
```

The modified cache line remains in L1 until it is eventually evicted.

---

# Multiple Active Threads

Suppose:

```text
thread_count = 10
```

Then:

```text
thread_en = 000...0001111111111
```

For an ADD:

```text
alu_start = thread_en
```

Therefore:

```text
10 ALUs → Active
54 ALUs → Inactive
```

For an LDR:

```text
lsu_start = thread_en
```

Therefore:

```text
10 LSUs → Generate Memory Requests
54 LSUs → Inactive
```

The corresponding L1 cache arbitrates among the active LSUs.

---

# Branching

The GPU uses a shared PC, so branch decisions are handled at the shared control level.

A comparison generates:

```text
NZP = {N, Z, P}
```

The Scheduler compares the generated condition against the decoded branch condition.

If the branch condition is satisfied:

```text
branch_taken = 1
```

and:

```text
PC = Branch Target
```

Otherwise:

```text
PC = PC + 1
```

This allows the complete SIMT machine to follow a shared control-flow path.

---

# RTL Design

The project was implemented using a modular hierarchical RTL structure.

Major modules include:

```text
Thread Controller
GPU PC
GPU Fetcher
GPU Instruction Memory
GPU Decoder
Scheduler

GPU Core
GPU Block
GPU Thread

GPU ALU
GPU LSU
GPU Register File
Result MUX

L1 Cache
Memory Controller
Data Memory

GPU Top
```

The architecture is organized hierarchically:

```text
GPU
 │
 ├── Shared Control Path
 │
 ├── Core 0
 │    ├── Block 0
 │    │    └── 8 Threads
 │    └── Block 1
 │         └── 8 Threads
 │
 ├── Core 1
 │
 ├── Core 2
 │
 └── Core 3
      │
      └── L1 Cache
             │
             ▼
       Memory Controller
             │
             ▼
         Data Memory
```

---

# Verification

The GPU was verified using RTL simulation.

The verification process covers:

* Instruction execution
* Thread activation
* Register operations
* ALU operations
* Branching
* Load/Store operations
* Cache hits
* Cache misses
* Cache fills
* Write-back operations
* Dirty-line eviction
* Memory transactions
* Completion handling

Supported instruction verification includes:

```text
CONST
ADD
SUB
MUL
DIV
CMP
BRnzp
LDR
STR
RET
```

The testbench loads instruction sequences and verifies the resulting register and memory states against expected behavior.

---

# Simulation Waveforms

The following section contains representative simulation waveforms demonstrating the GPU execution and control behavior.

## Waveform 1 — 

> **Waveform Image 1 

<img width="1911" height="733" alt="wave_diagram_0" src="https://github.com/user-attachments/assets/1bffbb79-e1f1-46ed-ae25-c35b97f06a28" />

---

## Waveform 2 —

> **Waveform Image 2 

<img width="1901" height="729" alt="wave_diagram_1" src="https://github.com/user-attachments/assets/3812b005-b2eb-41d1-add9-6fd2d99a972c" />


---

# Elaborated Design

The elaborated RTL design demonstrates the complete hierarchy generated from the Verilog source.



<img width="1530" height="589" alt="Elaborated" src="https://github.com/user-attachments/assets/826ae899-61d4-4113-9d14-859ee29db672" />


The elaborated hierarchy provides a structural view of how the RTL modules are instantiated and connected across:

```text
GPU
 ├── Control Path
 ├── Cores
 ├── Blocks
 ├── Threads
 ├── L1 Caches
 ├── Memory Controller
 └── Data Memory
```

---

# Synthesis Design

The synthesis result provides a hardware-oriented view of the implemented RTL after synthesis.



<img width="1533" height="789" alt="Synthesis" src="https://github.com/user-attachments/assets/c73a2405-3f62-4190-9bc8-924092c0e820" />

The synthesis view is useful for inspecting:

* RTL-to-hardware transformation
* Module hierarchy
* Hardware connectivity
* Resource mapping
* Synthesized structure

---

# Design Challenges

Several non-trivial RTL and microarchitectural problems were addressed during development.

## 1. Thread Masking

The architecture required independent enable control for all 64 threads while maintaining one shared instruction stream.

## 2. Hierarchical Organization

The design required coordination across:

```text
Thread
   ↓
Block
   ↓
Core
   ↓
L1 Cache
   ↓
Memory Controller
   ↓
Data Memory
```

## 3. Cache Arbitration

Multiple LSUs can generate memory requests simultaneously, requiring arbitration inside every L1 cache.

## 4. Dirty-Line Eviction

The write-back cache must preserve modified data before replacing a dirty cache line.

## 5. Shared Memory Arbitration

Four independent L1 caches share a single Memory Controller, requiring global arbitration.

## 6. Completion Tracking

Because memory requests are serialized through the cache and memory hierarchy, active threads may not complete simultaneously.

The control logic therefore needs to track completion correctly before advancing to the next instruction.

---

# Why This Project Is Interesting

This project goes beyond a basic ALU, single-thread processor, or simple cache implementation.

It combines multiple digital design concepts into one integrated hardware system:

```text
                         SIMT Execution
                              │
                              ▼
                       Multi-Core GPU
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
           Parallel ALUs             Parallel LSUs
                 │                         │
                 │                      L1 Cache
                 │                         │
                 │                  Memory Controller
                 │                         │
                 └──────────────┬──────────┘
                                ▼
                           Data Memory
```

The project provides practical experience with:

* RTL architecture
* Hierarchical hardware design
* SIMT execution
* Parallel processing
* FSM design
* Datapath and control-path design
* Register-file architecture
* Load/Store units
* Cache architecture
* Write-back caching
* Arbitration
* Memory systems
* Hardware verification

---

# Project Structure

A recommended repository organization is:

```text
SIMT-GPGPU/
│
├── rtl/
│   ├── gpu_top.v
│   ├── scheduler.v
│   ├── thread_controller.v
│   ├── gpu_pc.v
│   ├── gpu_fetcher.v
│   ├── gpu_inst_mem.v
│   ├── gpu_decoder.v
│   │
│   ├── gpu_core.v
│   ├── gpu_block.v
│   ├── gpu_thread.v
│   ├── gpu_alu.v
│   ├── gpu_lsu.v
│   ├── gpu_reg_file.v
│   ├── mux.v
│   │
│   ├── l1_cache.v
│   ├── memory_controller.v
│   └── data_memory.v
│
├── tb/
│   └── tb_gpu_top.v
│
├── docs/
│   └── images/
│       ├── architecture.png
│       ├── waveform_execution.png
│       ├── waveform_memory.png
│       ├── elaborated_design.png
│       └── synthesis_design.png
│
└── README.md
```

---

# Key Architectural Parameters

The architecture uses configurable parameters to support future experimentation.

Important parameters include:

```text
DATA_WIDTH
ADDR_WIDTH
BLOCK_DIM
no_thread
no_blocks
DEPTH
LINE_WORDS
NUM_LINES
INDEX_WIDTH
TAG_WIDTH
```

Current configuration:

```text
DATA_WIDTH  = 32
ADDR_WIDTH  = 32
BLOCK_DIM   = 8
Threads     = 64
Cores       = 4
Blocks/Core = 2
Registers   = 16
Line Words  = 8
Cache Lines = 128
```

This parameterized structure provides a foundation for experimenting with different GPU organizations and memory-system configurations.

---

# Current Architecture Summary

```text
                         SIMT GPGPU
                             │
              ┌──────────────┴──────────────┐
              │       Shared Control        │
              │                              │
              │ Thread Controller            │
              │ Scheduler                    │
              │ PC                           │
              │ Fetcher                      │
              │ Decoder                      │
              │ Instruction Memory           │
              └──────────────┬──────────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       │                     │                     │
       ▼                     ▼                     ▼
    CORE 0                CORE 1                CORE 2                CORE 3
       │                     │                     │                     │
   2 Blocks               2 Blocks              2 Blocks              2 Blocks
       │                     │                     │                     │
  16 Threads             16 Threads            16 Threads            16 Threads
       │                     │                     │                     │
   L1 Cache               L1 Cache              L1 Cache              L1 Cache
       │                     │                     │                     │
       └─────────────────────┴─────────────────────┴─────────────────────┘
                                   │
                                   ▼
                          Memory Controller
                                   │
                                   ▼
                              Data Memory
```

---

# Future Improvements

Possible future extensions include:

* More advanced cache associativity
* Non-blocking cache architecture
* Multiple outstanding memory transactions
* Cache coherence mechanisms
* Shared L2 cache
* More sophisticated warp scheduling
* Independent warp/program counters
* Better branch divergence handling
* Operand forwarding
* Pipeline execution
* Instruction-level parallelism
* Advanced memory scheduling
* AXI / AXI4 interfaces
* FPGA implementation
* Timing analysis
* Formal verification
* Synthesis resource utilization analysis

---

# Author

## Ziad Mohamed

Electrical Engineering — Electronics & Communications Engineering

### Focus Areas

* Digital IC Design
* RTL Design
* Computer Architecture
* GPU Microarchitecture
* Hardware Verification
* FPGA Design
* AI Hardware & Accelerators

---

# Project Highlights

```text
64 Hardware Threads
4 GPU Cores
8 Blocks
16 Threads / Core
8 Threads / Block
32-bit Datapath
16-bit ISA
Private 4 KB L1 Cache / Core
Write-Back Cache
128 Cache Lines / Core
8 Words / Cache Line
Round-Robin Arbitration
Shared Memory Controller
Shared Data Memory
Verilog RTL
Simulation-Based Verification
```

---

## Final Architecture

The resulting system combines a shared SIMT control path with a hierarchical parallel execution and memory architecture:

```text
                         ┌─────────────────────────┐
                         │       SIMT GPGPU        │
                         │                         │
                         │  Thread Controller      │
                         │  Scheduler              │
                         │  PC                     │
                         │  Fetcher                │
                         │  Decoder                │
                         │  Instruction Memory     │
                         └────────────┬────────────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            │                         │                         │
            ▼                         ▼                         ▼
        ┌────────┐                ┌────────┐                ┌────────┐
        │ CORE 0 │                │ CORE 1 │       ...      │ CORE 3 │
        └───┬────┘                └───┬────┘                └───┬────┘
            │                         │                         │
       2 Blocks                  2 Blocks                  2 Blocks
            │                         │                         │
      16 Threads                 16 Threads                 16 Threads
            │                         │                         │
        L1 Cache                  L1 Cache                  L1 Cache
            │                         │                         │
            └─────────────────────────┼─────────────────────────┘
                                      │
                                      ▼
                              Memory Controller
                                      │
                                      ▼
                                 Data Memory
```

**SIMT GPGPU** demonstrates a complete RTL-level exploration of GPU architecture, combining **parallel execution, hierarchical organization, cache systems, memory arbitration, and hardware control** into a single custom-designed processor.
