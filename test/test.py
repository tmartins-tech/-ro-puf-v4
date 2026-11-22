# SPDX-License-Identifier: Apache-2.0
"""V4 RTL and gate-level smoke test: outputs disabled and pins safe.

Never activates a ring oscillator. Ideal combinational feedback loops are not
valid frequency simulations and may stall a zero-delay HDL simulator. This
checks the deterministic disabled/reset behavior and dual-MUX selections only.
"""
import cocotb
from cocotb.triggers import Timer


async def assert_inactive(dut, label):
    await Timer(1000, unit="ns")
    output = int(dut.uo_out.value)
    io_output = int(dut.uio_out.value)
    io_enable = int(dut.uio_oe.value)
    assert output == 0, f"{label}: expected uo_out=0x00, got 0x{output:02x}"
    assert io_output == 0, f"{label}: uio_out is not all zero"
    assert io_enable == 0, f"{label}: bidirectional pins must be inputs"


@cocotb.test()
async def test_v4_safe_disabled_reset(dut):
    dut.clk.value = 0  # No synchronous logic in this design.
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 0
    dut.rst_n.value = 0
    await assert_inactive(dut, "initial reset")

    # Reset released; RO_ENABLE=1 but TT project enable is OFF.
    dut.rst_n.value = 1
    dut.uio_in.value = 1
    for a, b in ((0, 0), (0, 15), (3, 9), (15, 0)):
        dut.ui_in.value = (b << 4) | a
        await assert_inactive(dut, f"ena=0, selectors {a}/{b}")

    # TT enable ON but local RO_ENABLE is OFF.
    dut.ena.value = 1
    dut.uio_in.value = 0
    for a, b in ((1, 3), (4, 12), (15, 15)):
        dut.ui_in.value = (b << 4) | a
        await assert_inactive(dut, f"RO_ENABLE=0, selectors {a}/{b}")

    # Reset asserted with both enables high; no ring can start.
    dut.uio_in.value = 1
    dut.rst_n.value = 0
    for a, b in ((0, 15), (7, 8), (15, 15)):
        dut.ui_in.value = (b << 4) | a
        await assert_inactive(dut, f"rst_n=0, selectors {a}/{b}")

    dut._log.info("V4 disabled/reset RTL/GL smoke test passed. Frequencies not tested.")
