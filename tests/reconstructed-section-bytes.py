"""Regression for PHY globals and table tails lost by objdump parsing."""

from pathlib import Path
import runpy


module = runpy.run_path(str(
    Path(__file__).resolve().parents[1] / "tools/reconstruct-xtensa-object"
))
parse = module["section_bytes"]

for size in range(1, 34):
    expected = bytes(range(size))
    lines = ["Contents of section .data:"]
    for offset in range(0, size, 16):
        row = expected[offset:offset + 16]
        groups = " ".join(row[i:i + 4].hex() for i in range(0, len(row), 4))
        lines.append(f" {offset:04x} {groups:<35}  deadbeef")
    lines.extend(["Contents of section .rodata:", " 0000 fd        ."])
    assert parse("\n".join(lines)) == {".data": expected, ".rodata": b"\xfd"}, size

try:
    module["data_section_directives"](".data.test", "test", 3, 0, b"\x01", {})
except ValueError:
    pass
else:
    raise AssertionError("Truncated initialized data must not become zero padding")

assert ".zero 3" in module["data_section_directives"](
    ".bss.test", "test", 3, 0, b"", {}
)
print("Exact section bytes: lengths 1..33; truncated initialized data rejected")
