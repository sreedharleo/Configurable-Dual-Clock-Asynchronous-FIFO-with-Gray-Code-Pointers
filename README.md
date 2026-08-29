Asynchronous FIFO – RTL Design to Physical Implementation
📌 Project Overview

This project implements a parameterized Asynchronous FIFO (First-In First-Out) for reliable data transfer between two independent clock domains.

Unlike a synchronous FIFO, an asynchronous FIFO operates with separate clocks for the write and read sides:

wr_clk → Write clock domain
rd_clk → Read clock domain

The main objective of this project is to design, verify, synthesize, and physically implement an asynchronous FIFO while safely handling Clock Domain Crossing (CDC).

The project covers the complete digital design flow:

RTL Design
    ↓
Functional Verification
    ↓
Simulation / Waveform Analysis
    ↓
Logic Synthesis
    ↓
Floorplanning
    ↓
Placement
    ↓
Clock Tree Synthesis
    ↓
Global Routing
    ↓
Detailed Routing
    ↓
Static Timing Analysis
    ↓
Power Analysis
    ↓
Physical Verification
    ↓
Final GDSII
🎯 Project Objectives

The main objectives of this project are:

Design an asynchronous FIFO using Verilog HDL.
Transfer data safely between two independent clock domains.
Implement Clock Domain Crossing using Gray-coded pointers.
Use two-flip-flop synchronizers to reduce metastability propagation.
Generate FIFO status signals such as:
full
empty
almost_full
almost_empty
Verify the functionality using a dedicated testbench.
Analyze simulation waveforms using GTKWave.
Perform RTL synthesis using the OpenLane/OpenROAD flow.
Perform physical design including:
Floorplanning
Placement
CTS
Routing
Perform Static Timing Analysis (STA).
Perform power analysis.
Perform final physical verification and generate the final GDSII output.
🏗️ Why Asynchronous FIFO?

In modern SoCs and digital systems, different blocks may operate at different clock frequencies.

For example:

             Clock Domain 1
                wr_clk
                   │
                   ▼
              Write Logic
                   │
                   ▼
              ┌─────────┐
              │   FIFO  │
              │ Memory  │
              └─────────┘
                   │
                   ▼
              Read Logic
                   │
                   ▼
                rd_clk
             Clock Domain 2

Directly transferring control signals between unrelated clock domains can cause metastability and incorrect data/control behavior.

An asynchronous FIFO provides a controlled mechanism for transferring data between these independent clock domains.

🔄 Clock Domain Crossing (CDC)

CDC is one of the most important concepts in this project.

The write and read sides use independent clocks:

Write Domain                    Read Domain

  wr_clk                          rd_clk
    │                               │
    ▼                               ▼
Write Pointer                   Read Pointer
    │                               │
    ▼                               ▼
Binary → Gray                   Binary → Gray
    │                               │
    ▼                               ▼
  2-FF Synchronizer             2-FF Synchronizer
    │                               │
    ▼                               ▼
Read Domain                    Write Domain
Important point

The FIFO data itself is not passed through the 2-FF synchronizer.

The FIFO memory stores the actual data.

The information crossing the clock domains is mainly the read and write pointer information.

🧠 Why Gray Code is Used

The binary read and write pointers are converted into Gray code before crossing the clock domain.

The main advantage is that only one bit changes between consecutive Gray-code values.

For example:

Binary       Gray

000          000
001          001
010          011
011          010

This makes pointer synchronization safer when crossing between asynchronous clock domains.

Therefore:

Binary Pointer
      ↓
Gray Code Conversion
      ↓
2-FF Synchronizer
      ↓
Receiving Clock Domain
🔐 Two Flip-Flop Synchronizer

A two-flip-flop synchronizer is used to reduce the probability of metastability propagating into the receiving clock domain.

Asynchronous Signal
        │
        ▼
     ┌─────┐
     │ FF1 │
     └─────┘
        │
        ▼
     ┌─────┐
     │ FF2 │
     └─────┘
        │
        ▼
Receiving Domain

The first flip-flop may experience metastability if the incoming signal changes close to the receiving clock edge.

The second flip-flop provides additional settling time before the signal is used by the receiving logic.

Purpose

The purpose of the 2-FF synchronizer is to reduce the probability of metastability propagating into the receiving clock domain.

It does not mathematically eliminate metastability.

🧩 FIFO Architecture

The design consists of the following major blocks:

                         ASYNCHRONOUS FIFO
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
        WRITE CLOCK DOMAIN                  READ CLOCK DOMAIN
              │                                   │
            wr_clk                               rd_clk
              │                                   │
              ▼                                   ▼
       Write Pointer                         Read Pointer
              │                                   │
              ▼                                   ▼
       Binary → Gray                          Binary → Gray
              │                                   │
              ▼                                   ▼
       2-FF Synchronizer ◄────────────────► 2-FF Synchronizer
              │                                   │
              ▼                                   ▼
        Full Detection                       Empty Detection
              │                                   │
              └──────────────┬────────────────────┘
                             │
                             ▼
                       FIFO MEMORY
                             │
                       ┌─────┴─────┐
                       │           │
                  Write Data    Read Data
✍️ RTL Design

The FIFO RTL is written in Verilog HDL.

The design contains the main logic required for:

FIFO memory
Write pointer generation
Read pointer generation
Binary-to-Gray conversion
Pointer synchronization
Full detection
Empty detection
Almost-full detection
Almost-empty detection
📝 Write Operation

During a write operation:

wr_en = 1

and the FIFO is not full.

The input data is written into the FIFO memory.

Conceptually:

write_data
    │
    ▼
FIFO Memory
    │
    ▼
Write Address

The write pointer then advances to the next FIFO location.

The binary write pointer is also converted to Gray code for CDC.

📖 Read Operation

During a read operation:

rd_en = 1

and the FIFO is not empty.

The data stored at the current read location is read from the FIFO memory.

The read pointer then advances to the next location.

The read pointer is converted into Gray code before crossing into the write clock domain.

🚫 Full Detection

The write side needs to know whether there is enough space to accept another data word.

The synchronized read pointer is used by the write domain for full detection.

When the FIFO reaches its maximum capacity:

full = 1

Further write operations are prevented.

📭 Empty Detection

The read side needs to know whether valid data is available.

The synchronized write pointer is used by the read domain for empty detection.

When there is no unread data:

empty = 1

Further read operations are prevented.

⚠️ Almost-Full and Almost-Empty

The design also implements early warning status signals.

Almost Full

Indicates that the FIFO is approaching its maximum capacity.

Almost Empty

Indicates that the FIFO is approaching the empty condition.

These signals can be useful for controlling data flow before the FIFO reaches a critical condition.

🧪 Functional Verification

A dedicated testbench was developed to verify the FIFO functionality.

The testbench verifies:

Write operations
Read operations
Different clock domains
FIFO full condition
FIFO empty condition
Almost-full condition
Almost-empty condition
Data integrity
Pointer operation

The simulation was checked for incorrect behavior and data mismatches.

Final Functional Test Result
Total Writes : 12
Total Reads  : 10
Errors       : 0

Result       : ALL TESTS PASSED
📊 Simulation and Waveform Analysis

The design was simulated and the resulting signals were analyzed using GTKWave.

Important signals observed include:

wr_clk
rd_clk
wr_en
rd_en
write_data
read_data
full
empty
almost_full
almost_empty
write_pointer
read_pointer

The waveform confirms that the FIFO performs read and write operations correctly under independent clock domains.

🏭 RTL-to-GDSII Physical Design Flow

After functional verification, the design was taken through the physical implementation flow.

The physical design was performed using the OpenLane/OpenROAD environment with the SkyWater SKY130 technology.

Technology
PDK              : sky130A
Standard Cell    : sky130_fd_sc_hd
Clock            : wr_clk
Clock Period     : 10 ns
1️⃣ Floorplanning

The first major physical-design stage is floorplanning.

The floorplan defines:

Die area
Core area
Aspect ratio
Placement region
Standard-cell rows
Power structure

The final design reports:

Die Area  : 24543.4
Core Area : 19462.4
2️⃣ Placement

During placement, the synthesized standard cells are positioned inside the core area.

The objective is to achieve:

Efficient cell placement
Good timing
Reasonable routing congestion
Appropriate utilization

The reported standard-cell utilization is approximately:

51.46%
3️⃣ Clock Tree Synthesis

Clock Tree Synthesis (CTS) creates a clock distribution network.

The objective is to distribute the clock to sequential elements while controlling:

Clock skew
Clock latency
Timing

CTS was completed as part of the physical implementation flow.

4️⃣ Routing

Routing connects the placed cells using metal layers and vias.

The project completed:

Global routing
Detailed routing
Antenna repair

The final report shows:

Antenna Violations = 0
⏱️ Static Timing Analysis (STA)

Static Timing Analysis was performed after physical implementation.

The design was checked for:

Setup timing
Hold timing
WNS
TNS
Timing violations

Final timing metrics show:

Setup WNS = 0
Setup TNS = 0

Hold WNS  = 0
Hold TNS  = 0

Setup Violations = 0
Hold Violations  = 0

The timing results indicate that no setup or hold timing violations were reported in the final metrics.

⚡ Power Analysis

Power analysis was performed for multiple PVT corners.

Power is divided into:

Internal power
Switching power
Leakage power
Total power

Example final reported power:

Internal Power   ≈ 2.594 mW
Switching Power  ≈ 1.185 mW
Leakage Power    ≈ 0.000011 mW

Total Power      ≈ 3.779 mW

The project also generated power reports for multiple PVT corners.

🔌 Power Grid Verification

The power distribution network was checked for power-grid violations.

Final metrics:

VPWR Violations = 0
VGND Violations = 0
Power Grid Violations = 0

The reported worst power-grid drop was approximately:

Worst Drop ≈ 2.21 mV
📐 Physical Verification

The final physical implementation was checked for major physical-design issues.

Final results include:

Design Violations          = 0
Antenna Violations         = 0
Power Grid Violations      = 0
Setup Violations           = 0
Hold Violations            = 0

There are still reported maximum fanout and maximum slew counts in the metrics:

Max Fanout Violations = 8
Max Slew Violations   = 9

These should be reported transparently rather than claiming that every design-rule metric is zero.

📦 Final Design Outputs

The completed physical-design run generated the following important outputs:

final/
├── def/
├── gds/
├── klayout_gds/
├── lef/
├── lib/
├── mag/
├── mag_gds/
├── metrics.csv
├── metrics.json
├── nl/
├── odb/
├── pnl/
├── sdc/
├── sdf/
├── spef/
├── spice/
└── vh/
Important files
File	Purpose
.gds	Final layout database for fabrication
.def	Physical design description
.lef	Layout abstract
.lib	Timing/power library information
.sdc	Timing constraints
.sdf	Timing annotation
.spef	Parasitic information
.spice	Extracted circuit representation
.odb	OpenROAD database
metrics.csv	Final design metrics
metrics.json	Machine-readable metrics
🛠️ Tools Used
Tool	Purpose
Verilog HDL	RTL design
Simulation/Testbench	Functional verification
GTKWave	Waveform analysis
OpenLane/OpenROAD	RTL-to-physical-design flow
SkyWater SKY130	Target PDK
Magic/KLayout	Physical/layout inspection and verification
STA tools in the flow	Timing analysis
Git/GitHub	Version control and project showcase
📈 Final Project Results
Parameter	Result
Clock Period	10 ns
Die Area	24543.4
Core Area	19462.4
Standard Cell Utilization	~51.46%
Total Power	~3.779 mW
Setup WNS	0
Setup TNS	0
Hold WNS	0
Hold TNS	0
Setup Violations	0
Hold Violations	0
Antenna Violations	0
Power Grid Violations	0
Overall Design Violations	0
Max Fanout Violations	8
Max Slew Violations	9
📸 Recommended GitHub Screenshots

The following screenshots should be included in the repository to demonstrate the complete implementation:

1. RTL Code

Show:

src/async_fifo.v
2. Testbench

Show the FIFO testbench and verification environment.

3. Simulation Result

Show:

ALL TESTS PASSED
12 Writes
10 Reads
0 Errors
4. GTKWave

Show the read/write clocks, data, enable signals, pointers and FIFO status signals.

5. Floorplan

Show the OpenROAD floorplan GUI.

6. Placement

Show the placed standard cells.

7. CTS

Show the clock tree implementation.

8. Routing

Show the routed design with metal interconnects.

9. Final Layout

Show the final GDS/layout view.

10. STA

Show the timing report containing:

Setup Violations = 0
Hold Violations  = 0
WNS = 0
TNS = 0
11. Power Analysis

Show the power report and total power.

12. Final Metrics

Show metrics.csv or metrics.json.

🚀 Project Flow Summary
                 ASYNC FIFO RTL
                       │
                       ▼
              Functional Verification
                       │
                       ▼
                  GTKWave
                       │
                       ▼
                    Synthesis
                       │
                       ▼
                  Floorplanning
                       │
                       ▼
                    Placement
                       │
                       ▼
                       CTS
                       │
                       ▼
                  Global Routing
                       │
                       ▼
                 Detailed Routing
                       │
                       ▼
                Antenna Repair
                       │
                       ▼
                    STA
                       │
                       ▼
                Power Analysis
                       │
                       ▼
             Physical Verification
                       │
                       ▼
                  Final GDSII
🎓 Key Technical Concepts Demonstrated

This project demonstrates practical understanding of:

Asynchronous FIFO architecture
Clock Domain Crossing
Metastability
Two-flip-flop synchronizers
Gray-code pointers
FIFO full/empty detection
Almost-full/almost-empty detection
RTL coding
Functional verification
Waveform debugging
Logic synthesis
Floorplanning
Standard-cell placement
Clock Tree Synthesis
Global and detailed routing
Static Timing Analysis
Setup and hold analysis
Power analysis
Power-grid verification
Antenna verification
RTL-to-GDSII implementation
👨‍💻 Conclusion

The project successfully demonstrates the implementation of an Asynchronous FIFO from RTL design through physical implementation.

The design uses independent write and read clock domains, with Gray-coded pointers and two-flip-flop synchronizers to safely handle clock-domain crossing.

Functional verification completed successfully with zero simulation errors. The design was then taken through synthesis, floorplanning, placement, CTS, routing, timing analysis, power analysis, and physical verification.

The final implementation generated the required physical-design outputs including DEF, GDS, LEF, SPEF, SDF, SPICE and OpenROAD database files.

Overall, this project demonstrates a complete practical RTL-to-GDSII digital design flow for an asynchronous FIFO, with particular focus on safe clock-domain crossing and physical implementation.
