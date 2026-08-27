# Abla Embedded

Abla Embedded is the low-level, board-neutral home for firmware written in
Abla. Application code uses the same names (`Pin`, `SerialPort`, `I2sDevice`,
`WifiStation`, `TlsClient`) while a project chooses the platform implementation
it imports.

The ESP32 target emits Xtensa objects directly through LLVM. There is no
generated C and no handwritten C/C++ shim between an Abla application and the
linker. The shared `Register8`, `Register16`, `Register32`, and `Register64`
types are zero-storage views over volatile MMIO. Classic ESP32 GPIO direction,
levels, pulls, open-drain mode, and drive strength are implemented entirely in
Abla on top of those views; UART also uses direct volatile MMIO. Xtensa cycle
reads and bounded delays lower directly to CCOUNT instructions. Complex vendor
services currently call their native ABI:
the ESP-IDF I2C, SPI and I2S DMA drivers, Wi-Fi initialization/PHY/MAC
libraries, TLS, and sleep support. Those boundaries are deliberately visible
in `src/esp32`.

## Requirements

- the sibling `ablac` checkout with `abla/unsafe/mmio` support
- ESP-IDF 6.0.2 with ESP32 Xtensa and ESP32-C6 RISC-V toolchains (the helper
  defaults to the cached checkout documented below)
- CMake, Ninja, and the other ESP-IDF host tools (provided by `shell.nix`)
- PlatformIO only for the optional Arduino compatibility builds
- Espressif's LLVM toolchain 21.1.3 (or set `ABLA_ESP_LLVM_ROOT`)
- `steam-run` when using Espressif's generic Linux archive on NixOS

## Build the examples

From this directory:

```sh
make setup
make blink
make serial
make i2c-scan
make spi-jedec
make sd-card
make rtc-pcf8563
make rtc-rx8130
make rtc-powerhub
make io-expander
make imu
make power-monitor
make pmic-axp192
make pmic-axp2101
make pmic-ip5306
make pmic-m5pm1
make charger-aw32001
make led-m5pm1
make led-powerhub
make led-paper-mono
make led-strip-rmt
make board-detect-c6
make board-detect-s3
make radio-mac-registers
make compare-radio-power-size
make compare-rx-chain-size
make compare-wifi-fcs-size
make compare-esp32-aes-size
make compare-wifi-ccmp-size
make imu-calibration
make imu-offsets
make i2s-tone
make wifi-connect
make atom-echo
```

`make setup` installs the checksum-pinned x86-64 Linux Espressif LLVM release
and ESP-IDF 6.0.2 under the user cache directory. On another host, install the
equivalent toolchains and set `ABLA_ESP_LLVM_ROOT` and `IDF_PATH`.

`make blink` uses Espressif's official `idf.py` workflow. Set `IDF_PATH` when
ESP-IDF is installed somewhere other than
`~/.cache/abla-embedded/esp-idf-v6.0.2`. `spi-jedec` demonstrates a single
chip-select-preserving command/read transaction against an external SPI flash.
`sd-card` initializes an SDHC/SDSC card and reads its first raw 512-byte block
using an SDSPI protocol implementation written in Abla.
`rtc-pcf8563` reads and validates an external PCF8563 RTC over I2C.
`rtc-rx8130` reads and validates an external RX8130 RTC over I2C.
`rtc-powerhub` reads and validates the M5Stack PowerHub RTC protocol.
`io-expander` probes M5IOE1 and PI4IOE5V6408 devices and configures one input.
`imu` probes MPU6886, SH200Q, BMI270, BMM150, and AK8963 devices and exercises
the shared packed-axis API. These device examples are direct `app_main`
ESP-IDF firmwares and do not depend on Arduino.
`power-monitor` probes INA226 and INA3221 monitors and exercises calibrated
bus-voltage, shunt-voltage, current, and power reads. Both drivers retain their
configuration in one allocation-free scalar rather than a heap-backed object.
`pmic-axp192` probes the classic M5Stack AXP192 PMIC and reads battery, input,
system-rail, and temperature telemetry without changing rail configuration.
The reusable allocation-free driver also exposes DCDC/LDO/GPIO, charging, ADC,
backup, external-rail, power-key, and shutdown controls.
`pmic-axp2101` read-only probes the newer PMIC used by CoreS3-class boards and
samples its battery, VBUS, system, thermistor, die-temperature, charge-state,
and IRQ registers. Its allocation-free driver also exposes ALDO/BLDO/DLDO,
charging, ADC, power-key, IRQ, and shutdown controls. IRQ snapshots use the
same bit positions as IRQ enable masks and require no hidden mutable arrays.
`pmic-ip5306` covers the original M5Stack boost/charger PMIC, including its
coarse battery gauge, charge controls, completed-charge detection, and low-load
keep-on mode. `pmic-m5pm1` builds the M5Stack PM1 used by M5StickS3-class
boards. Its allocation-free driver covers rail control, five GPIOs, two PWM
channels, wake/IRQ handling, power-key event snapshots, charge enable,
telemetry, and shutdown. A power-key snapshot retains double-click state in
the returned scalar rather than in hidden driver state. `PY32PMIC` is only an
upstream deprecated alias for this same device, not another implementation.
`charger-aw32001` builds the AW32001 charger used with the
RISC-V ESP32-C6 Arduino Nesso N1, using an Abla-generated RISC-V object. The
same example initializes its paired BQ27220 fuel gauge and reads signed battery
current and voltage through an allocation-free driver.
`board-detect-c6` is the independently buildable opt-in detector for NanoC6
and StampC6. It reads the package through ESP-IDF's stable eFuse ABI and the
embedded-flash capacity from the read-only eFuse mirror directly in Abla. It
does not touch GPIOs, and QFN40 display products remain unknown until a display
detector identifies them.
`board-detect-s3` is the independently buildable opt-in ESP32-S3 detector. It
captures and restores every GPIO field it changes, including the output latch,
and refuses peripheral-controlled outputs. Its allocation-free Abla software
I2C probe only uses open-drain transitions, checks for strong external pull-ups,
honors bounded clock stretching, and recovers an interrupted bus without
allocating ESP-IDF's I2C driver. The AtomS3R camera distinction generates XCLK
and probes the OV3660/GC0308 addresses through direct Abla volatile MMIO, then
restores every pin it touched.
The four LED examples cover ESP-IDF 6 RMT strips, M5PM1 packed RGB output,
PowerHub's eight RGB channels, and Paper Mono's split PMIC/M5IOE1 RGB path.
Each backend has the same `setColor`, `setAllColor`, `setBrightness`, and
`display` names. Fixed caller-owned state replaces M5Unified's virtual objects
and heap-backed color vectors. The RMT backend uses IDF's built-in byte and
copy encoders directly, so it also avoids M5Unified's allocated custom encoder
and C callback. `rmtLedStripAt` accepts storage for any checked strip length;
the convenience constructor owns 424 static bytes for up to 64 LEDs. Its APB
clock default covers classic ESP32/S2/S3/C2/C3 targets, while adapters for SoCs
with a different IDF RMT clock enum pass that source explicitly. The examples
illuminate briefly and turn off, and must only be flashed to the board named by
the example.
The serial, I2S, and Wi-Fi examples
currently also exercise the optional Arduino/PlatformIO compatibility
integration. Edit the placeholder credentials before flashing `wifi-connect`.
`radio-mac-registers` is a build-only, opt-in classic-ESP32 object proving that
interrupt, RX DMA/filter, TX queue/PLCP, and MAC-time operations lower directly
to volatile MMIO with no vendor radio ABI. It also emits a separate native ESP
DMA descriptor object so ownership publication can be inspected independently.
The build also emits classic ESP32 radio power/clock/reset leaves, including a
complete 10-microsecond CCOUNT-timed power-on sequence; none of the three
objects performs initialization merely by being linked. The size comparison
targets check that sequence and the null-terminated RX descriptor-chain
initializer against equivalent C under the same toolchain and flags. The RX
leaf retains all alignment, count, and 32-bit range checks and is three bytes
smaller than the C reference (114 versus 117 bytes of text plus literals).
The same example emits a board-independent IEEE 802.11 FCS leaf and checks it
against equivalent volatile-memory C: Abla is 180 bytes and 54 Xtensa
instructions versus C at 184 bytes and 56 instructions.
It also emits native hardware AES-CCM and complete conventional-frame
CCMP-128/CCMP-256 request entries. Their 32-bit request layout avoids a C
trampoline and keeps the Xtensa boundary stable while the implementation stays
entirely in Abla. The stateful layer covers the opaque CCMP object's complete
encap, decap, encrypt, decrypt, ESP-NOW, cipher-metadata, PN, and per-TID replay
surface with a caller-owned 216-byte state and native Xtensa CAS. Its final
full-surface KAT passed on an ESP32-PICO-D4. The CCMP replay leaf is 72 bytes
and 27 instructions in both Abla and equivalent C++ with no unresolved call.
The same object now emits allocation-free AES-CMAC and AES-GMAC request
entries plus stateful 802.11w BIP-CMAC-128, BIP-GMAC-128, and BIP-GMAC-256
protect/verify entries. Their one-pointer records avoid overflowing the Xtensa
register argument window. Standard tags, replay rejection, tamper rejection,
state rollback, and retry all passed on the connected ESP32-PICO-D4. The exact
`ieee80211_crypto.o` ABI is now also Abla: cipher encap/decap dispatch, MIC
lengths, BIP encrypt/verify, and the writable provider-table symbol. A real
M5Echo link removed that opaque member, reducing the retained radio inventory
from 62 to 61 objects, and then passed WPA2 association, authenticated server
connection, speech request, and playback. The provider callbacks copied into
that table remain separate replacement work.
It also emits the classic ESP32 interrupt-matrix and Xtensa CPU-mask leaves.
Core ID is 11 bytes/4 instructions in both Abla and C++. The race-safe
enable/disable operations use 9/10 instructions with no call or allocation;
each is one byte smaller than the equivalent C++ leaf (24 versus 25 bytes and
27 versus 28 bytes). A named top-level Abla function can now become a native
IRAM interrupt entry without an export, C trampoline, boxed `Fn`, or manual
section annotation. The build-only example acknowledges the Wi-Fi MAC
interrupt through direct MMIO; its entry is 21 bytes/8 instructions, exactly
matching equivalent C++, with the same 29 total code-plus-literal IRAM bytes;
its 12-byte/3-instruction address leaf also ties.
Closures and aliases are rejected, and direct Abla helpers are placed in IRAM
automatically. The same object installs that address directly into the
linker-owned dispatcher table on the executing core: it validates the classic
ESP32 interrupt level, disables only that line while publishing the two-word
entry, and restores its prior mask state. The complete installer is 97 bytes
and 33 instructions versus equivalent C++ at 99 bytes and 33 instructions.
It has no unresolved call. A separate target-only Abla module now owns the
classic ESP32's 64-entry interrupt table, 128-entry exception table, 32-byte
interrupt-level table, all six dispatcher compatibility functions, and all six
public names covering the five interrupt-register HAL operations. It also owns
the two non-windowed 48-byte extra-state save/restore leaves and all three ABI
names for the register-window spill unit. `make
check-xtensa-dispatcher-ownership` links that object against the installed
archives and proves the vendor dispatcher assembly, C, interrupt-level, and
five register-access plus two extra-state and window-spill objects are not
selected. The two
dispatcher tables occupy the exact required 1,024 bytes and the level table the
exact 32 bytes.
The target package defines generic typed and naked assembly signatures and
registers its own `$xtensa` subparser; the compiler contains no Xtensa opcode,
register, or `_nw` naming table. Abla's mask helpers tie the vendor assembly.
Its register-access leaves tie the HAL at 8 bytes/3 instructions, and the
62-byte/25-instruction extra-state leaves are byte-identical. The source-owned
window-spill entry is 269 bytes/102 decoded instructions versus the HAL's
273/106. Its 35-byte wrapper matches after normalizing identical literal/call
relocation slots. The compatibility alias shares the primary address, making
the complete unit 308 runtime bytes versus 315 for the HAL. The
management/default unit is 222 bytes versus vendor C at 253. The
handler query is 5 bytes/2 instructions smaller, the interrupt setter 3 bytes
smaller at the same 28 instructions, and the exception setter one byte smaller
at the same 21 instructions.
The RX descriptor/header validator checks ownership, EOF, capacity, address,
and both hardware signal lengths before exposing a frame; its checked leaf is
103 bytes/35 instructions versus 108 bytes/37 instructions for equivalent C++
and has no unresolved calls. The same build emits a caller-owned, 8-byte RX
queue with bounded two-phase descriptor reloads: a timeout keeps explicit
pending state and cannot hand hardware-owned memory to the application. Its
native-width take leaf is 220 bytes/78 instructions versus C++ at 223/79.
The TX slice validates PLCP0's 20-bit descriptor window, publishes the buffer
and null link before DMA ownership, accounts for the hardware-generated FCS,
and reports typed complete/timeout/collision/conflict outcomes per queue. Its
descriptor-preparation leaf matches optimized C++ at 97 bytes and 31
instructions, with no initialization guard or unresolved call.
The target neither links a firmware image nor initializes or transmits on the
radio. See `RADIO.md` for the exact current boundary and provenance.
The default ESP32 surface also includes zero-storage DMA handles and the native
12-byte ESP peripheral-DMA descriptor layout. Descriptor mutation is trusted
because callers must supply DMA-capable internal memory.
`atom-echo` demonstrates a statically selected M5Stack board profile with
built-in button and RGB LED access. See `M5UNIFIED.md` for how these profiles
relate to M5Unified.

Runtime board detection is never imported by a static board profile. Firmware
that genuinely needs one image for several boards imports the relevant
`src/m5stack/detect_*.ab` target module explicitly; importing `m5stack.ab`
alone retains no probe code or detector state.

Each target first compiles an `.ab` entry to an Xtensa ELF object. The preferred
ESP32 integration is the ESP-IDF project in `examples/blink`; it links that
object directly and uses `idf.py` for build, flash, and monitoring. PlatformIO
recipes remain as optional Arduino compatibility checks. The examples have no
C-family application source files. To flash a compatibility build, run:

```sh
make upload-blink
```

The public handles are nominal scalar values where the hardware identity fits
in a machine word. For example, `Pin`, `SerialPort`, `RgbLed`, `ButtonState`, `WifiStation`,
`GpioButton`, `I2cBus`, `I2cDevice`, `SpiPins`, `SpiBus`, `SpiDevice`, `I2sPins`,
`I2sDevice`, `NativeBuffer`, and `TlsClient` keep distinct types
during checking but lower to ordinary integers. Extension methods use `this`
directly; there is no wrapper object or `.value` field.

```abla
val led = pin(27)
led.output()
led.setDriveStrength(2)
led.write(true)

val audio = i2s(0, i2sPins(19, 33, 22, 23), 16000)

var buttonA = pin(39).asButton()
buttonA.initialize()
buttonA = buttonA.update()
if (buttonA.wasPressed()) led.write(true)
```

`GpioButton` packs the GPIO pin, active polarity, debounce/click/hold state,
and transient events into one 64-bit scalar. Its timestamp is modulo 2^22
milliseconds, so it must be updated at least once per roughly 70 minutes; a
normal firmware loop updates it many times per second.

Every M5Stack board ID exposes `buttonA()`, `buttonB()`, `buttonC()`,
`buttonExt()`, and `buttonPower()` as raw `Pin` values. A button wired through
touch, PI4IOE5V6408, PowerHub I2C, M5PM1, or a PMIC key returns `Pin(-1)` rather
than a fake GPIO; the matching `...Source()` method describes its real source.
The returned GPIO `Pin` converts explicitly with `.asButton()`. Checked PI4,
PowerHub, and M5PM1 reads preserve I2C failure separately from the active-low
level, so a bus error cannot become a false press. The pure source registry
imports no timing, network, or device service by itself.

Every M5Unified board ID also exposes raw connector topology through `portA()`
to `portE()`, `sdPins()`, `rgbLedPin()`, `powerHoldPin()`, and `mBusPin(1..30)`.
These return `Pin` values (with `Pin(-1)` for absent hardware), so higher-level
drivers consume the same lowest-level representation on every board.

Trusted driver code can use `nativeStackAllocate` for short-lived SDK structs
and native-width loads/stores. LLVM lowers these to stack allocation and direct
memory operations, so a driver does not need a heap-backed buffer merely to
call a native ABI.

Long-lived firmware storage uses `nativeStaticAllocate`. Each constant-sized
call site becomes a zero-initialized BSS region, while `nativeBufferAt` wraps
its address and capacity into one checked scalar. The `tlsClient()` convenience
constructor similarly owns one static client region; projects needing multiple
clients can reserve distinct regions and construct them with `tlsClientAt`.
The LED constructors follow the same pattern: their convenience form owns one
static instance, while the `...At` form accepts explicit storage for multiple
independent controllers.

ESP-IDF NVS namespaces use a scalar `NvsNamespace` handle with exact 32-bit
vendor ABI declarations. `ImuOffsets` keeps M5Unified-compatible signed Q16
`ax` through `mz` fields in 36 caller-owned or static bytes and persists them
only when its module is imported. Saves explicitly call `nvs_commit`; loads
fail without modifying the live offsets if any field is absent instead of
silently accepting a partial record.

`ImuCalibration` keeps M5Unified's three-sensor previous sample, moving
average, stillness score, radius, tolerance, noise, and strength state in 120
caller-owned bytes. Its fixed-point update uses integer square root and direct
scalar arithmetic, so automatic correction does not require heap objects or a
floating-point math-library boundary. NVS remains a separate opt-in import.

## API and portability

The package entry selects the preferred ESP32 profile (ESP-IDF 6 with Arduino
as a component), so a published checkout can be imported directly:

```abla
import github("AndreBaltazar8/abla-embedded")
```

`src/esp32` contains the native ESP32 implementation. `src/arduino` contains
portable Arduino-runtime fallbacks with the same public names. An application
selects one implementation at its import boundary; its business logic does not
need board-specific function names.

The current ESP32/Arduino link still contains Espressif and Arduino objects.
In particular, ESP32 Wi-Fi depends on Espressif's precompiled PHY, coexistence,
802.11, and power-management archives. Abla Embedded can progressively replace
open driver layers, but it does not claim that those closed binary components
are Abla code.

The intended replacement order is direct peripheral register access first,
then open interrupt/DMA and protocol layers, while retaining vendor PHY/radio
blobs where the silicon requires them. Target modules preserve the same public
names as those boundaries move downward.
