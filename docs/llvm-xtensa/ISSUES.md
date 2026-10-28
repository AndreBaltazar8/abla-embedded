# Issue drafts

`B=/nix/store/63b2qnfsn22li6zg1hkk2zjv2m2xna0b-llvm-23.1.3/bin`, run from this directory.

## 1. [Xtensa] Cannot select `Constant<N>` for `(add (shl x, 1|2|3), C)` when C is outside MOVI range

    $B/llc -mtriple=xtensa-esp-unknown-elf -mcpu=esp32 -O0 01-addx-large-constant.ll -o -

Observed (same at -O2):

    LLVM ERROR: Cannot select: 0x...: i32 = Constant<8192>
    In function: f

Expected: `movi`/`l32r` (or `addmi`) materializes 8192, then `addx8`.

Draft: The ADDX2/4/8 patterns take the addend as a register, and the constant
operand is matched without a lowering for values outside MOVI's 12-bit signed
range, so ISel aborts. Even at -O0 `shl i32 %b, 3; add i32 %s, 8192` fails.

Upstream: not found in llvm/llvm-project. Same symptom, open, no fix:
https://github.com/espressif/llvm-project/issues/141 ;
repro repo https://github.com/aeolionics-rs/xtensa-ice . Related but different:
https://github.com/llvm/llvm-project/issues/227826 (PCREL_WRAPPER),
fix PR https://github.com/llvm/llvm-project/pull/231056 .

## 2. [Xtensa][MC] Out-of-range conditional branches are not relaxed

    $B/llvm-mc -triple=xtensa-esp-unknown-elf -mcpu=esp32 -filetype=obj 02-branch-relax.s -o /dev/null

Observed:

    02-branch-relax.s:5:14: error: fixup value out of range
            beqi a8, 5, far

Expected (GNU as behaviour): rewrite as inverted branch over a `j far`.

Draft: XtensaAsmBackend checks branch fixup ranges but does not relax B*
instructions whose target is beyond the 8-bit (bz: 12-bit) reach, unlike
binutils. Hand-written/inline asm and large functions hit this.

Upstream: no Xtensa report found; backend source
https://codebrowser.dev/llvm/llvm/lib/Target/Xtensa/MCTargetDesc/XtensaAsmBackend.cpp.html
(range checks only). Precedent for RISC-V: https://reviews.llvm.org/D108961 .

## 3. [Xtensa] Text streamer crashes on `.literal` with `sym+addend`

    $B/llvm-mc -triple=xtensa-esp-unknown-elf -mcpu=esp32 -filetype=obj 03b-literal-addend.s -o m.o   # OK
    $B/llvm-mc -triple=xtensa-esp-unknown-elf -mcpu=esp32 -filetype=asm 03b-literal-addend.s         # segfault, rc=139

Stack: `XtensaTargetAsmStreamer::emitLiteral` called from
`XtensaAsmParser::parseLiteralDirective`. Via llc, inline asm
`movi $0, sym+5` (`03-literal-addend.ll`, `-filetype=asm`) does not crash here
but prints an empty operand, `.literal .Ltmp0, ` (plain `sym` prints
correctly), which is unassemblable. Object output works.

Draft: emitLiteral mishandles a SymbolRef+constant expression (null deref in
the asm streamer; empty operand when printed from the llc path). It should
print the MCExpr generically.

Upstream: none found.

## 4. [Xtensa] `.cfi_def_cfa a7, N` emitted by llc is rejected by llvm-mc

    $B/llc -mtriple=xtensa-esp-unknown-elf -mcpu=esp32 -filetype=asm 04-cfi-frame-pointer.ll -o 04.s
    $B/llvm-mc -triple=xtensa-esp-unknown-elf -mcpu=esp32 -filetype=obj 04.s -o /dev/null

Observed: `04.s:14:17: error: invalid register name  .cfi_def_cfa a7, 32`.
Expected: round trip. Draft: the assembler cannot parse the AR register name
as a DWARF register in `.cfi_*` directives while the backend emits it for
frame-pointer functions, so llc's asm output cannot be re-assembled.

Upstream: none found.

## 5. [Xtensa] Inline asm constraint `a` unsupported

    $B/llc -mtriple=xtensa-esp-unknown-elf -mcpu=esp32 05-asm-constraint-a.ll -o -

Observed: `error: could not allocate output register for constraint 'a'`;
as an input-only constraint: `error: unknown asm constraint 'a'`.
Expected: accepted as address-register class (GCC/Espressif use `a`);
`r` works. Draft: Xtensa inline-asm constraint lowering handles only `r`;
`a` should map to the AR register class.

Upstream: none found.

## 6. [Xtensa] Code Density instructions rarely selected (missed optimization)

    $B/llc -mtriple=xtensa-esp-unknown-elf -mcpu=esp32 -O2 06-density.ll -o -

23.1.3 emits for the loop `or a8,a2,a2`, `l32i`, `add`, `addi`, `addi`;
only `retw.n` is narrow. Espressif clang 21.1.3 (same flags, run via
`steam-run ~/.cache/abla-embedded/esp-clang-21.1.3/bin/llc`) emits `movi.n`,
`mov.n`, `l32i.n`, `add.n`, `addi.n` x2, `retw.n`: 7 of 10 narrow.
Expected: use `mov.n`, `l32i.n`, `s32i.n`, `add.n`, `addi.n`, `movi.n`,
`ret.n` when operands fit and `density` is enabled. Not a correctness bug.

Upstream: none found. (GCC was not available locally; the comparison is
against the Espressif LLVM fork.)

## 7. [Xtensa] No `esp32s3` CPU

    $B/llc -mtriple=xtensa-esp-unknown-elf -mcpu=esp32s3 06-density.ll -o /dev/null
    'esp32s3' is not a recognized processor for this target (ignoring processor)

`-mcpu=help` lists esp32, esp32s2, esp8266. Upstream added esp32/esp8266 CPUs in
https://lists.llvm.org/pipermail/all-commits/Week-of-Mon-20250811/241722.html
(#152409); I could not confirm an esp32s3 definition in main (verify in
`XtensaProcessors.td`). Related in-flight S3 work:
https://github.com/llvm/llvm-project/pull/235094 .
Workaround: `-mcpu=esp32 -mattr=-dfpaccel`.
