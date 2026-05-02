![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Keypad Calculator

A hardware calculator implemented in SystemVerilog for TinyTapeout. It scans
a 4x4 matrix keypad, accepts two-digit operands, performs addition,
subtraction, multiplication, and division, and outputs the 8-bit binary
result on the assigned output pins. Results are transmitted as a
decimal string over UART.

- [Read the documentation for project](docs/info.md)

## How it works

The design has three main components:

Keypad FSM — scans the 4x4 keypad matrix by driving each column low one
at a time and reading the row inputs. When a key is detected it debounces
the signal over ~10ms and decodes the row/column combination into a key
value and type (digit, operator, equals, clear).

Calculator FSM — sequences through states to collect operand A, the
operator, operand B, and then triggers the ALU. Supports up to two-digit
operands (0-99). The result is latched and held until the next calculation
begins.

ALU — performs addition, subtraction, shift-and-add multiplication, and
iterative subtraction division on 8-bit unsigned operands.

UART transmitter — when a result is ready, transmits "Result: DDD\r\n"
at 115200 baud over uio[4]. Connect uio[4] to a USB-serial adapter to
read results in a terminal.

## Calculator operation

1. Power on or press reset once at startup
2. Enter operand A (one or two digits)
3. Press an operator key (A=+, B=-, C=*, D=/)
4. Enter operand B (one or two digits)
5. Press # (equals) to compute
6. The result appears on uo_out in binary and is printed over UART
7. Press any digit to start the next calculation — no reset needed
8. Press * (clear) at any time to reset the calculator state

Reset is only required at startup. Between calculations the * key acts
as a soft clear.

## Keypad wiring

A standard 4x4 matrix membrane keypad is required (e.g. Adafruit 419 or
equivalent). The keypad has 4 row pins and 4 col.

Rows (inputs to chip):
- ROW0  (ui_in[0]) — top row: 1, 2, 3, A
- ROW1  (ui_in[1]) — second row: 4, 5, 6, B
- ROW2  (ui_in[2]) — third row: 7, 8, 9, C
- ROW3  (ui_in[3]) — bottom row: *, 0, #, D

Columns (outputs from chip):
- COL0  (uio[0]) — left column: 1, 4, 7, *
- COL1  (uio[1]) — second column: 2, 5, 8, 0
- COL2  (uio[2]) — third column: 3, 6, 9, #
- COL3  (uio[3]) — right column: A, B, C, D

Key functions:
- 0-9 — digit input
- A — addition
- B — subtraction
- C — multiplication
- D — division
- # — equals
- * — clear
 
## Output

uo_out[7:0] carries the 8-bit binary result. uo_out[7] is the most
significant bit and uo_out[0] is the least significant bit. The result
is unsigned (0 to 255).

uio[4] is the UART TX output at 115200 baud, 8N1. Connect to a
USB-serial adapter and open a terminal at 115200 baud to see results
printed in decimal.

## Clock

The design requires a 50 MHz clock. This matches the TinyTapeout default
clock frequency. The UART baud rate will be incorrect at other frequencies.

## IO

Inputs:
- ui_in[0] — Keypad ROW0
- ui_in[1] — Keypad ROW1
- ui_in[2] — Keypad ROW2
- ui_in[3] — Keypad ROW3
- ui_in[7:4] — unused

Outputs:
- uo_out[7:0] — 8-bit result, unsigned, uo_out[7] is MSB

Bidirectional:
- uio[0] — Keypad COL0 (output)
- uio[1] — Keypad COL1 (output)
- uio[2] — Keypad COL2 (output)
- uio[3] — Keypad COL3 (output)
- uio[4] — UART TX at 115200 baud 8N1 (output)
- uio[7:5] — unused, tied to 0


## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper
than ever to get your digital and analog designs manufactured on a real chip.
To learn more and get started, visit https://tinytapeout.com.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Join the community](https://tinytapeout.com/discord)
