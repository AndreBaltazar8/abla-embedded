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
- ESP-IDF 6.0.2 (the helper defaults to the cached checkout documented below)
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
make rtc-pcf8563
make rtc-rx8130
make io-expander
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
`rtc-pcf8563` reads and validates an external PCF8563 RTC over I2C.
`rtc-rx8130` reads and validates an external RX8130 RTC over I2C.
`io-expander` probes M5IOE1 and PI4IOE5V6408 devices and configures one input.
All three are direct `app_main` ESP-IDF firmwares and do not depend on Arduino.
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
```

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
