"""Offline tests; run after both P4 console ELFs have been built and packaged."""
import hashlib
from pathlib import Path
import runpy
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
validate = runpy.run_path(str(ROOT / "tools/check-p4-console-image"))["validate"]


class ConsoleImageTests(unittest.TestCase):
    def test_layouts_and_corruption(self):
        for layout in (1, 3):
            prefix = ROOT / f"build/p4-internal-console/layout-{layout}/application"
            elf = prefix.with_suffix(".elf").read_bytes()
            image = prefix.with_suffix(".bin").read_bytes()
            validate(elf, image, layout)
            with self.assertRaises(ValueError):
                validate(elf, image, 4 - layout)
            for length in range(len(image)):
                with self.assertRaises((ValueError, struct.error)):
                    validate(elf, image[:length], layout)
            for offset in (0, 1, 4, 12, 15, 17, 23, 24, 28, 32, len(image) - 33, len(image) - 1):
                corrupt = bytearray(image)
                corrupt[offset] ^= 1
                with self.assertRaises(ValueError):
                    validate(elf, corrupt, layout)
            # A validly checksummed but changed payload must fail ELF equivalence.
            corrupt = bytearray(image)
            corrupt[32] ^= 1
            corrupt[-33] ^= 1
            corrupt[-32:] = hashlib.sha256(corrupt[:-32]).digest()
            with self.assertRaisesRegex(ValueError, "differ from ELF"):
                validate(elf, corrupt, layout)
            with self.assertRaises(ValueError):
                validate(elf, image + b"\0", layout)
            # A moved reservation must fail even if no bytes are loaded there.
            corrupt_elf = bytearray(elf)
            phoff = struct.unpack_from("<I", elf, 28)[0]
            count = struct.unpack_from("<H", elf, 44)[0]
            for index in range(count):
                header = phoff + index * 32
                tag = struct.unpack_from("<I", elf, header)[0]
                size, reserved = struct.unpack_from("<II", elf, header + 16)
                if tag == 1 and size == 0 and reserved:
                    struct.pack_into("<II", corrupt_elf, header + 8, 0x4ff30000, 0x4ff30000)
                    break
            else:
                self.fail("missing stack reservation in fixture")
            with self.assertRaisesRegex(ValueError, "outside selected RAM"):
                validate(corrupt_elf, image, layout)


if __name__ == "__main__":
    unittest.main()
