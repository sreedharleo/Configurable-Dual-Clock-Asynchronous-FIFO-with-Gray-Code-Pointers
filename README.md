This project implements an **Asynchronous FIFO (First-In First-Out)** for reliable data transfer between two independent clock domains.

The design uses **binary and Gray-code pointers, clock-domain synchronizers, and Full/Empty flag generation** to ensure safe and reliable clock-domain crossing (CDC).

The project covers the complete **RTL-to-GDSII flow**, from RTL design and functional verification to synthesis, physical implementation, and timing verification.



## Objectives

- Design an asynchronous FIFO for independent read and write clocks.
- Enable reliable data transfer between different clock domains.
- Prevent data corruption and reduce metastability during CDC.
- Implement accurate FIFO **Full and Empty** detection.
- Use Gray-code pointers for safe clock-domain crossing.
- Verify FIFO functionality through simulation.
- Perform synthesis and physical implementation.
- Verify setup and hold timing.
- Generate the final physical design output.

---

## FIFO Architecture

The asynchronous FIFO consists of the following major blocks:

- **FIFO Memory** – Stores the data.
- **Write Logic** – Controls data writing using the write clock.
- **Read Logic** – Controls data reading using the read clock.
- **Write Pointer** – Tracks the write position.
- **Read Pointer** – Tracks the read position.
- **Binary-to-Gray Conversion** – Converts pointers for safe CDC.
- **Synchronizers** – Transfers pointer information between clock domains.
- **Full Flag Logic** – Indicates when the FIFO is full.
- **Empty Flag Logic** – Indicates when the FIFO is empty.

### Basic Architecture

```text
                 WRITE CLOCK DOMAIN
                        |
                  Write Pointer
                        |
                  Binary → Gray
                        |
                   Synchronizer
                        |
                        v
                  READ CLOCK DOMAIN


DATA IN  ───────>  FIFO MEMORY  ───────>  DATA OUT


                 READ CLOCK DOMAIN
                        |
                   Read Pointer
                        |
                  Binary → Gray
                        |
                   Synchronizer
                        |
                        v
                 WRITE CLOCK DOMAIN
<img width="1600" height="850" alt="WhatsApp Image 2026-08-29 at 08 46 53" src="https://github.com/user-attachments/assets/040a4c1a-50f7-42a8-985f-7af83b42d510" />
GTKWave Functional Simulation

The functional behavior of the asynchronous FIFO was verified using **GTKWave**. The waveform shown below is generated from the FIFO simulation (`async_fifo.vcd`) and covers approximately **0 ns to 821 ns** of simulation time.

The waveform demonstrates the independent operation of the read and write clock domains, FIFO pointer movement, Gray-code conversion, pointer synchronization, FIFO status flags, and data transfer.

### GTKWave Waveform

The simulation waveform contains signals from the asynchronous FIFO testbench and DUT, including:

- Write clock and read clock
- Write enable and read enable
- Write data and read data
- Binary write pointer
- Binary read pointer
- Gray-coded write pointer
- Gray-coded read pointer
- Synchronized Gray-coded pointers
- FIFO write/read counters
- FULL and EMPTY flags
- Almost-FULL and Almost-EMPTY flags
- Programmable threshold values
- Reset signal

### Important Signals Observed

#### 1. Independent Clock Domains

The waveform contains two independent clocks:

```text
wr_clk
rd_clk
