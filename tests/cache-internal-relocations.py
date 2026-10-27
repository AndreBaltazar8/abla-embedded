import runpy
import struct
from pathlib import Path

validate = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/check-cache-internal-relocations'))['validate']


def fixture(target_name, target_index=3):
    data = bytearray(52)
    data[:6] = b'\x7fELF\x01\x01'
    names = b'\0.names\0.iram1.code\0' + target_name.encode() + b'\0.symtab\0.rela.iram1.code\0'
    sections = [(0,)*10]
    def add(name, kind, flags, payload, link=0, info=0, stride=0):
        start = len(data)
        data.extend(payload)
        sections.append((names.index(name.encode()+b'\0'), kind, flags, 0, start, len(payload), link, info, 4, stride))
    add('.names', 3, 0, names)
    add('.iram1.code', 1, 6, b'\0'*4)
    add(target_name, 1, 2, b'\0'*4)
    add('.symtab', 2, 0, b'\0'*16 + struct.pack('<IIIBBH', 0, 0, 4, 3, 0, target_index), stride=16)
    add('.rela.iram1.code', 4, 0, struct.pack('<IIi', 0, 257, 0), link=4, info=2, stride=12)
    table = len(data)
    for section in sections:
        data.extend(struct.pack('<10I', *section))
    struct.pack_into('<I', data, 32, table)
    struct.pack_into('<HHH', data, 46, 40, len(sections), 1)
    return data


assert validate(fixture('.dram1.table')) == 1
for data in (fixture('.rodata.table'), fixture('.text.helper'), fixture('.dram1.table', 0)):
    try:
        validate(data)
    except ValueError:
        pass
    else:
        raise AssertionError('unsafe relocation accepted')
print('PASS: internal data, flash table/helper and undefined relocation cases')
