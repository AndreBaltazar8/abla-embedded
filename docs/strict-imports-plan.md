# Moving abla-embedded to strict imports

The package says `visibility = "flat"` (abla.toml): some modules use names the program supplies. A strict module sees
only what it imports, and the nearest abla.toml above a module decides, so the package moves a directory at a time.

## Where it stands

- **Strict now:** 40 directory trees (1,141 modules: `src/esp32/runtime`, `security`, `radio`, `system`, `sdk`, ...
  `src/network`, `src/wifi`, `src/runtime`, ...) and `src/i2c/helpers`. Each has its own abla.toml with
  `visibility = "imports"`; their imports were added with the compiler's `help: add:` lines, from building all 2,973
  programs and a union program per tree.
- **Flat:** everything else, including `src/rtc`, the drivers in `src/m5stack`, `src/display`, ..., and the root manifest.
  The reason is hooks (below) and, for the I2C drivers, the per-program remaps.

## I2C: one interface module, remapped per program

`src/i2c/device.ab` declares `I2cBus`, `I2cDevice` and their common methods (stubs; the bodies are never linked). A
program's manifest remaps it to the module that really declares them (`[imports] "../../src/i2c/device.ab" =
"../../src/esp32/i2c_esp32s3.ab"`); the remap check (`E_IMPORT_REMAP_MISMATCH`) holds the backend to the contract.
Needs the compiler fix of #1025 (a program started by a relative path).

- Every example has an abla.toml with its remap; `tests/abla.toml` is the S3 group; the other backends' tests live in
  `tests/{software,p4,lp-c5,c5,idf6}/` and the host fakes in `tests/fakes/<name>/` (each remaps to itself and declares the
  whole surface). `examples/shared/` holds modules several programs import (a remap in a dependency's manifest is
  `E_IMPORT_REMAP_NOT_ROOT`).
- Two stub paths that remap to one backend are `E_IMPORT_ALIAS_TARGET_DUPLICATE` in a module importing both: one stub.
- `src/i2c/helpers` (register_access, register_address16) is strict and imports the stub.
- Not done: the I2C drivers (`src/rtc`, `src/m5stack`, ...). Making `src/rtc` strict needs a remap in every program that
  reaches it (118, eight with their own I2C fakes); tried and reverted. The software backend's own hooks
  (`softwareI2cDelay/Drive/Sample`) are another family.

## Hooks: what keeps the rest flat

1,043 modules call 1,793 names that a platform module and test mocks both define. See
[hook-mocking-design.md](hook-mocking-design.md): the two directions and what each costs. Until one is chosen
those directories stay flat.

## Checking a change

`tools/check-source`, plus building every program (`ablac build <program>`, flat, with `--visibility-report`) and
comparing the errors with the previous state: no strict-import error inside the strict trees, no new semantic or
import error. A new module in a strict tree needs its imports (the build says which: `help: add: import "..."`).
