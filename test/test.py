# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Run the CPU and check the OUT sequence")

    # Demo program computes (3+4)=7, XORs with 9 -> 14, inverts -> 0xF1,
    # printing each result via OUT, then halts.
    expected = [7, 14, 0xF1]
    seen = []
    prev = None

    # 10 instructions x 2 cycles/instruction + margin
    for _ in range(60):
        await ClockCycles(dut.clk, 1)
        val = int(dut.uo_out.value)
        if prev is not None and val != prev:
            seen.append(val)
        prev = val

    dut._log.info(f"Observed OUT sequence: {[hex(v) for v in seen]}")
    assert seen == expected, f"Expected {expected}, got {seen}"

    # uio_out[7] is the halted flag -- confirm the CPU actually stopped
    halted = (int(dut.uio_out.value) >> 7) & 1
    assert halted == 1, "CPU did not halt as expected"

    dut._log.info("PASS: mini CPU output sequence and halt behaviour correct")
