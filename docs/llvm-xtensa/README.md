# LLVM 23.1 Xtensa backend: upstream bug drafts

Drafts only; nothing has been filed. Repros were run with
`/nix/store/63b2qnfsn22li6zg1hkk2zjv2m2xna0b-llvm-23.1.3/bin` (`B` below),
triple `xtensa-esp-unknown-elf`, `-mcpu=esp32`. Full issue text is in
[ISSUES.md](ISSUES.md).

| # | Issue | Repro | Status on 23.1.3 | abla-embedded workaround (remove when fixed) |
|---|-------|-------|------------------|-----------------------------------------------|
| 1 | ISel `Cannot select: Constant<N>` for `add (shl x,1..3), C` | `01-addx-large-constant.ll` | reproduces (-O0 and -O2) | `tools/esp-llvm-bin/opaque-xtensa-constant` + retry loop in `tools/esp-llvm-bin/llc` |
| 2 | MC does not relax out-of-range conditional branches | `02-branch-relax.s` | reproduces | `tools/esp-llvm-bin/relax-xtensa-branches` + llvm-mc retry loop in `llc` |
| 3 | `.literal L, sym+N` crashes text streamer | `03b-literal-addend.s`, `03-literal-addend.ll` | reproduces (llvm-mc segfault rc=139; llc prints an empty literal operand instead of crashing) | `alias_symbol_addends` in `tools/recover-member` (`.set alias, sym+N`) |
| 4 | `.cfi_def_cfa a7, N` rejected by llvm-mc | `04-cfi-frame-pointer.ll` | reproduces | CFI directives dropped in `tools/esp-llvm-bin/narrow-xtensa-assembly` (unless `ABLA_ESP_KEEP_UNWIND=1`); `.eh_frame` stripped in `llc` |
| 5 | Inline-asm constraint `a` rejected | `05-asm-constraint-a.ll` | reproduces | none in tools; sources use `r` |
| 6 | Code Density (`.n`) rarely selected | `06-density.ll` | reproduces (missed optimization) | `tools/esp-llvm-bin/narrow-xtensa-assembly` (`ABLA_XTENSA_NARROW=1`) |
| 7 | No `esp32s3` CPU | (command only) | reproduces | `esp32s3) target=(-mcpu=esp32 -mattr=-dfpaccel)` case in `tools/esp-llvm-bin/llc` |

Upstream status found online (searched 2026-10-28): see per-issue links in
ISSUES.md. Short version: #1 is open downstream at
espressif/llvm-project#141 with no fix; no upstream report or fix found for
#2-#5; #7 not found in main (unverified).
