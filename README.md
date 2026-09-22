# Custom VHDL On-Chip Logic Analyzer & Debugger Core (OSTDC)

A custom VHDL-based On-Chip Signal Trace & Debug Core (OSTDC) designed for Intel Cyclone V FPGAs. The system captures live hardware signals into inferred M10K Block RAM (BRAM) when a user-defined hardware trigger condition is met, and exposes control/trace readout over an Avalon Memory-Mapped (Avalon-MM) slave interface via an Intel JTAG-to-Avalon Master Bridge.

---

### Core Features
* Register-mapped control, status, trigger configuration, and trace buffer readout using custom Avalon-MM Slave Interface.
* High-speed trace logging with zero CPU overhead using block RAM primitives (`no_rw_check`) usnig inferred M10K BRAM Buffer.
* Real-time single-cycle pattern matcher on external/internal probe lines.
* Tcl automation for System Console to arm, monitor, and dump trace memory directly to CSV files.

---

## Required Software

1. Intel Quartus Prime Lite Edition (v20.1 or higher)
2. Intel USB-Blaster II Drivers
   * Included with Quartus Prime Lite installation (`quartus/drivers/usb-blaster-ii`).

---

## Hardware Connections (Terasic DE10-Standard)
   
> The top-level entity (`ostdc_top.vhd`) maps the physical toggle switches (`SW[9:0]`) to `probe_inputs_export`.

---

## Register Map

| Offset | Register Name | R/W | Bit Description |
| :---: | :--- | :---: | :--- |
| `0x00` | **REG_STATUS / REG_CONTROL** | R/W | [Write] Bit 0: Arm, Bit 1: Soft Reset<br>[Read] Bit 0: Armed, Bit 1: Triggered, Bit 2: Buffer Full |
| `0x04` | **REG_TRIGGER** | R/W | `[31:0]` Hardware Trigger Pattern Matcher |
| `0x08` | **REG_BUFFER** | R | `[31:0]` Auto-incrementing readout port for M10K Trace RAM |
| `0x0C` | **REG_DEPTH** | R | `[31:0]` Total buffer depth capacity |

---

## How to Flash the Board (Quartus Programmer)

1. Open **Quartus Prime Lite**.
2. Open the project (`ostdc.qpf`) and compile the top-level entity (**Ctrl+L**).
3. Open **Tools > Programmer**.
4. Click **Hardware Setup...** at the top left, select **DE10-Standard [USB-1]**, and click **Close**.
5. Click **Auto Detect** on the left toolbar.
6. When prompted to select the target device variant, explicitly choose **`5CSXFC6D6`** from the list (the Cyclone V SX device populated on the DE10-Standard board).
7. Double-click the `<none>` file entry next to the **`5CSXFC6D6`** row, navigate to the `output_files/` directory, and select **`ostdc_top.sof`**.
8. Check the **Program/Configure** checkbox for the `5CSXFC6D6` device.
9. Click **Start**. Wait for the progress bar to reach **100% (Successful)**.

---

## Running the Project & Dumping Traces via System Console

1. In Quartus Prime Lite, open **Tools > System Console**.
2. In the System Console command-line shell, navigate to the project directory and source the tcl file:
   ```tcl
   cd /path/to/project
   source scripts/debug_dump.tcl
   ```
### What the Tcl Script Does Automatically:
1. Claims the JTAG-to-Avalon Master Bridge channel cleanly.
2. Issues a soft reset (0x02) to clear previous core state.
3. Configures REG_TRIGGER to 0x000000FF.
4. Arms the capture engine (0x01).
5. Polls REG_STATUS until the trigger condition matches.
6. Flip physical toggle switches SW[7:0] UP on the DE10-Standard board to match 0x000000FF.
7. Reads out the recorded samples from M10K BRAM and saves the trace to trace_dump.csv.