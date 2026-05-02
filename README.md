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
equivalent). The keypad has 4 row pins and 4 col
