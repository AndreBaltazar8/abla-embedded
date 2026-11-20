# Hooks and host tests in abla-embedded: what strict imports need

Strict imports make a module see only what it imports. abla-embedded's drivers call *hooks*: functions they never
import, whose body the program supplies by name (`peripheralDelayMilliseconds`, `c6I2sRead`, `sdMmcS3Read`, ...).
A real program imports a platform module that defines them; a host test defines its own mock with the same name. That
is a link-time substitution by flat name, and `visibility = "flat"` is what lets it work. This note compares the two
ways to keep it without flat. Numbers come from building all 2,973 programs with the strict-visibility report
(`~/archive/ablac-sweep-062/i2c/merged-rep1.tsv`, `multi-def.tsv`).

## What it looks like today

```abla
// src/m5stack/cores3_panel.ab (a driver)          // no import of any delay
        if (attempt < 5) peripheralDelayMilliseconds(20)

// src/esp32/peripheral_delay_esp32s3.ab (the platform's, ROM calibrated)
trusted fun peripheralDelayMilliseconds(milliseconds: int): void { ... esp_rom_delay_us(u32(1000)) ... }

// tests/fakes/cores3-power/cores3-power.ab (a host test, no platform module imported)
fun peripheralDelayMilliseconds(duration: int): void { bad = true; return }
```

## The size of it

| | count |
|---|---|
| src modules that call a name with several definers (hook-coupled) | 1,043 of 4,099 |
| hook names (several definers across programs) | 1,793 (1,780 defined by a platform module *and* by tests) |
| src modules that define such a name (platform side) | 723 |
| tests/examples that define (mock) such a name | 1,102 programs, ~1,795 definitions |
| src modules that depend on a hook-coupled module through imports | 2,399 |

Import remaps (how `I2cDevice` was done) don't fit: the remap target must declare everything the stub declares, and a
test mocks only the hooks its driver calls.

## Direction 1: an explicit native boundary the tests link mocks against

A hook becomes an `extern:"c"` declaration in a small interface module; whoever supplies it exports the symbol.
Checked with a scratch program (driver calls the extern, the program's `@export` is the body: prints 24):

```abla
// src/hal/delay.ab (new: the declarations, a few lines per family)
extern:"c" fun peripheralDelayMilliseconds(milliseconds: int): void
// the driver
import "../hal/delay.ab"            // one added import per driver; the call is unchanged
// the platform module
@export("peripheralDelayMilliseconds") trusted fun romDelayMilliseconds(milliseconds: int): void { ... }
// a host test: rename its mock and export it
@export("peripheralDelayMilliseconds") fun mockDelay(duration: int): void { bad = true; return }
```

- Files touched: interface modules (one per platform family); 723 platform modules (an `@export` and a rename per
  hook); 1,043 drivers (an import); 1,102 tests (rename + `@export` for ~1,795 mocks). No driver logic or signature changes.
- Driver author: writes the call as now; adds a hook by adding one line to the family's interface module and
  importing it. A program with two definitions of a symbol is a link error (today it's a silent name clash).
- Host test: the same shape as now plus `@export`; a test still mocks only the hooks it needs (no completeness rule).
- Risks: an `extern:"c"` declaration is checked for prototype compatibility only, so a mock with another signature
  would link: a script has to compare each `@export` with the interface declaration. Whole-program optimization still
  sees both sides (same module), so the code size should match; to be measured on one board before the rest.

## Direction 2: hooks passed as parameters

An interface per family and generic bounds (no dispatch, one instance per program):

```abla
interface PeripheralDelay { fun delayMilliseconds(milliseconds: int): void }
fun <D : PeripheralDelay> panelReset(delay: D, ...): bool { ... delay.delayMilliseconds(20) ... }
class RomDelay : PeripheralDelay { ... }          // platform
class MockDelay(var bad: bool) : PeripheralDelay { ... }   // host test
```

- Files touched: every function on a path to a hook gains a parameter, so up to the 2,399 dependent src modules and
  every call site; 1,102 tests rewrite their mocks as classes and pass them in. Functions that take several hooks need a
  bundle class per board.
- Driver author: sees the hooks as explicit arguments (clearer, and mocks stop being globals), at the cost of
  threading them through every layer.
- Host test: build the mock object, pass it; its state is explicit instead of file-level `var`s.
- Risks: signatures of public driver functions change for every user; one instance per implementation grows flash
  where a driver is used with more than one; a much bigger migration, not mechanical.

## Comparison

| | 1: extern boundary | 2: parameters |
|---|---|---|
| src files touched | ~1,043 (one import) + 723 (annotations) | up to 2,399, with signature changes |
| test files touched | 1,102 (rename + `@export`) | 1,102 (mocks become classes) |
| driver logic changes | none | every layer |
| mechanical | yes (scripts like the import fixer) | no |
| type-checked mocks | no (needs a script) | yes (bounds) |
| code size | to measure (should match) | to measure (monomorphization) |

Recommendation: direction 1, starting with one family (the peripheral delays: 3 platform modules, 74 mocks) to measure
code size and the signature script, then the rest by script.

## State after the scripted families, and what is left (2026-11-20)

Done: the scalar hooks (about 1,449 of 1,793 names: src/hal/*.ab declare them as `extern:"c"`, platforms and mocks `@export`
them), `Pin` as one shared alias (src/hal/pin.ab), the I2C types through a remapped stub (src/i2c/device.ab, 56 tests moved to
tests/fakes/), five duplicated aliases. A strict report of every program (761 (module, name) pairs in 310 src modules) shows
what still depends on flat visibility:

- the 21 `Pin` methods (number, valid, write, read, outputLevelOwned, ... about 230 pairs): each platform module (gpio_esp32s3,
  gpio, the c5/c6/c61/p4 sequences, matrix_routes_esp32s3) declares a different subset and ~100 tests mock them;
- the mock driver types (M5Ioe1, Es7210, M5Pm1, Es8311, Aw9523, ...: about 60 pairs, tests define type and methods whole);
- about 40 test-defined functions whose signatures use test types (GDMA, SPI, I2S, p4 helpers).

Why the I2C stub does not carry over to `Pin`: a remap target must declare everything the stub declares, and the platforms'
subsets differ (S3: 20 methods, C6: 11 with `inputPullOwned`), so the stub would be the intersection, which the drivers exceed;
splitting the stub per method fails because two stubs remapped to one importer's target are E_IMPORT_ALIAS_TARGET_DUPLICATE.

Next design (not started): `Pin` methods become wrappers in src/hal/pin.ab over scalar hooks (`abla_pin_write(pin: int,
level: bool)` ...), the platform modules and the mocks export the hooks (`@export`), the bodies rewritten from `this` to a
`Pin(pinNumber)` parameter. The mock driver types and the functions follow the I2C pattern (a remap per mock, the mock
declaring what the driver module declares).
