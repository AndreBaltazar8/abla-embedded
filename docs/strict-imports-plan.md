# Moving abla-embedded to strict imports

The package says `visibility = "flat"` (abla.toml) because the shared driver modules use names that the program
supplies: `I2cDevice` and its methods come from whichever backend a program imports, and a strict module
can't import "whichever backend".

## What is in the way

- `type I2cDevice = int` is declared in six backends (`src/esp32/i2c_idf6.ab`, `i2c_esp32s3.ab`, `i2c_esp32c5.ab`,
  `i2c_lp_esp32c5.ab`, `src/esp32/i2c/hardware_provider_p4.ab`, `src/i2c/software_provider.ab`); 148 files in
  `src/` and 158 in `tests/` and `examples/` mention it. `tools/fix-imports.ab` merges reports across programs
  and so imports two backends into one module (two `I2cDevice`): it can't do this migration mechanically.
- Every backend defines the same ten methods on it: `valid close write read writeRead readRegister writeRegister
  readRegister8 readRegister8Checked writeRegister8` (plus `transferStatus`, `setFrequency` in some). The shared
  modules `src/i2c/register_access.ab` and `register_address16.ab` and every board driver call them.

## Design: one interface module, remapped per program

1. `src/i2c/device.ab` declares `type I2cDevice = int` once, with the ten methods as stubs (same signatures as
   the backends, bodies that return false/0). Shared modules and drivers import it, and nothing else, for
   the device. Packages `src/i2c`, `src/m5stack`, ... get `visibility = "imports"` one directory at a time (the
   nearest manifest decides, so the flat package migrates a directory per step).
2. A program picks its backend with an import remap in its root manifest (docs/packages.md, "Import
   remaps"): `[imports] "<path>/src/i2c/device.ab" = "<path>/src/esp32/i2c_esp32c5.ab"`. The remap check
   (`E_IMPORT_REMAP_MISMATCH`) enforces that the backend declares everything device.ab does, with the same
   types: that is the interface. Each backend then drops its own `type I2cDevice` only when it is no longer
   imported without the remap, so flat programs keep building during the migration.
3. `examples/*` already have a directory each: one `abla.toml` per example (or one per board group). The
   single-file programs in `tests/` need a manifest above them per backend (`tests/esp32c5/abla.toml`, ...).
4. The same shape applies to the other program-supplied names (`I2cBus`, the SPI/GPIO/clock backends): one
   interface module per family, remapped per program.

## Blocker found while trying it (needs a compiler change)

A remap redirects a shared module's imports to the backend, and the shared module compiles against it. But an
extension function the shared module declares on the remapped type is not found on the backend's type from the
program: `Dev(40).twice(1)` is `method.unknown`, whether `Dev` is a class or `type Dev = int`, flat or strict.
In abla-embedded that is `device.writeRegister16LittleEndian(...)` from `register_access.ab`. A repro with three
files is in `~/archive/ablac-sweep-062/remap-ext-repro/` (`app/` is the program; `shared/` the shared module with
`dev.ab` the stub). Until that works, steps 1-3 can't be shown on even one backend.

If the compiler change isn't wanted, the other route is to repeat the shared helpers per backend (about 120 lines
in each of six backends), which this plan does not recommend.

## Order once the remap works

1. `device.ab` and its remap for one backend, with `register_access.ab` strict (an example program per backend
   proves it: `examples/i2c-<backend>-strict/`).
2. The other five backends' manifests; then the board drivers in `src/m5stack/`, directory by directory.
3. Tests and examples: one manifest per backend group.
4. Remove `visibility = "flat"` from abla.toml when no flat module is left.
