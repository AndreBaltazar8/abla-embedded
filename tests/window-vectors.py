"""Mutation checks against a real emitted window vector object; no rebuild."""
import runpy
import struct
import sys
from pathlib import Path

check = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/check-window-vectors'))['check']
data = Path(sys.argv[1]).read_bytes()
assert check(data)
table = struct.unpack_from('<I', data, 32)[0]
count, names_index = struct.unpack_from('<HH', data, 48)
sections = [struct.unpack_from('<10I', data, table+i*40) for i in range(count)]
header = sections[names_index]
names = data[header[4]:header[4]+header[5]]
section = next(s for s in sections if names[s[0]:].split(b'\0', 1)[0] == b'.iram1.abla.s3WindowVectors')
offset = section[4]
# Alter saved/loaded registers, base pointers, displacements and returns in
# each hardware slot, plus the MOVSP window-base field and branch targets.
mutations = [(slot+delta, mask) for slot in (0, 0x40, 0x80, 0xc0, 0x100, 0x140)
             for delta, mask in ((0, 0x10), (1, 1), (1, 0x10), (2, 1))]
mutations += [(pc, 1) for pc in (0x59, 0x6e, 0x74, 0x7a, 0xc, 0x4c, 0x9b, 0xdb, 0x127, 0x167)]
for pc, mask in mutations:
    damaged = bytearray(data)
    damaged[offset+pc] ^= mask
    try:
        check(damaged)
    except (AssertionError, ValueError, IndexError, KeyError, struct.error):
        continue
    raise AssertionError(f'accepted damaged vector at {pc:#x}, xor {mask:#x}')
print(f'PASS: rejected {len(mutations)} emitted window-vector corruptions')
