# Abla Embedded

Abla Embedded is the low-level, board-neutral home for firmware written in
Abla. Application code uses the same names (`Pin`, `SerialPort`, `I2sDevice`,
`WifiStation`, `TlsClient`) while a project chooses the platform implementation
it imports.

The ESP32 target emits Xtensa objects directly through LLVM. There is no
generated C and no handwritten C/C++ shim between an Abla application and the
linker. Stable hardware operations such as GPIO and UART are implemented with
volatile MMIO in Abla. Complex vendor services currently call their native ABI:
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
make charger-aw32001
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
keep-on mode. `charger-aw32001` builds the AW32001 charger used with the
RISC-V ESP32-C6 Arduino Nesso N1, using an Abla-generated RISC-V object. The
same example initializes its paired BQ27220 fuel gauge and reads signed battery
current and voltage through an allocation-free driver.
The serial, I2S, and Wi-Fi examples
currently also exercise the optional Arduino/PlatformIO compatibility
integration. Edit the placeholder credentials before flashing `wifi-connect`.
`atom-echo` demonstrates a statically selected M5Stack board profile with
built-in button and RGB LED access. See `M5UNIFIED.md` for how these profiles
relate to M5Unified.

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
