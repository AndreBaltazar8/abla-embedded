#!/usr/bin/env python3
import hashlib
import pathlib
import runpy
import struct
import unittest

api = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/repack-esp32-image'))
parse, repack = api['parse'], api['repack']

def original(drom_size, dram_size):
    header = bytearray(24)
    header[0], header[23] = 0xE9, 1
    struct.pack_into('<I', header, 4, 0x40080000)
    output, checksum, count = header, 0xEF, 0
    def emit(address, data):
        nonlocal checksum, count
        output.extend(struct.pack('<II', address, len(data)))
        output.extend(data)
        for value in data:
            checksum ^= value
        count += 1
    emit(0x3F400020, b'D' * drom_size)
    emit(0x3FFB0000, b'R' * dram_size)
    emit(0x40080000, b'I' * 64)
    if (len(output) + 8) % 65536 != 32:
        emit(0, bytes((32 - len(output) - 16) % 65536))
    emit(0x400D0020, b'F' * 128)
    output[1] = count
    output.extend(bytes(15 - len(output) % 16))
    output.append(checksum)
    output.extend(hashlib.sha256(output).digest())
    return bytes(output)

class RepackTests(unittest.TestCase):
    def test_page_edges_and_ram_splits(self):
        for drom in (4, 8, 16, 0xD9CC, 65500, 65504, 65508):
            for dram in (4, 8, 16, 0x2614, 16384):
                with self.subTest(drom=drom, dram=dram):
                    before = original(drom, dram)
                    after = repack(before)
                    self.assertLessEqual(len(after), len(before))
                    self.assertEqual(parse(before)[1], parse(after)[1])
                    self.assertEqual(repack(after), after)

    def test_actual_near_page_gap(self):
        before = original(0xD9CC, 0x2614)
        after = repack(before)
        # The RAM ends at0x10008: an8-byte padding payload plus8-byte header
        # must place the IROM segment header at0x10018, not0x20018.
        self.assertEqual(struct.unpack_from('<II', after, 0x10008), (0, 8))
        self.assertEqual(struct.unpack_from('<II', after, 0x10018), (0x400D0020, 128))
        self.assertGreater(len(before) - len(after), 64000)

    def test_corruption_and_trailing_signatures_rejected(self):
        valid = original(16, 16)
        for bad in (valid[:-1], valid + bytes(4096), bytes(64)):
            with self.assertRaises(ValueError):
                repack(bad)
        for offset in (0, 12, 23, 40, len(valid) - 33, len(valid) - 1):
            changed = bytearray(valid)
            changed[offset] ^= 1
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                repack(changed)

if __name__ == '__main__':
    unittest.main()
