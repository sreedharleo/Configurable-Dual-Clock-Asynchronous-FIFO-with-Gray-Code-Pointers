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
