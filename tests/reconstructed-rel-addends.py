#!/usr/bin/env python3
"""Regression for REL addends stored in Xtensa literal words."""

from pathlib import Path
import runpy


root = Path(__file__).resolve().parents[1]
reconstruct = runpy.run_path(str(root / "tools/reconstruct-xtensa-object"))
lift = runpy.run_path(str(root / "tools/lift-xtensa-leaves-to-abla"))

# GCC represents this PHY end pointer as an R_XTENSA_32 relocation against an
# anonymous rodata section while keeping the +6 REL addend in the literal word.
# BFD omits that addend from the relocation text, so reconstruction must read
# it from the section contents.
content = bytes(16) + b"\x06\x00\x00\x00"
relocations = {
    ".text.fixture": {
        0x10: ("32", ".rodata.CSWTCH$356"),
    },
}
expression = reconstruct["literal_expression"](
    ".text.fixture",
    0x10,
    {".text.fixture": content},
    relocations,
)
assert expression == ".rodata.CSWTCH$356+0x6"

# The REL rule is not specific to anonymous section symbols. If BFD presents
# a bare named target, its nonzero in-place addend has the same meaning.
assert reconstruct["data_relocation_expression"](
    "named_table", b"\x06\x00\x00\x00", 0
) == "named_table+0x6"

instruction = reconstruct["Instruction"](
    0x20,
    "l32r\ta3, 10 <fixture-0x10>",
    [],
)
recovered = reconstruct["recover_instruction"](
    "fixture",
    ".text.fixture",
    instruction,
    {".text.fixture": content},
    relocations,
)
assert recovered == (
    "movi a3, .rodata.CSWTCH$356\n"
    "addi a3, a3, 6"
)

# The structured lifter must retain the address adjustment rather than
# collapsing both iterator bounds to the same section base.
lifted = lift["lift"](
    "fixture",
    "entry a1, 32\n"
    "movi a2, .rodata.CSWTCH$356\n"
    "movi a3, .rodata.CSWTCH$356\n"
    "addi a3, a3, 6\n"
    "retw.n",
)
assert "r3 = r3 + u32(6)" in lifted.source

print("Xtensa REL addend: section base +6 survives reconstruction and lifting")
