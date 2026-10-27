#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("prepare_xtensa", str(root / "tools/esp-llvm-bin/prepare-xtensa-assembly"))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

source = '''\t.section .iram1.abla.worker,"ax",@progbits
\t.type worker,@function
worker:
\tentry a1, 32
\tretw
\t.size worker, .-worker
\t.section .rodata.worker,"a",@progbits
\t.p2align 2
.LJTI0_0:
\t.word .LBB0_1
\t.section .text.normal,"ax",@progbits
\t.type normal,@function
\t.section .rodata.normal,"a",@progbits
\t.word 42
\t.section .rodata.worker_suffix,"a",@progbits
\t.word 43
#APP
\t.section .rodata.worker,"a",@progbits
\t.word 44
#NO_APP
'''
actual = ''.join(module.place_iram_companion_data(source.splitlines(keepends=True)))
expected = source.replace('.section .rodata.worker,', '.section .dram1.abla.rodata.worker,', 1)
assert actual == expected
assert ''.join(module.place_iram_companion_data(actual.splitlines(keepends=True))) == actual
assert module.place_iram_companion_data([]) == []
assert ''.join(module.prepare(source.splitlines(keepends=True))) == expected
print("PASS: exact IRAM companion placement, ordinary/user assembly preservation and idempotence")

switches = source + '''\t.section .rodata..Lswitch.table.worker,"a",@progbits
\t.word 80
\t.section .rodata..Lswitch.table.worker_suffix,"a",@progbits
\t.word 40
\t.section .rodata..Lswitch.table.normal,"a",@progbits
\t.word 20
'''
switched = ''.join(module.place_iram_companion_data(switches.splitlines(keepends=True)))
assert switched == expected + switches[len(source):].replace(
    '.section .rodata..Lswitch.table.worker,',
    '.section .dram1.abla.rodata..Lswitch.table.worker,', 1)
assert ''.join(module.place_iram_companion_data(switched.splitlines(keepends=True))) == switched
print("PASS: LLVM switch lookup tables retain exact IRAM function ownership")
merged = source + '''\t.type .Lswitch.table.worker,@object
\t.section .rodata.cst16,"aM",@progbits,16
.Lswitch.table.worker:
\t.word 1,2,3,4
\t.size .Lswitch.table.worker,16
ordinary:
\t.word 5,6,7,8
'''
merged_actual = ''.join(module.place_iram_companion_data(merged.splitlines(keepends=True)))
assert '.section .dram1.abla.rodata..Lswitch.table.worker,"aM",@progbits,16' in merged_actual
assert '.size .Lswitch.table.worker,16\n\t.section .rodata.cst16,"aM",@progbits,16\nordinary:' in merged_actual
assert ''.join(module.place_iram_companion_data(merged_actual.splitlines(keepends=True))) == merged_actual
print("PASS: owned merged switch constants move only their object, not following data")

loader = importlib.machinery.SourceFileLoader("internal_object", str(root / "tools/check-cache-internal-object"))
spec = importlib.util.spec_from_loader(loader.name, loader)
checker = importlib.util.module_from_spec(spec)
loader.exec_module(checker)
checker.validate_sections([(".iram1.test", 6, 64), (".dram1.table", 2, 16), (".text", 6, 0), (".debug", 0, 100)])
for invalid in [[(".text.fn", 6, 8)], [(".iram1.fn", 6, 8), (".rodata.fn", 2, 16)], [(".dram1.data", 2, 4)]]:
    try:
        checker.validate_sections(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError(f"accepted unsafe/empty code closure: {invalid}")
print("PASS: section guard rejects flash code, flash data and empty closures")
