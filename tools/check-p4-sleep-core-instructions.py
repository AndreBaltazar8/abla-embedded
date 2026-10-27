#!/usr/bin/env python3
"""Execute the linked LLVM RV32 boundary, not a source-level mock.

Bounded integer/CSR model; no claim of P4 ROM/cache/PMU or physical validation.
Usage: python3 tools/check-p4-sleep-core-instructions.py build/tests/sleep-core-p4.elf
"""
import struct
import sys

blob = open(sys.argv[1], "rb").read()
assert blob[:6] == b"\x7fELF\x01\x01"
assert struct.unpack_from("<H", blob, 18)[0] == 243
shoff = struct.unpack_from("<I", blob, 32)[0]
entsize, count = struct.unpack_from("<HH", blob, 46)
sections = [struct.unpack_from("<10I", blob, shoff + i * entsize) for i in range(count)]
initial = {}
symbols = {}
for section in sections:
    _, kind, flags, address, offset, size, link, _, _, stride = section
    if flags & 2:
        data = bytes(size) if kind == 8 else blob[offset:offset + size]
        initial.update((address + i, value) for i, value in enumerate(data))
    if kind == 2:
        strings = sections[link]
        names = blob[strings[4]:strings[4] + strings[5]]
        for i in range(0, size, stride):
            name, value, _, _, _, _ = struct.unpack_from("<IIIBBH", blob, offset + i)
            symbols[names[name:].split(b"\0", 1)[0].decode()] = value

cores = [s for s in sections if s[2] & 4 and s[3] == 0x4ff01000]
assert len(cores) == 1
ENTRY = cores[0][3]
WAKE = ENTRY + 16
TABLE = symbols[".Labla_p4_core_frames"]
FRAME = 0x4ff20000
CALLBACK = 0x4ff30000
RETURN = 0x12340000
ROM_RETURN = 0x12340004
PUBLIC = symbols["abla_esp32p4_sleep_core_example"]
SAVED = [1, 2, 3, 4, 8, 9, *range(18, 28)]
TRAPS = [0x300, 0x305, 0x307, 0x342, 0x343, 0x304, 0x344, 0x341, 0x340]
MASK = 0xffffffff


def signed(value, bits=32):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value >> (bits - 1) else value


class Machine:
    def __init__(self, hart, revision):
        self.mem = initial.copy()
        self.regs = [0] + [(0xa5100000 + i * 0x1234) & MASK for i in range(1, 32)]
        self.regs[1] = RETURN
        self.regs[2] = 0x4ff2f000
        self.regs[10:14] = [FRAME, CALLBACK, 0xdeadbeef, revision]
        self.before = self.regs.copy()
        self.csrs = {c: 0x25000000 + i * 256 for i, c in enumerate(TRAPS)}
        self.csrs[0x300] = 0x1880
        self.csrs[0x347] = 0x12340000
        self.csrs[0xf14] = hart
        self.old_csrs = self.csrs.copy()
        self.pc = ENTRY
        self.fences = 0
        self.csr_access = []
        self.stores = []
        self.callbacks = 0
        for i in range(148):
            self.mem[FRAME + i] = 0
        self.put(FRAME + 144, 0x1234abcd)
        self.stores.clear()

    def get(self, address):
        assert address & 3 == 0, hex(address)
        return sum(self.mem[address + i] << (8 * i) for i in range(4))

    def put(self, address, value):
        assert address & 3 == 0, hex(address)
        assert FRAME <= address < FRAME + 148 or TABLE <= address < TABLE + 8 or 0x4ff2ef00 <= address < 0x4ff2f000, hex(address)
        for i in range(4):
            self.mem[address + i] = (value >> (8 * i)) & 255
        self.stores.append((address, value & MASK))

    def step(self):
        ins = self.get(self.pc)
        op, rd, f3, rs1, rs2, f7 = ins & 127, (ins >> 7) & 31, (ins >> 12) & 7, (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = self.regs[rs1], self.regs[rs2]
        imm = signed(ins >> 20, 12)
        next_pc = self.pc + 4
        value = None
        if op == 0x37:
            value = ins & 0xfffff000
        elif op == 0x17:
            value = self.pc + (ins & 0xfffff000)
        elif op == 0x13:
            if f3 == 0:
                value = a + imm
            elif f3 == 7:
                value = a & imm
            elif f3 == 6:
                value = a | imm
            elif f3 == 1:
                value = a << (rs2 & 31)
            else:
                raise AssertionError(("opimm", hex(ins)))
        elif op == 0x33 and f7 == 0 and f3 in (0, 6):
            value = a + b if f3 == 0 else a | b
        elif op == 3 and f3 == 2:
            value = self.get((a + imm) & MASK)
        elif op == 3 and f3 == 4:
            value = self.mem[(a + imm) & MASK]
        elif op == 0x23 and f3 == 2:
            offset = signed(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
            self.put((a + offset) & MASK, b)
        elif op == 0x63:
            offset = signed(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 63) << 5) | (((ins >> 8) & 15) << 1), 13)
            take = {0: a == b, 1: a != b, 4: signed(a) < signed(b), 5: signed(a) >= signed(b), 6: a < b, 7: a >= b}[f3]
            if take:
                next_pc = self.pc + offset
        elif op == 0x6f:
            offset = signed(((ins >> 31) << 20) | (((ins >> 12) & 255) << 12) | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 1023) << 1), 21)
            value, next_pc = next_pc, self.pc + offset
        elif op == 0x67 and f3 == 0:
            value, next_pc = next_pc, (a + imm) & ~1
        elif op == 0x0f:
            self.fences += 1
        elif op == 0x73 and f3:
            csr = ins >> 20
            self.csr_access.append(csr)
            value = self.csrs.get(csr, 0)
            source = rs1 if f3 >= 5 else a
            mode = f3 & 3
            if mode == 1:
                self.csrs[csr] = source
            elif source and mode == 2:
                self.csrs[csr] = value | source
            elif source and mode == 3:
                self.csrs[csr] = value & ~source & MASK
        else:
            raise AssertionError((hex(self.pc), hex(ins)))
        if value is not None and rd:
            self.regs[rd] = value & MASK
        self.regs[0] = 0
        self.pc = next_pc & MASK

    def run(self, wake=False):
        for _ in range(1000):
            if self.pc in (RETURN, ROM_RETURN):
                return
            if self.pc == CALLBACK:
                self.callbacks += 1
                assert self.callbacks == 1
                assert self.regs[10] == 0xdeadbeef
                hart = self.csrs[0xf14]
                assert self.get(TABLE + hart * 4) == FRAME
                assert self.get(FRAME + 4) == 1 and self.fences == 1
                if wake:
                    self.regs = [0] + [0x76540000 + i * 16 for i in range(1, 32)]
                    self.regs[1] = ROM_RETURN
                    self.csrs = {0xf14: hart, 0x300: 0}
                    self.pc = WAKE
                else:
                    return_pc = self.regs[1]
                    for r in [1, 5, 6, 7, *range(10, 18), 28, 29, 30, 31]:
                        self.regs[r] = 0xbad00000 + r
                    self.regs[1] = return_pc
                    self.regs[10] = 0x87654321
                    self.pc = return_pc
                continue
            self.step()
        raise AssertionError("instruction budget exceeded")


cases = 0
for public in (False, True):
    for hart in (0, 1):
        for revision in (0, 1, 299, 300, 399):
            for wake in (False, True):
                m = Machine(hart, revision)
                if public:
                    m.pc = PUBLIC
                    m.regs[14:16] = [1, 1]
                m.run(wake)
                assert m.pc == RETURN and m.callbacks == 1
                assert all(m.regs[r] == m.before[r] for r in SAVED)
                assert all(m.csrs[c] == m.old_csrs[c] for c in TRAPS)
                assert (0x347 in m.csr_access) == (revision >= 300)
                if revision >= 300:
                    assert m.csrs[0x347] == m.old_csrs[0x347]
                assert m.regs[10] == (0 if wake else 0x87654321)
                assert m.get(FRAME + 4) == (3 if wake else 2)
                assert m.get(TABLE) == m.get(TABLE + 4) == 0
                assert m.get(FRAME + 144) == 0x1234abcd
                assert m.fences == 2
                cases += 1
for reason in ("interrupts", "hart", "nested"):
    m = Machine(0, 300)
    if reason == "interrupts":
        m.csrs[0x300] |= 8
    elif reason == "hart":
        m.csrs[0xf14] = 2
    else:
        m.put(TABLE, 0x4ff24000)
        m.stores.clear()
    m.run()
    assert not m.callbacks and not m.stores
    assert m.regs[10] == 3
    assert all(m.regs[r] == m.before[r] for r in SAVED)
    cases += 1
for hart in (0, 1, 2):
    m = Machine(hart, 300)
    m.pc = WAKE
    m.regs[1] = ROM_RETURN
    m.run()
    assert m.pc == ROM_RETURN and not m.stores and not m.callbacks
    cases += 1
for reason in ("address", "unaligned", "callback", "revision", "exclusive", "live"):
    m = Machine(0, 300)
    m.pc = PUBLIC
    m.regs[14:16] = [1, 1]
    if reason == "address":
        m.regs[10] = 0
    elif reason == "unaligned":
        m.regs[10] = FRAME + 1
    elif reason == "callback":
        m.regs[11] = CALLBACK + 1
    elif reason == "revision":
        m.regs[13] = 400
    elif reason == "exclusive":
        m.regs[15] = 0
    else:
        m.put(FRAME, 1)
        m.stores.clear()
    m.run()
    assert m.pc == RETURN and not m.callbacks and m.regs[10] == 2
    assert all(m.regs[r] == m.before[r] for r in SAVED)
    assert all(0x4ff2ef00 <= addr < 0x4ff2f000 for addr, _ in m.stores)
    cases += 1
m = Machine(0, 300)
m.pc = PUBLIC
m.regs[14] = 0
m.run()
assert m.pc == RETURN and m.regs[10] == WAKE and not m.callbacks
cases += 1
print(f"PASS: {cases} emitted-RV32 sleep boundary scenarios; no physical ROM/PMU claim")
