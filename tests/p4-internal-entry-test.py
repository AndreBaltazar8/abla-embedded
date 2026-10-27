"""Offline instruction-verifier regression; requires all six bring-up ELFs."""
from pathlib import Path
import runpy
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
validate = runpy.run_path(str(ROOT / "tools/check-p4-internal-entry"))["validate"]


class EntryTests(unittest.TestCase):
    def test_both_applications_and_layouts(self):
        for application in ("p4-internal-console", "tab5-control-bringup", "tab5-panel-bringup"):
            for layout in (1, 3):
                elf = (ROOT / f"build/{application}/layout-{layout}/application.elf").read_bytes()
                validate(elf)
                entry, phoff = struct.unpack_from("<II", elf, 24)
                count = struct.unpack_from("<H", elf, 44)[0]
                for index in range(count):
                    tag, offset, address, _, size, _, _, _ = struct.unpack_from("<8I", elf, phoff + index * 32)
                    if tag == 1 and address <= entry < address + size:
                        location = offset + entry - address
                        break
                else:
                    self.fail("entry has no load payload")
                # Corrupt privilege/core checks, relocations, BSS loop, call,
                # handler CSR capture, fences and magic commit independently.
                for offset in (0, 8, 24, 32, 36, 44, 52, 60, 68, 84, 92,
                               128, 140, 152, 176, 192, 204, 208):
                    mutated = bytearray(elf)
                    mutated[location + offset] ^= 1
                    with self.assertRaises(AssertionError):
                        validate(mutated)


if __name__ == "__main__":
    unittest.main()
