# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

DEBOUNCE = 12

async def do_reset(dut):
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0
    dut.ena.value    = 1
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 50)

async def press_key(dut, col_idx, row_idx):
    col_map = {0: 0b1110, 1: 0b1101, 2: 0b1011, 3: 0b0111}
    row_map = {0: 0b1110, 1: 0b1101, 2: 0b1011, 3: 0b0111}

    want_col = col_map[col_idx]
    row_val  = row_map[row_idx]

    dut.ui_in.value = 0xFF
    for _ in range(500):
        await RisingEdge(dut.clk)
        if (dut.uio_out.value & 0xF) == want_col:
            break

    dut.ui_in.value = 0xF0 | row_val
    await ClockCycles(dut.clk, DEBOUNCE)
    dut.ui_in.value = 0xFF
    await ClockCycles(dut.clk, DEBOUNCE)


async def press_digit(dut, d):
    if   d == 1: await press_key(dut, col_idx=0, row_idx=0)
    elif d == 2: await press_key(dut, col_idx=1, row_idx=0)
    elif d == 3: await press_key(dut, col_idx=2, row_idx=0)
    elif d == 4: await press_key(dut, col_idx=0, row_idx=1)
    elif d == 5: await press_key(dut, col_idx=1, row_idx=1)
    elif d == 6: await press_key(dut, col_idx=2, row_idx=1)
    elif d == 7: await press_key(dut, col_idx=0, row_idx=2)
    elif d == 8: await press_key(dut, col_idx=1, row_idx=2)
    elif d == 9: await press_key(dut, col_idx=2, row_idx=2)
    elif d == 0: await press_key(dut, col_idx=1, row_idx=3)

async def press_add(dut): await press_key(dut, col_idx=3, row_idx=0)
async def press_sub(dut): await press_key(dut, col_idx=3, row_idx=1)
async def press_mul(dut): await press_key(dut, col_idx=3, row_idx=2)
async def press_div(dut): await press_key(dut, col_idx=3, row_idx=3)
async def press_eq(dut):  await press_key(dut, col_idx=2, row_idx=3)

@cocotb.test()
async def test_project(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0
    dut.ena.value    = 1
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 100)

    try:
        val = int(dut.uo_out.value)
        dut._log.info(f"output after reset: {val}")
    except Exception:
        dut._log.warning("output still X after reset, continuing anyway")

    await do_reset(dut)
    await press_digit(dut, 7)
    await press_add(dut)
    await press_digit(dut, 5)
    await press_eq(dut)
    await ClockCycles(dut.clk, 20)

    dut._log.info("gate level smoke test complete")